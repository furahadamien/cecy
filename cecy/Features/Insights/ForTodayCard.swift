import SwiftUI

/// Presentation only; daily requests remain owned by TrackerSession.
struct ForTodayCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPreparation = false
    let session: TrackerSession
    let today: LocalDay
    private var wellness: WellnessRecommendation? {
        guard session.canUseAI,
              let request = try? AIContextBuilder.wellness(snapshot: session.snapshot, today: today) else { return nil }
        return session.ai.wellness(for: request)
    }

    var body: some View {
        TrackerCard {
            InsightSectionHeader(title: "For today", symbol: "leaf")
            DailyInsightsContent(session: session, styled: true)
            if let wellness {
                WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: today)
                VStack(alignment: .leading, spacing: 12) {
                    if let movement = wellness.movementSuggestions.first { row("Movement", text: movement, symbol: "figure.walk") }
                    if let food = wellness.foodSuggestions.first { row("Food", text: food, symbol: "fork.knife") }
                    row("Hydration", text: wellness.hydrationSuggestion, symbol: "drop")
                    if let recovery = wellness.recoverySuggestions.first { row("Recovery", text: recovery, symbol: "leaf") }
                    AISafetyNotice(message: wellness.safetyMessage)
                }.accessibilityIdentifier("todayWellnessSuggestions")
            }
            NavigationLink { AIFeatureView(session: session, feature: .wellness) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.title).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wellness == nil ? "Get today’s suggestions" : "View all suggestions").font(.headline)
                        Text("Food, movement and recovery ideas based on your logs.").font(.subheadline)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .foregroundStyle(.white).padding(18).frame(minHeight: 44)
                .background(TrackerPalette(scheme: colorScheme).action, in: RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain).accessibilityIdentifier("dailyWellnessAI")
            Divider()
            NavigationLink { ProfileSettingsView(session: session) } label: {
                TrackerNavigationLabel(title: "Edit wellness preferences", symbol: "gearshape", detail: "Personalize your suggestions.")
            }.buttonStyle(.plain).accessibilityIdentifier("todayWellnessPreferences")
            Divider()
            Button { showPreparation.toggle() } label: {
                HStack {
                    TrackerNavigationLabel(title: "Daily preparation", symbol: "list.clipboard", detail: "Optional daily insights.", showsChevron: false)
                    Image(systemName: showPreparation ? "chevron.down" : "chevron.right").accessibilityHidden(true)
                }.contentShape(Rectangle())
            }
                .buttonStyle(.plain)
                .accessibilityLabel("Daily preparation")
                .accessibilityValue(showPreparation ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("dailyPreparationOptions")
            if showPreparation { DailyInsightsPreference(session: session) }
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
