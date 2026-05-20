import AppKit
import SwiftUI
import VimEngine

/// Multi-line editor used by EditableConfigRow's inline edit mode. Modeled on
/// FilterField but built around NSTextView so a plain Return inserts a
/// newline — `command:` values are often single-line at first but routinely
/// grow into multi-line shell snippets, and forcing the user to bounce out
/// to the popout for that is friction we don't want.
///
/// Keys (with vim OFF — default):
/// - Return       → newline.
/// - Cmd+Return   → save and exit.
/// - Escape       → cancel and exit.
/// - Tab/click-out → save (via textDidEndEditing).
///
/// When vim is ON (host passes a non-nil `vimEngine`), Escape belongs to
/// vim (cancels operator / exits insert / aborts command line). Cmd+Return
/// continues to save because Cmd-shortcuts bypass `keyDown` via
/// `performKeyEquivalent` earlier in the responder chain.
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
    /// Non-nil = vim mode is active. The engine owns key routing.
    var vimEngine: VimEngine? = nil
    /// Current `/partial` slash-command run at the caret.
    var slashPrefix: Binding<String>? = nil
    /// Host-side handler for slash dropdown navigation while visible.
    var onSlashKeyEvent: ((CodeEditorView.SuggestionKeyEvent) -> Bool)? = nil

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

        let coordinator = context.coordinator
        textView.vimEngineProvider = { coordinator.parent?.vimEngine }
        textView.isShowingSlash = { !(coordinator.parent?.slashPrefix?.wrappedValue ?? "").isEmpty }
        textView.slashKeyHandler = { event in
            coordinator.parent?.onSlashKeyEvent?(event) ?? false
        }
        context.coordinator.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? InlineMultilineTextView else { return }
        context.coordinator.parent = self
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

        // On vim→off transition, redraw the cursor cell so the lingering
        // block clears.
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
        var parent: InlineMultilineEditor?
        weak var textView: NSTextView?
        var lastFocusTrigger = -1
        var lastVimActive = false
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string

            // Slash-command detection; suspended while vim is on.
            if let parent, let binding = parent.slashPrefix {
                binding.wrappedValue = parent.vimEngine != nil
                    ? ""
                    : SlashPrefixDetector.detect(in: tv)
            }
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
/// vim → slash → (Cmd+Return saves / Escape cancels) → super (insert
/// newline). The vim/slash plumbing comes from `VimAwareTextView`; this
/// subclass adds the host-specific Cmd+Return + Esc handlers (via
/// `handleSubclassKey`) plus AppKit's auto-* suppressors that the inline
/// editor's CLAUDE.md rule requires to be reapplied at every lifecycle hook.
final class InlineMultilineTextView: VimAwareTextView {
    var onSaveCommand: (() -> Void)?
    var onCancelCommand: (() -> Void)?

    /// Smaller fallback to match the 11pt font used in the inline editor.
    override class var minBlockCursorWidth: CGFloat { 7 }

    override func handleSubclassKey(_ event: NSEvent) -> Bool {
        // 36 = Return. .command alone (no shift/option) → save. Plain Return
        // and Shift+Return both fall through to insert a newline so the
        // user can build multi-line content the obvious way.
        if event.keyCode == 36 && event.modifierFlags.contains(.command) {
            onSaveCommand?()
            return true
        }
        if event.keyCode == 53 /* Escape */ {
            onCancelCommand?()
            return true
        }
        return false
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
