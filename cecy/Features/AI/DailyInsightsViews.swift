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
            DailyInsightsContent(session: session)
            DisclosureGroup("Daily preparation") { DailyInsightsPreference(session: session) }
                .accessibilityIdentifier("dailyPreparationOptions")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyInsightsCard")
    }
}

/// Both tabs observe the same coordinator; presentation never starts a second request.
struct DailyInsightsContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: TrackerSession
    var styled = false

    var body: some View {
        Group {
            if let output = session.dailyInsightOutput {
                Text("AI-generated daily insights").font(.caption).foregroundStyle(.secondary)
                AIOutputView(output: output)
            } else if let today = session.today {
                let answers = PreparedRecordAnswers.build(snapshot: session.snapshot, today: today)
                if styled {
                    let periods = session.snapshot.periods.filter { $0.start <= today }
                    let ends = periods.filter { $0.end != nil }.count
                    let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
                    layout {
                        metric(periods.count, title: "period starts recorded", symbol: "drop.fill", tint: TrackerPalette(scheme: colorScheme).recorded)
                        metric(ends, title: "confirmed ends", symbol: "circle.dashed", tint: TrackerPalette(scheme: colorScheme).accent)
                    }
                    .padding(14)
                    .background(TrackerPalette(scheme: colorScheme).sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(answers[0].answer)
                    .accessibilityIdentifier("localPeriodFacts")
                    if ends < periods.count {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle").foregroundStyle(TrackerPalette(scheme: colorScheme).recorded).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Missing period ends").font(.headline)
                                Text("Add an end when known to track bleeding duration.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(TrackerPalette(scheme: colorScheme).recordedSurface, in: RoundedRectangle(cornerRadius: 20))
                    }
                } else {
                    Text(answers[0].answer).font(.subheadline)
                }
                Text(answers[1].answer).font(.footnote).foregroundStyle(.secondary)
                Text("Calculated on this device").font(.caption).foregroundStyle(.secondary)
            }
            AIRequestStatus(coordinator: session.dailyAI)
            if session.privacy.dailyInsightsEnabled && !session.dailyAI.isLoading && session.dailyInsightOutput == nil {
                Text("Your local facts are ready. You can generate an explanation manually if today’s automatic request is unavailable.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ count: Int, title: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint)
                .frame(width: 42, height: 42).background(tint.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(count.formatted()).font(TrackerTypography.metric).monospacedDigit()
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
