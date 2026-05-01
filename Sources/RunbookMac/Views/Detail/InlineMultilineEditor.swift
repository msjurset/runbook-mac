import AppKit
import SwiftUI

/// Multi-line editor used by EditableConfigRow's inline edit mode. Modeled on
/// FilterField but built around NSTextView so a plain Return inserts a
/// newline — `command:` values are often single-line at first but routinely
/// grow into multi-line shell snippets, and forcing the user to bounce out
/// to the popout for that is friction we don't want.
///
/// Keys:
/// - Return       → newline (default).
/// - Cmd+Return   → save and exit.
/// - Escape       → cancel and exit.
/// - Tab/click-out → save (via textDidEndEditing).
///
/// Auto-completion / autofill / inline prediction are all force-disabled at
/// every lifecycle hook AppKit exposes, matching the user's CLAUDE.md rule
/// that any macOS text input must use a NoAutoFill subclass.
struct InlineMultilineEditor: NSViewRepresentable {
    @Binding var text: String
    var onSave: () -> Void
    var onCancel: () -> Void
    /// Bumping this requests first-responder. SwiftUI @FocusState does not
    /// reach into NSViewRepresentable, so the parent flips an Int instead.
    var focusTrigger: Int = 0

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = InlineMultilineTextView()
        textView.delegate = context.coordinator
        textView.onSaveCommand = onSave
        textView.onCancelCommand = onCancel
        textView.applyAutoFillSuppressors()
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.string = text
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InlineMultilineTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onSaveCommand = onSave
        textView.onCancelCommand = onCancel

        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                // Place caret at end of text so the user can keep typing
                // immediately. Without this AppKit selects the entire string.
                let end = (textView.string as NSString).length
                textView.selectedRange = NSRange(location: end, length: 0)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var lastFocusTrigger = -1
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let tv = notification.object as? InlineMultilineTextView else { return }
            // textDidEndEditing fires when the field loses first-responder
            // for any reason (clicking another control, tabbing away, the
            // window resigning key). We treat that as "save" — same model
            // FilterField uses for single-line inputs.
            tv.onSaveCommand?()
        }
    }
}

/// NSTextView subclass that owns the keyboard contract for the inline editor:
/// Cmd+Return saves, Escape cancels, plain Return falls through to default
/// (insert newline). Also re-applies AppKit's auto-* suppressors at every
/// lifecycle hook because AppKit re-enables them otherwise.
final class InlineMultilineTextView: NSTextView {
    var onSaveCommand: (() -> Void)?
    var onCancelCommand: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // 36 = Return. .command alone (no shift/option) → save. Plain Return
        // and Shift+Return both fall through to insert a newline so the
        // user can build multi-line content the obvious way.
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onSaveCommand?()
            return
        }
        if event.keyCode == 53 /* Escape */ {
            onCancelCommand?()
            return
        }
        super.keyDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        applyAutoFillSuppressors()
        return super.becomeFirstResponder()
    }

    func applyAutoFillSuppressors() {
        isAutomaticTextCompletionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isContinuousSpellCheckingEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        if #available(macOS 14.0, *) { inlinePredictionType = .no }
    }
}
