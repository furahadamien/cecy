import SwiftUI

struct SelectionChip: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
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
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: TrackerLayout.minimumTarget)
            .foregroundStyle(selected ? palette.accent : .primary)
            .background(selected ? palette.sage : palette.background,
                        in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous)
                    .strokeBorder(selected || contrast == .increased ? palette.accent : .secondary.opacity(0.35),
                                  lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
