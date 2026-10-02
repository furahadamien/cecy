import SwiftUI

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
                .frame(width: 46, height: 46)
                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(accent.opacity(0.08), in: Capsule())
    }
}
