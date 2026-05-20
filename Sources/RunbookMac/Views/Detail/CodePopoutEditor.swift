import AppKit
import SwiftUI
import VimEngine

/// NSTextView-backed code editor used inside the code-block popover.
/// Carries a language hint and applies the matching highlighter live.
///
/// Optionally hands the keyboard off to `VimEngine` when the host
/// passes a non-nil `vimEngine`; while active, Esc has vim semantics
/// rather than popover-dismiss semantics.
struct CodePopoutEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage
    /// Non-nil = vim mode is active. The engine owns key routing while set.
    var vimEngine: VimEngine? = nil
    /// Current `/partial` slash-command run at the caret. Empty when the
    /// caret isn't inside a slash context.
    var slashPrefix: Binding<String>? = nil
    /// Host-side handler for arrow/Enter/Tab/Esc/Space while the slash
    /// pill is visible.
    var onSlashKeyEvent: ((CodeEditorView.SuggestionKeyEvent) -> Bool)? = nil

    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let baseAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.labelColor,
    ]

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = PopoutTextView()

        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        if #available(macOS 14.0, *) {
            textView.inlinePredictionType = .no
        }
        textView.font = Self.font
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.typingAttributes = Self.baseAttrs

        textView.delegate = context.coordinator
        let coordinator = context.coordinator
        textView.vimEngineProvider = { coordinator.parent?.vimEngine }
        textView.isShowingSlash = { !(coordinator.parent?.slashPrefix?.wrappedValue ?? "").isEmpty }
        textView.slashKeyHandler = { event in
            coordinator.parent?.onSlashKeyEvent?(event) ?? false
        }
        context.coordinator.textView = textView
        context.coordinator.language = language

        context.coordinator.setTextAndHighlight(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PopoutTextView else { return }
        context.coordinator.parent = self
        context.coordinator.language = language
        if textView.string != text {
            context.coordinator.setTextAndHighlight(text)
        }

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
        let c = Coordinator(text: $text, language: language)
        c.parent = self
        return c
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var language: CodeLanguage
        var parent: CodePopoutEditor?
        weak var textView: NSTextView?
        private var isUpdating = false
        var lastVimActive = false

        init(text: Binding<String>, language: CodeLanguage) {
            self.text = text
            self.language = language
        }

        @MainActor func setTextAndHighlight(_ newText: String) {
            guard let textView, let storage = textView.textStorage else { return }
            isUpdating = true
            let selected = textView.selectedRanges
            let attrStr = NSMutableAttributedString(string: newText, attributes: CodePopoutEditor.baseAttrs)
            applyHighlight(attrStr)
            storage.setAttributedString(attrStr)
            textView.typingAttributes = CodePopoutEditor.baseAttrs
            let maxLen = newText.utf16.count
            let safe = selected.compactMap { v -> NSValue? in
                v.rangeValue.location <= maxLen ? v : nil
            }
            if !safe.isEmpty { textView.selectedRanges = safe }
            isUpdating = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            isUpdating = true
            text.wrappedValue = textView.string
            let selected = textView.selectedRanges
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.setAttributes(CodePopoutEditor.baseAttrs, range: fullRange)
            applyHighlight(storage)
            textView.selectedRanges = selected
            textView.typingAttributes = CodePopoutEditor.baseAttrs
            isUpdating = false

            // Slash-command detection; suspended while vim is on.
            if let parent, let binding = parent.slashPrefix {
                binding.wrappedValue = parent.vimEngine != nil
                    ? ""
                    : SlashPrefixDetector.detect(in: textView)
            }
        }

        private func applyHighlight(_ storage: NSMutableAttributedString) {
            switch language {
            case .bash:  BashHighlighter.apply(to: storage)
            case .json:  JSONHighlighter.apply(to: storage)
            case .plain: break
            }
        }
    }
}

/// NSTextView subclass for the code-block popout. All vim/slash plumbing
/// (block cursor, scroll fix, replace-mode overwrite, keyDown forwarding)
/// is inherited from `VimAwareTextView`. No additional behavior.
final class PopoutTextView: VimAwareTextView {}
