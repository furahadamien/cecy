import SwiftUI
import UIKit

/// Enforces the grapheme limit before UIKit accepts input; no transient 101st character.
struct BoundedQuestionEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    var maximum = AIContextBuilder.maximumQuestionLength

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        let descriptor = UIFont.preferredFont(forTextStyle: .body).fontDescriptor
        view.font = UIFont(descriptor: descriptor.withDesign(.rounded) ?? descriptor, size: 0)
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = "Your question"
        view.accessibilityIdentifier = "aiQuestionText"
        view.accessibilityHint = "Up to \(maximum) characters."
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        toolbar.autoresizingMask = .flexibleWidth
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Hide keyboard", primaryAction: UIAction { [weak view] _ in
                view?.resignFirstResponder()
            })
        ]
        view.inputAccessoryView = toolbar
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.markedTextRange == nil && view.text != text { view.text = text }
        if focused && !view.isFirstResponder && view.window != nil { view.becomeFirstResponder() }
        if !focused && view.isFirstResponder { view.resignFirstResponder() }
    }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BoundedQuestionEditor
        init(parent: BoundedQuestionEditor) { self.parent = parent }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.focused = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.focused = false }
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard textView.markedTextRange == nil else { return true }
            let candidate = (textView.text as NSString).replacingCharacters(in: range, with: text)
            guard candidate.count <= parent.maximum else {
                UIAccessibility.post(notification: .announcement, argument: "Questions can contain up to \(parent.maximum) characters.")
                return false
            }
            return true
        }
        func textViewDidChange(_ textView: UITextView) {
            // Let input-method composition finish before enforcing the final grapheme count.
            guard textView.markedTextRange == nil else { return }
            let bounded = String(textView.text.prefix(parent.maximum))
            if textView.text != bounded { textView.text = bounded }
            parent.text = bounded
        }
    }
}
