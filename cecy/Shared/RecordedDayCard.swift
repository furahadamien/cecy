import SwiftUI

/// The same recorded-day surface and editing controls on Today and Calendar.
struct RecordedDayCard: View {
    @Environment(\.calendarRecordStyle) private var calendarStyle
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let day: LocalDay
    let today: LocalDay

    var body: some View {
        TrackerCard {
            VStack(alignment: .leading, spacing: 12) {
                if calendarStyle {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            dateHeading
                            Spacer(minLength: 8)
                            todayBadge
                        }
                        VStack(alignment: .leading, spacing: 6) { dateHeading; todayBadge }
                    }
                    .padding(12)
                    .background(TrackerPalette(scheme: colorScheme).recordedSurface.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                } else {
                    Text(DayText.full(day)).font(.headline).accessibilityAddTraits(.isHeader)
                    if day == today { Text("Today").font(.subheadline) }
                }
                if let answer = session.snapshot.dailyBleeding.first(where: { $0.day == day }) {
                    DailyBleedingRecordView(session: session, observation: answer)
                    Divider()
                }
                if let period = session.snapshot.periods.first(where: { $0.contains(day) }) {
                    PeriodRecordSummary(session: session, period: period,
                                        title: period.start == day ? "Recorded period start" : "Confirmed bleeding day")
                } else {
                    Text("No period recorded for this day.")
                }
                if session.snapshot.symptoms.contains(where: { $0.day == day }) {
                    Divider()
                    CalendarSymptomGroup(session: session, day: day)
                        .id(day)
                }
                ForEach(session.snapshot.sexualActivities.filter { $0.day == day }) { entry in
                    Divider()
                    SexualActivityRecordView(session: session, entry: entry)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("selectedCalendarDetails")
        }
        .environment(\.recordsShareSurface, true)
    }

    private var dateHeading: some View {
        Text(DayText.full(day)).font(.system(.title3, design: .serif, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var todayBadge: some View {
        if day == today { Text("Today").font(.caption).foregroundStyle(.secondary) }
    }
}
