import AppKit
import SwiftUI

/// A text field that suppresses macOS autofill/autocomplete popups.
/// Use this instead of SwiftUI TextField for filter/search fields.
struct FilterField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onCommit: (() -> Void)?
    var autoFocus = false

    func makeNSView(context: Context) -> NoAutoFillTextField {
        let field = NoAutoFillTextField()
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.isAutomaticTextCompletionEnabled = false
        field.contentType = .none
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
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCommit: (() -> Void)?

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
class NoAutoFillTextField: NSTextField {
    override var allowsCharacterPickerTouchBarItem: Bool {
        get { false }
        set {}
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        // Suppress autofill immediately when field gains focus
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
    }
}
