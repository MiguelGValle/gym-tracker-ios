import SwiftUI
import UIKit

/// A numeric entry selects the existing number on focus, so typing replaces it.
struct ReplaceableNumberField: UIViewRepresentable {
    let title: String
    @Binding var value: Double
    var integer = false

    private var formatted: String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...(integer ? 0 : 2))))
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.keyboardType = integer ? .numberPad : .decimalPad
        field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        field.addGestureRecognizer(tap)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.placeholder = title
        field.accessibilityLabel = title
        field.accessibilityIdentifier = title
        field.keyboardType = integer ? .numberPad : .decimalPad
        if !field.isFirstResponder { field.text = formatted }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate, UIGestureRecognizerDelegate {
        var parent: ReplaceableNumberField
        init(_ parent: ReplaceableNumberField) { self.parent = parent }

        func textFieldDidBeginEditing(_ field: UITextField) {
            // Run after UIKit's initial caret placement so the tap cannot collapse selection.
            DispatchQueue.main.async { [weak field] in
                guard let field, field.isFirstResponder else { return }
                field.selectAll(nil)
            }
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let field = gesture.view as? UITextField else { return }
            DispatchQueue.main.async { [weak field] in
                guard let field, field.isFirstResponder else { return }
                field.selectAll(nil)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

        @objc func changed(_ field: UITextField) {
            let text = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = Double(text.replacingOccurrences(of: ",", with: ".")),
                  number.isFinite, (0...1_000_000).contains(number),
                  !parent.integer || number.rounded(.towardZero) == number else { return }
            parent.value = number
        }

        func textFieldDidEndEditing(_ field: UITextField) { field.text = parent.formatted }
    }
}
