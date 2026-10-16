import SwiftUI

/// A labeled single-choice control that shows every option as a tappable chip instead of a hidden menu.
/// Options wrap to new rows at any text size and expose standard selected traits to VoiceOver.
struct ChipPicker<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var symbol: ((Value) -> String?)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            }
            SelectionFlowLayout {
                ForEach(options, id: \.self) { option in
                    SelectionChip(title: label(option), symbol: symbol?(option), selected: option == selection) {
                        selection = option
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}
