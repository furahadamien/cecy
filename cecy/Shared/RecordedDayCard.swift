import SwiftUI

/// The same recorded-day surface and editing controls on Today and Calendar.
struct RecordedDayCard: View {
    let session: TrackerSession
    let day: LocalDay
    let today: LocalDay

    var body: some View {
        TrackerCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(DayText.full(day)).font(.headline).accessibilityAddTraits(.isHeader)
                if day == today { Text("Today").font(.subheadline) }
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
}
