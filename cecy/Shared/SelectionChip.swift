import SwiftUI

struct SelectionChip: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    // Onboarding tints the chip with the step color; everywhere else it stays sage/accent.
    @Environment(\.onboardingTheme) private var theme
    let title: String
    var symbol: String? = nil
    let selected: Bool
    var iconTint: Color? = nil
    let action: () -> Void

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        let accent = theme?.tint ?? palette.accent
        let selectedFill = theme?.surface ?? palette.sage
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol).symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconTint ?? (selected ? accent : .primary))
                        .accessibilityHidden(true)
                }
                Text(title).fixedSize(horizontal: false, vertical: true)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: TrackerLayout.minimumTarget)
            .foregroundStyle(selected ? accent : .primary)
            .background(selected ? selectedFill : palette.background,
                        in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous)
                    .strokeBorder(selected || contrast == .increased ? accent : .secondary.opacity(0.35),
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
