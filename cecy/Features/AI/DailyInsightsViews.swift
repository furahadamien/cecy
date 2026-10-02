import SwiftUI

struct DailyInsightsPreference: View {
    let session: TrackerSession
    @State private var confirmEnable = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AIConsentControl(session: session)
            Toggle("Prepare daily insights", isOn: Binding(
                get: { session.privacy.dailyInsightsEnabled },
                set: { enabled in
                    if enabled { confirmEnable = true }
                    else {
                        session.dailyAI.invalidate()
                        error = session.privacy.setDailyInsightsEnabled(false)
                    }
                }))
                .disabled(!session.canUseAI)
                .accessibilityIdentifier("dailyInsightsToggle")
            Text("Once a day when you open Cecy, selected cycle and symptom summaries can be sent automatically. Off by default.")
                .font(.caption).foregroundStyle(.secondary)
            if let error { InlineError(message: error) }
        }
        .alert("Prepare daily insights automatically?", isPresented: $confirmEnable) {
            Button("Not now", role: .cancel) {}
            Button("Enable daily insights") {
                error = session.privacy.setDailyInsightsEnabled(true)
            }.accessibilityIdentifier("enableDailyInsights")
        } message: {
            Text("On your first unlocked app visit each day, Cecy may send selected cycle and symptom summaries to Azure and OpenAI. No private notes, identity, sexual activity or full history are sent. Generated text stays in memory only. Turn this off here or in Privacy and export.")
        }
    }
}

struct DailyInsightsCard: View {
    let session: TrackerSession

    var body: some View {
        TrackerCard {
            Label("Today’s insights", systemImage: "sun.max").font(.headline)
                .accessibilityAddTraits(.isHeader)
            if let output = session.dailyInsightOutput {
                AIOutputView(output: output)
            } else if let today = session.today {
                let answers = PreparedRecordAnswers.build(snapshot: session.snapshot, today: today)
                Text(answers[0].answer).font(.subheadline)
                Text(answers[1].answer).font(.footnote).foregroundStyle(.secondary)
                Text("Calculated on this device").font(.caption).foregroundStyle(.secondary)
            }
            AIRequestStatus(coordinator: session.dailyAI)
            if session.privacy.dailyInsightsEnabled && !session.dailyAI.isLoading && session.dailyInsightOutput == nil {
                Text("Your local facts are ready. You can generate an explanation manually if today’s automatic request is unavailable.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Daily preparation") { DailyInsightsPreference(session: session) }
                .accessibilityIdentifier("dailyPreparationOptions")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyInsightsCard")
    }
}