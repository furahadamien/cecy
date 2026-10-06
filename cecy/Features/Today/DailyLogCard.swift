import SwiftUI

/// Selected-day records use the same presentation and editor as Calendar.
struct DailyLogCard: View {
    let session: TrackerSession
    let selectedDay: LocalDay
    let today: LocalDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecordedDayCard(session: session, day: selectedDay, today: today)
                .accessibilityIdentifier("todayRecordedDayCard")
            NavigationLink {
                TrackerPage(title: "Daily log history") {
                    DailyLogHistoryCard(session: session, selectedDay: selectedDay, today: today)
                }
                .navigationBarTitleDisplayMode(.inline)
            } label: {
                Label("View all daily logs", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(RecordActionButtonStyle())
            .accessibilityIdentifier("dailyLogHistory")
        }
    }
}

/// Retain paginated access to older records without crowding the selected day.
private struct DailyLogHistoryCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var listHeight = 280.0
    let session: TrackerSession
    let selectedDay: LocalDay
    let today: LocalDay
    @State private var pageBoundaries: [LocalDay] = []

    var body: some View {
        let days = session.activityIndex.loggedDays(before: pageBoundaries.last)
        RecordedEntryCard(accent: TrackerPalette(scheme: colorScheme).accent) {
            Text("Your daily logs").font(.headline).accessibilityAddTraits(.isHeader)
            Text("A quick glance at each day. Tap to view or manage its records.")
                .font(.footnote).foregroundStyle(.secondary)
            if selectedDay != today && !days.contains(selectedDay) {
                if session.activityIndex.markers(on: selectedDay).isEmpty {
                    Text("No records for \(DayText.full(selectedDay)).")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    dayRow(selectedDay)
                }
            }
            if days.isEmpty {
                Text(pageBoundaries.isEmpty ? "No records logged yet." : "No logs on this page.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(days) { day in
                            dayRow(day)
                            if day != days.last { Divider().padding(.vertical, 4) }
                        }
                    }
                    .padding(.trailing, 6)
                }
                .id(pageBoundaries.last)
                .frame(height: min(listHeight, 480))
                .clipped()
                .contentShape(Rectangle())
                .accessibilityIdentifier("dailyLogsList")
            }
            HStack {
                if !pageBoundaries.isEmpty {
                    Button("Newer days") { pageBoundaries.removeLast() }
                        .accessibilityIdentifier("newerLoggedDays")
                }
                Spacer(minLength: 8)
                if let last = days.last,
                   !session.activityIndex.loggedDays(before: last, limit: 1).isEmpty {
                    Button("Older days") { pageBoundaries.append(last) }
                        .accessibilityIdentifier("olderLoggedDays")
                }
            }
            .buttonStyle(RecordActionButtonStyle())
        }
    }

    private func dayRow(_ day: LocalDay) -> some View {
        let markers = session.activityIndex.markers(on: day)
        let palette = TrackerPalette(scheme: colorScheme)
        return NavigationLink {
            DailyLogDetailsView(session: session, day: day)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(DayText.full(day)).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    SelectionFlowLayout {
                        ForEach(markers) { marker in
                            Image(systemName: marker.symbol)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(marker.id == "period" ? palette.recorded
                                    : marker.id == "sexualActivity" ? palette.sexualActivity : palette.accent)
                                .frame(width: 32, height: 32)
                                .background(palette.background, in: Circle())
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DayText.full(day)), \(markers.map(\.title).joined(separator: ", "))")
        .accessibilityHint("Opens this day's recorded details and editing controls.")
        .accessibilityIdentifier("dailyLog_\(day.key)")
    }
}

struct DailyLogDetailsView: View {
    let session: TrackerSession
    let day: LocalDay

    var body: some View {
        TrackerPage(title: "Daily logs", subtitle: DayText.full(day)) {
            if session.activityIndex.markers(on: day).isEmpty {
                Text("No records for this date.").accessibilityIdentifier("emptyDailyLogs")
            }
            ForEach(session.snapshot.periods.filter { $0.contains(day) }) { period in
                // Period metadata belongs to an interval, not an independent daily record.
                Text("This day belongs to the period starting \(DayText.full(period.start)). Editing or deleting that period affects its full recorded date range, not only this day.")
                    .font(.footnote).foregroundStyle(.secondary)
                PeriodRecordSummary(session: session, period: period)
            }
            ForEach(session.snapshot.symptoms.filter { $0.day == day }) { entry in
                SymptomRecordView(session: session, entry: entry)
            }
            ForEach(session.snapshot.sexualActivities.filter { $0.day == day }) { entry in
                SexualActivityRecordView(session: session, entry: entry)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("dailyLogDetails_\(day.key)")
    }
}
