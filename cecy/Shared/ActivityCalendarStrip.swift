import SwiftUI

struct DayActivityIcons: View {
    @Environment(\.colorScheme) private var colorScheme
    let markers: [DayActivityMarker]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 4) {
            ForEach(markers) { marker in
                Image(systemName: marker.symbol).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(marker.id == "period"
                                     ? TrackerPalette(scheme: colorScheme).recorded
                                     : TrackerPalette(scheme: colorScheme).accent)
            }
        }
        .frame(minHeight: 10)
        // The containing date button reads the full list, not unlabeled tiny images.
        .accessibilityHidden(true)
    }
}

struct ActivityCalendarStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .body) private var dayWidth = 64.0
    let today: LocalDay
    let snapshot: TrackerSnapshot
    @Binding var selection: LocalDay
    @State private var lower = -30
    @State private var upper = 30
    @State private var centeredDay: Int?

    private var days: [LocalDay] { (lower...upper).compactMap { try? today.adding(days: $0) } }
    private var visibleDay: LocalDay { centeredDay.flatMap { try? LocalDay(key: $0) } ?? selection }
    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(DayText.month(visibleDay)).font(.headline).accessibilityIdentifier("todayStripMonth")
                Spacer()
                Button("Today") {
                    selection = today
                    lower = min(lower, -30); upper = max(upper, 30)
                    centeredDay = today.key
                }.frame(minHeight: 44).accessibilityIdentifier("stripReturnToToday")
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days) { day in
                        let markers = DayActivityMarker.recorded(on: day, in: snapshot)
                        Button { selection = day; centeredDay = day.key } label: {
                            VStack(spacing: 8) {
                                Text(day.formattingDate, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(day.day.formatted()).font(.system(.title3, design: .rounded, weight: .semibold))
                                    .monospacedDigit()
                                    .underline(day == today)
                                DayActivityIcons(markers: markers)
                            }
                            .padding(.horizontal, 6).padding(.vertical, 12)
                            .frame(width: dayWidth, alignment: .top)
                            .background(day == selection ? palette.sage : palette.surface,
                                        in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous)
                                    .strokeBorder(day == selection || contrast == .increased ? palette.accent : palette.accent.opacity(0.10),
                                                  lineWidth: day == selection ? 2 : 1)
                            }
                        }
                        .buttonStyle(.plain).id(day.key)
                        .accessibilityLabel("\(DayText.full(day)). \(day == today ? "Today. " : "")\(markers.isEmpty ? "No recorded activities" : markers.map(\.title).joined(separator: ", "))")
                        .accessibilityAddTraits(day == selection ? .isSelected : [])
                        .accessibilityIdentifier("todayDate_\(day.key)")
                    }
                }.scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $centeredDay, anchor: .center)
            .accessibilityIdentifier("todayDateStrip")
            .onAppear { centeredDay = selection.key }
            .onChange(of: centeredDay) { _, key in
                guard let key, let day = try? LocalDay(key: key) else { return }
                let offset = today.days(until: day)
                if offset < lower + 7 { lower -= 30 }
                if offset > upper - 7 { upper += 30 }
            }
            .onChange(of: today) { old, new in
                if selection == old { selection = new; centeredDay = new.key }
            }
        }
        .environment(\.calendar, LocalDay.calendar)
        .environment(\.timeZone, LocalDay.calendar.timeZone)
    }
}
