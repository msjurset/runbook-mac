import AppKit
import SwiftUI
import VimEngine

/// A syntax-highlighted YAML editor with auto-completion. Optionally
/// hands the keyboard off to `VimEngine` when the host passes a non-nil
/// `vimEngine` binding (set by clicking the vim icon or typing `/vim`).
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    /// Non-nil = vim mode is active. The engine owns key routing while set.
    var vimEngine: VimEngine? = nil
    /// Current `/partial` slash-command run at the caret. Empty when the
    /// caret isn't inside a slash context. The host renders the
    /// suggestion pill from this; the editor writes to it.
    var slashPrefix: Binding<String>? = nil
    /// Host-side handler for arrow/Enter/Tab/Esc/Space while the slash
    /// pill is visible. Returning true marks the event as consumed.
    var onSlashKeyEvent: ((SuggestionKeyEvent) -> Bool)? = nil

    enum SuggestionKeyEvent {
        case arrowUp, arrowDown, enter, escape, tab, space
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = YAMLTextView()

        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(AppSettings.editorFontSize), weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(AppSettings.editorFontSize), weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]

        textView.delegate = context.coordinator
        let coordinator = context.coordinator
        textView.vimEngineProvider = { coordinator.parent?.vimEngine }
        textView.isShowingSlash = { !(coordinator.parent?.slashPrefix?.wrappedValue ?? "").isEmpty }
        textView.slashKeyHandler = { event in
            coordinator.parent?.onSlashKeyEvent?(event) ?? false
        }
        context.coordinator.textView = textView

        context.coordinator.setTextAndHighlight(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? YAMLTextView else { return }
        // Refresh the coordinator's parent so non-@Binding values (vim
        // engine, slash bindings, slash handler) read live across
        // re-renders. @Binding storage already routes through its
        // wrapper, but plain `var` fields would otherwise see the stale
        // struct captured at makeCoordinator() time.
        context.coordinator.parent = self

        if textView.string != text {
            context.coordinator.setTextAndHighlight(text)
        }

        // On vim→off transition, restore first responder and repaint the
        // cursor cell so the lingering block clears.
        let vimActiveNow = (vimEngine != nil)
        if context.coordinator.lastVimActive && !vimActiveNow {
            DispatchQueue.main.async {
                if let window = textView.window {
                    window.makeFirstResponder(textView)
                }
                textView.refreshCursorArea()
            }
        }
        context.coordinator.lastVimActive = vimActiveNow
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator(text: $text)
        c.parent = self
        return c
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var parent: CodeEditorView?
        weak var textView: NSTextView?
        let highlighter = YAMLHighlighter()
        let completionProvider = YAMLCompletionProvider()
        private var isUpdating = false
        var lastVimActive = false

        private let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: CGFloat(AppSettings.editorFontSize), weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]

        init(text: Binding<String>) {
            self.text = text
        }

        @MainActor func setTextAndHighlight(_ newText: String) {
            guard let textView else { return }
            isUpdating = true

            let selectedRanges = textView.selectedRanges

            let attrStr = NSMutableAttributedString(string: newText, attributes: baseAttrs)
            highlightAttributedString(attrStr)
            textView.textStorage?.setAttributedString(attrStr)

            // Reset typing attributes so new text is default color
            textView.typingAttributes = baseAttrs

            let maxLen = newText.utf16.count
            let safeRanges = selectedRanges.compactMap { rangeValue -> NSValue? in
                let range = rangeValue.rangeValue
                return range.location <= maxLen ? rangeValue : nil
            }
            if !safeRanges.isEmpty {
                textView.selectedRanges = safeRanges
            }

            isUpdating = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView else { return }
            isUpdating = true

            text.wrappedValue = textView.string

            // Re-highlight
            let selectedRanges = textView.selectedRanges
            let fullRange = NSRange(location: 0, length: textView.textStorage!.length)
            textView.textStorage?.setAttributes(baseAttrs, range: fullRange)
            highlightTextStorage(textView.textStorage!)
            textView.selectedRanges = selectedRanges

            // Reset typing attributes so next keystroke uses default color
            textView.typingAttributes = baseAttrs

            isUpdating = false

            // Slash-command detection — suspended while /vim is active so
            // vim's normal-mode `/` (search) doesn't fight the app-level
            // dropdown.
            if let parent, let binding = parent.slashPrefix {
                binding.wrappedValue = parent.vimEngine != nil
                    ? ""
                    : SlashPrefixDetector.detect(in: textView)
            }
        }
        // MARK: - Completion

        func textView(_ textView: NSTextView, completions words: [String],
                       forPartialWordRange charRange: NSRange,
                       indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
            let nsText = textView.string as NSString
            let cursorLocation = textView.selectedRange().location
            let lineRange = nsText.lineRange(for: NSRange(location: cursorLocation, length: 0))
            let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

            let suggestions = completionProvider.completions(for: line, cursorPosition: cursorLocation - lineRange.location)
            if let index {
                index.pointee = 0  // Pre-select first item
            }
            return suggestions
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // While vim is active, the engine has already had a chance to
            // consume the key in keyDown — anything reaching doCommandBy
            // belongs to AppKit's default behavior (insert-mode typing,
            // newline insertion etc.), so don't trigger YAML completion
            // or auto-indent here.
            if parent?.vimEngine != nil { return false }

            // Tab: insert 2 spaces (YAML indent) or trigger completion if line has content
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                let nsText = textView.string as NSString
                let cursorLocation = textView.selectedRange().location
                let lineRange = nsText.lineRange(for: NSRange(location: cursorLocation, length: 0))
                let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
                let lineToCursor = nsText.substring(
                    with: NSRange(location: lineRange.location,
                                  length: cursorLocation - lineRange.location))

                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Indent-only line: prefer offering keys appropriate to
                    // this indent if the schema has any. If the provider
                    // returns nothing (e.g., we're outside the schema's
                    // known indent levels), fall back to inserting spaces so
                    // Tab still does *something*.
                    let cursorOffsetInLine = cursorLocation - lineRange.location
                    let suggestions = completionProvider.completions(
                        for: line, cursorPosition: cursorOffsetInLine)
                    if suggestions.isEmpty {
                        textView.insertText("  ", replacementRange: textView.selectedRange())
                    } else {
                        textView.complete(nil)
                    }
                } else if lineToCursor.hasSuffix(":") {
                    // Cursor sits right after a key colon with no space yet —
                    // chain into value completion. Insert the missing space
                    // first so the partial-word range AppKit computes is the
                    // empty position AFTER the space, not the colon itself.
                    // Without this, the value commit would have to either
                    // produce "type:shell" (no space, ugly) or special-case
                    // insertion in two places.
                    textView.insertText(" ", replacementRange: textView.selectedRange())
                    textView.complete(nil)
                } else {
                    // Line has content: trigger completion
                    textView.complete(nil)
                }
                return true
            }

            // Auto-indent on newline
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let nsText = textView.string as NSString
                let selectedRange = textView.selectedRange()
                let lineRange = nsText.lineRange(for: NSRange(location: selectedRange.location, length: 0))
                let currentLine = nsText.substring(with: lineRange)

                let indent = currentLine.prefix(while: { $0 == " " })
                var newIndent = String(indent)

                let trimmed = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasSuffix(":") {
                    newIndent += "  "
                }

                textView.insertNewline(nil)
                textView.insertText(newIndent, replacementRange: textView.selectedRange())
                return true
            }

            return false
        }

        // MARK: - Highlighting

        private func highlightAttributedString(_ attrStr: NSMutableAttributedString) {
            let text = attrStr.string
            let lines = text.components(separatedBy: "\n")
            var offset = 0
            for line in lines {
                let lineRange = NSRange(location: offset, length: line.utf16.count)
                highlightLine(line, in: attrStr, at: lineRange)
                offset += line.utf16.count + 1
            }
        }

        private func highlightTextStorage(_ storage: NSTextStorage) {
            storage.beginEditing()
            let text = storage.string
            let lines = text.components(separatedBy: "\n")
            var offset = 0
            for line in lines {
                let lineRange = NSRange(location: offset, length: line.utf16.count)
                highlightLine(line, in: storage, at: lineRange)
                offset += line.utf16.count + 1
            }
            storage.endEditing()
        }

        private func highlightLine(_ line: String, in attrStr: NSMutableAttributedString, at lineRange: NSRange) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#") {
                attrStr.addAttribute(.foregroundColor, value: NSColor.systemGray, range: lineRange)
                return
            }

            // Template expressions {{...}}
            applyPattern("\\{\\{[^}]*\\}\\}", in: line, to: attrStr,
                         lineOffset: lineRange.location, color: .systemPink)

            // List dash
            if trimmed.hasPrefix("- ") {
                if let dashRange = line.range(of: "- ") {
                    let nsRange = NSRange(dashRange, in: line)
                    let adjusted = NSRange(location: lineRange.location + nsRange.location, length: 1)
                    attrStr.addAttribute(.foregroundColor, value: NSColor.systemYellow, range: adjusted)
                }
            }

            // Key: value
            guard let colonIdx = line.firstIndex(of: ":") else { return }
            let keyPart = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)

            // Color the key
            if !keyPart.isEmpty && !keyPart.hasPrefix("-") {
                if let keyRange = line.range(of: keyPart) {
                    let nsRange = NSRange(keyRange, in: line)
                    let adjusted = NSRange(location: lineRange.location + nsRange.location, length: nsRange.length)
                    attrStr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: adjusted)
                }
            }

            // Key after "- " (e.g., "- name:")
            if trimmed.hasPrefix("- ") {
                let afterDash = String(trimmed.dropFirst(2))
                if let subColon = afterDash.firstIndex(of: ":") {
                    let subKey = String(afterDash[afterDash.startIndex..<subColon])
                    if !subKey.isEmpty, let keyRange = line.range(of: subKey) {
                        let nsRange = NSRange(keyRange, in: line)
                        let adjusted = NSRange(location: lineRange.location + nsRange.location, length: nsRange.length)
                        attrStr.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: adjusted)
                    }
                }
            }

            // Value after colon
            let afterColon = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            guard !afterColon.isEmpty else { return }
            guard let valueRange = line.range(of: afterColon, options: .backwards) else { return }
            let nsValueRange = NSRange(valueRange, in: line)
            let adjustedValue = NSRange(location: lineRange.location + nsValueRange.location, length: nsValueRange.length)

            if (afterColon.hasPrefix("\"") && afterColon.hasSuffix("\"")) ||
               (afterColon.hasPrefix("'") && afterColon.hasSuffix("'")) {
                attrStr.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: adjustedValue)
            } else if ["true", "false", "yes", "no"].contains(afterColon.lowercased()) {
                attrStr.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: adjustedValue)
            } else if Double(afterColon) != nil {
                attrStr.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: adjustedValue)
            } else if afterColon.hasPrefix("op://") {
                attrStr.addAttribute(.foregroundColor, value: NSColor.systemTeal, range: adjustedValue)
            }
        }

        private func applyPattern(_ pattern: String, in line: String, to attrStr: NSMutableAttributedString,
                                   lineOffset: Int, color: NSColor) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsLine = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
            for match in matches {
                let adjusted = NSRange(location: lineOffset + match.range.location, length: match.range.length)
                attrStr.addAttribute(.foregroundColor, value: color, range: adjusted)
            }
        }
    }
}

/// NSTextView subclass that scopes completion's partial-word range to a YAML
/// token. Crucially `:` is NOT a word char — that makes the YAML key/value
/// boundary a token boundary, so a value-position completion (cursor after a
/// `key:`) replaces only the value text, not the key. Including `:` in the
/// word set causes "type:" + Tab to replace the whole "type:" with the
/// chosen value, producing a broken document.
///
/// All the vim/slash plumbing (block cursor, scroll-on-cursor-move,
/// replace-mode overwrite, keyDown forwarding) lives in `VimAwareTextView`.
final class YAMLTextView: VimAwareTextView {
    private static let wordChars = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "_-."))

    override var rangeForUserCompletion: NSRange {
        let nsText = string as NSString
        let cursor = selectedRange().location

        var start = cursor
        while start > 0 {
            let c = Character(UnicodeScalar(nsText.character(at: start - 1))!)
            if c.unicodeScalars.allSatisfy({ Self.wordChars.contains($0) }) {
                start -= 1
            } else {
                break
            }
        }

        return NSRange(location: start, length: cursor - start)
    }
}
