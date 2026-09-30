import SwiftUI

struct SelectionChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var symbol: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol).symbolRenderingMode(.monochrome)
                        .accessibilityHidden(true)
                }
                Text(title).fixedSize(horizontal: false, vertical: true)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(minHeight: 44)
            .foregroundStyle(selected ? palette.accent : .primary)
            .background(selected ? palette.sage : palette.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? palette.accent : .secondary.opacity(0.4)))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}