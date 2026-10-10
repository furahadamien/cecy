import SwiftUI

struct DailyInsightsPreference: View {
    let session: TrackerSession
    @State private var confirmEnable = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AIConsentControl(session: session)
            Toggle("Prepare automatically on Today", isOn: Binding(
                get: { session.privacy.dailyInsightsEnabled },
                set: { enabled in
                    if enabled { confirmEnable = true }
                    else {
                        session.dailyAI.invalidate()
                        error = session.privacy.setDailyInsightsEnabled(false)
                    }
                }))
                .disabled(!session.canUseAI || (session.dailyInsightRequest == nil && !session.privacy.dailyInsightsEnabled))
                .accessibilityIdentifier("dailyInsightsToggle")
            if session.snapshot.profile?.wellnessPreferences?.isReadyForInsights != true {
                Text(session.privacy.dailyInsightsEnabled ? "Preparation paused · Finish setup" : "Finish setup to prepare daily insights.")
                    .font(.caption).foregroundStyle(.secondary)
                NavigationLink("Finish insight setup") { DailyInsightSetupView(session: session) }
                    .accessibilityIdentifier("finishInsightSetup")
            }
            if let error { InlineError(message: error) }
        }
        .alert("Prepare daily insights automatically?", isPresented: $confirmEnable) {
            Button("Not now", role: .cancel) {}
            Button("Enable daily insights") {
                error = session.privacy.setDailyInsightsEnabled(true)
                if error == nil { session.preloadDailyInsights() }
            }.accessibilityIdentifier("enableDailyInsights")
        } message: {
            Text("Once a day when you open Cecy, your cycle day, today’s selected symptoms, activity, exercise, diet, allergies and wellness goals may be sent to Azure and OpenAI. No private notes, identity, sexual-activity records or full history are sent. Results appear on Today and stay on this device until the day ends. Turn this off here or in Privacy and export.")
        }
    }
}

struct DailyInsightsCard: View {
    let session: TrackerSession

    var body: some View {
        TrackerCard {
            InsightSectionHeader(title: "Today’s insights", symbol: "sparkles")
            if let output = session.dailyInsightOutput, case .wellness(let value) = output {
                VStack(alignment: .leading, spacing: 16) {
                    suggestions("Food", symbol: "fork.knife", items: value.foodSuggestions)
                    suggestions("Movement", symbol: "figure.walk", items: value.movementSuggestions)
                    suggestions("Hydration", symbol: "drop", items: [value.hydrationSuggestion])
                    suggestions("Recovery", symbol: "leaf", items: value.recoverySuggestions)
                    WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: session.today)
                    AISafetyNotice(message: value.safetyMessage)
                    DisclosureGroup("Why these?") { Text(verbatim: value.explanation).font(.subheadline) }
                    Text("AI-generated · Not medical advice. Check ingredients against your allergies. New insights tomorrow.")
                        .font(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .contain).accessibilityIdentifier("todayWellnessSuggestions")
            } else if session.dailyAI.isLoading {
                AIRequestStatus(coordinator: session.dailyAI, label: "Preparing today’s insights")
            } else if session.snapshot.profile?.wellnessPreferences?.isReadyForInsights != true {
                Text(session.privacy.dailyInsightsEnabled ? "Preparation paused · Finish setup" : "Personalize your daily insights")
                    .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("dailyInsightsNeedsSetup")
                NavigationLink("Finish insight setup") { DailyInsightSetupView(session: session) }
                    .frame(minHeight: 44).accessibilityIdentifier("finishInsightSetup")
            } else if !session.canUseAI {
                AIConsentControl(session: session)
            } else {
                AIRequestStatus(coordinator: session.dailyAI)
                Text(session.dailyAI.message == nil ? "Today’s insights haven’t been prepared yet." : "Today’s insights couldn’t be prepared.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button(session.dailyAI.message == nil ? "Prepare today’s insights" : "Try again") {
                    session.prepareTodayInsights()
                }.buttonStyle(TrackerPrimaryButtonStyle()).accessibilityIdentifier("prepareDailyInsights")
            }
            NavigationLink { AIFeatureView(session: session, feature: .wellness) } label: {
                Label("Insight settings", systemImage: "slider.horizontal.3")
                    .font(.subheadline).frame(minHeight: 44)
            }.buttonStyle(.plain).accessibilityIdentifier("dailyWellnessAI")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyInsightsCard")
        .task(id: session.dailyInsightRequest) { session.preloadDailyInsights() }
    }

    private func suggestions(_ title: String, symbol: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(verbatim: item).font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DailyInsightSetupView: View {
    let session: TrackerSession
    @State private var preferences: WellnessPreferences?

    init(session: TrackerSession) {
        self.session = session
        _preferences = State(initialValue: session.snapshot.profile?.wellnessPreferences)
    }

    var body: some View {
        WellnessPreferencesView(preferences: $preferences,
            saveTitle: session.canUseAI ? "Save & prepare" : "Save",
            onSave: session.saveDailyInsightPreferences)
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
