import SwiftUI

struct CalendarSymbolLegend: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    struct Item: Identifiable {
        let id: String
        let title: String
        let meaning: String
        let symbol: String
        let description: String
    }

    static let items: [Item] = [
        Item(id: "period", title: "Period", meaning: "Logged", symbol: "drop.fill", description: "Recorded period"),
        Item(id: "estimate", title: "Period dates", meaning: "Estimated", symbol: "circle.dashed", description: "Estimated period dates · Not recorded"),
        Item(id: "ovulation", title: "Ovulation", meaning: "Estimated", symbol: "circle.dotted", description: "Estimated ovulation · Not confirmed"),
        Item(id: "fertile", title: "Fertile window", meaning: "Estimated", symbol: "leaf", description: "Estimated fertile window"),
        Item(id: "sex", title: "Sex", meaning: "Logged", symbol: "heart.fill", description: "Sexual activity"),
        Item(id: "symptoms", title: "Symptoms", meaning: "Logged", symbol: "waveform.path.ecg", description: "Logged symptoms"),
        Item(id: "bleeding", title: "Other bleeding", meaning: "Logged", symbol: "drop.circle.fill", description: "Daily bleeding log · Not a period start")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 140 : 94), alignment: .top)], spacing: 6) {
                ForEach(Self.items) { item in
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: item.symbol).font(.caption).foregroundStyle(color(item))
                            .frame(width: 16).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.caption2.weight(.medium))
                            Text(item.meaning).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.description)
                    .accessibilityIdentifier("calendarLegend_\(item.id)")
                }
            }
            DailyBleedingLegend(includesCalendarNotes: true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendarLegend")
    }

    private func color(_ item: Item) -> Color {
        let palette = TrackerPalette(scheme: colorScheme)
        switch item.id {
        case "period", "estimate": return palette.recorded
        case "sex": return palette.sexualActivity
        default: return palette.accent
        }
    }
}
