import AppKit
import SwiftUI

/// NSTextView-backed code editor used inside the code-block popover.
/// Carries a language hint and applies the matching highlighter live.
///
/// Line numbers intentionally removed for now — a prior pass with
/// NSRulerView broke the text display on first show. Coming back as a
/// separate follow-up once this editor is confirmed working.
struct CodePopoutEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeLanguage

    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let baseAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.labelColor,
    ]

    // Mirrors the known-working main YAML editor (CodeEditorView) as closely as
    // possible, swapping the language-specific highlighter and dropping YAML-
    // specific completion/comment toggling.

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

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
        context.coordinator.textView = textView
        context.coordinator.language = language

        context.coordinator.setTextAndHighlight(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.language = language
        if textView.string != text {
            context.coordinator.setTextAndHighlight(text)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, language: language) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var language: CodeLanguage
        weak var textView: NSTextView?
        private var isUpdating = false

        init(text: Binding<String>, language: CodeLanguage) {
            self.text = text
            self.language = language
        }

        func setTextAndHighlight(_ newText: String) {
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
