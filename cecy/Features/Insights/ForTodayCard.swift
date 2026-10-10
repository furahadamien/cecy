import SwiftUI

/// Presentation only; daily requests remain owned by TrackerSession.
struct ForTodayCard: View {
    let session: TrackerSession
    let today: LocalDay

    var body: some View {
        DailyInsightsCard(session: session)
            .accessibilityIdentifier("forTodayCard")
    }
}
