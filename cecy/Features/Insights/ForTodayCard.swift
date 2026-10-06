import SwiftUI

/// Presentation only; daily requests remain owned by TrackerSession.
struct ForTodayCard: View {
    let session: TrackerSession
    let today: LocalDay
    private var wellness: WellnessRecommendation? {
        guard session.canUseAI,
              let request = try? AIContextBuilder.wellness(snapshot: session.snapshot, today: today) else { return nil }
        return session.ai.wellness(for: request)
    }

    var body: some View {
        TrackerCard {
            Text("For today").font(.headline).accessibilityAddTraits(.isHeader)
            DailyInsightsContent(session: session)
            if let wellness {
                WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: today)
                VStack(alignment: .leading, spacing: 12) {
                    if let movement = wellness.movementSuggestions.first { row("Movement", text: movement, symbol: "figure.walk") }
                    if let food = wellness.foodSuggestions.first { row("Food", text: food, symbol: "fork.knife") }
                    row("Hydration", text: wellness.hydrationSuggestion, symbol: "drop")
                    if let recovery = wellness.recoverySuggestions.first { row("Recovery", text: recovery, symbol: "leaf") }
                    AISafetyNotice(message: wellness.safetyMessage)
                }.accessibilityIdentifier("todayWellnessSuggestions")
            } else {
                Text("Food, movement and recovery ideas based on today’s logs. Generate when you’re ready.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            NavigationLink { AIFeatureView(session: session, feature: .wellness) } label: {
                Label(wellness == nil ? "Get today’s suggestions" : "View all suggestions", systemImage: "sparkles")
                    .frame(minHeight: 44)
            }.accessibilityIdentifier("dailyWellnessAI")
            NavigationLink("Edit wellness preferences") { ProfileSettingsView(session: session) }
                .frame(minHeight: 44).font(.subheadline).accessibilityIdentifier("todayWellnessPreferences")
            DisclosureGroup("Daily preparation") { DailyInsightsPreference(session: session) }
                .accessibilityIdentifier("dailyPreparationOptions")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("forTodayCard")
    }
    private func row(_ title: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            Text(verbatim: text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
