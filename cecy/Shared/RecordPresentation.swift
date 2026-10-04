import SwiftUI

/// One solid reading surface per record; no nested borders or translucent health text.
struct RecordedEntryCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 32, bottomLeadingRadius: 24,
                                           bottomTrailingRadius: 32, topTrailingRadius: 24, style: .continuous)
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(TrackerPalette(scheme: colorScheme).surface, in: shape)
            .overlay {
                shape.strokeBorder(accent.opacity(contrast == .increased ? 1 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(contrast == .increased ? 0 : 0.04), radius: 12, y: 4)
    }
}

struct RecordActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(configuration.role == .destructive ? Color.secondary : TrackerPalette(scheme: colorScheme).accent)
            .padding(.horizontal, 8)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.45)
    }
}

/// A consistent record identity without adding another nested card surface.
struct RecordHeader: View {
    let title: String
    let date: String
    let symbol: String
    let accent: Color
    @ScaledMetric(relativeTo: .body) private var iconSize = 20.0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: min(iconSize, 28), weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 50, height: 50)
                .background(accent.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                Text(date).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RecordBadge: View {
    let title: String
    let symbol: String
    let accent: Color
    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(accent)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 3)
            .padding(.trailing, 8)
    }
}
