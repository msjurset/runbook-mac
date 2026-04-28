import AppKit
import SwiftUI

/// A text field that suppresses macOS autofill/autocomplete popups.
/// Use this instead of SwiftUI TextField for every text input on macOS —
/// SwiftUI TextField shows a phantom autocomplete dropdown no modifier can kill.
struct FilterField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onCommit: (() -> Void)?
    var autoFocus = false
    var isDisabled = false
    /// Bumping this integer requests that the field become first responder.
    /// Use instead of SwiftUI @FocusState, which doesn't bind to NSViewRepresentable.
    var focusTrigger: Int = 0
    /// Visual style — .rounded for form/sheet inputs, .plain for inline search bars.
    var style: Style = .rounded

    enum Style { case rounded, plain }

    func makeNSView(context: Context) -> NoAutoFillTextField {
        let field = NoAutoFillTextField()
        field.placeholderString = placeholder
        switch style {
        case .rounded:
            field.bezelStyle = .roundedBezel
            field.isBordered = true
            field.drawsBackground = true
        case .plain:
            field.isBordered = false
            field.drawsBackground = false
            field.focusRingType = .none
        }
        field.delegate = context.coordinator
        field.isAutomaticTextCompletionEnabled = false
        field.contentType = .none
        context.coordinator.lastFocusTrigger = focusTrigger
        if autoFocus {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                field.window?.makeFirstResponder(field)
            }
        }
        return field
    }

    func updateNSView(_ nsView: NoAutoFillTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
            // After a PROGRAMMATIC text change (e.g. autocomplete inserted
            // a suggestion), place the cursor at the end of the new text
            // with no selection. Without this, AppKit's default behavior
            // when stringValue is set on a field with an active editor is
            // to select the entire inserted text — which forces the user
            // to press right-arrow before they can keep typing, because
            // the next keystroke would otherwise replace the selection.
            // NSRange.location is in UTF-16 units, so use utf16.count to
            // stay correct for emoji and accented characters.
            if let editor = nsView.currentEditor() {
                let end = (text as NSString).length
                editor.selectedRange = NSRange(location: end, length: 0)
            }
        }
        nsView.isEnabled = !isDisabled
        if focusTrigger != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectAll(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCommit: (() -> Void)?
        var lastFocusTrigger: Int = 0

        init(text: Binding<String>, onCommit: (() -> Void)?) {
            self.text = text
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            onCommit?()
        }
    }
}

/// NSTextField subclass that refuses all autofill and autocompletion.
/// The field editor (NSTextView) must be reconfigured in three places —
/// becomeFirstResponder, textDidBeginEditing, and textShouldBeginEditing —
/// because AppKit re-enables auto-* flags at each lifecycle point.
final class NoAutoFillTextField: NSTextField {
    override var allowsCharacterPickerTouchBarItem: Bool {
        get { false }
        set {}
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if let editor = currentEditor() as? NSTextView {
            disableAllAutoComplete(editor)
        }
        return result
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        if let editor = currentEditor() as? NSTextView {
            disableAllAutoComplete(editor)
        }
    }

    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        if let editor = textObject as? NSTextView {
            disableAllAutoComplete(editor)
        }
        return super.textShouldBeginEditing(textObject)
    }

    private func disableAllAutoComplete(_ editor: NSTextView) {
        editor.isAutomaticTextCompletionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        // macOS 14+ added an inline-prediction bar that renders as a
        // large ghost popup beneath the field on focus. The usual
        // auto-* flags don't disable it; this trait does.
        if #available(macOS 14.0, *) {
            editor.inlinePredictionType = .no
        }
    }
}
