import SwiftUI

struct TodayView: View {
    @Bindable var session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    let onLog: (LocalDay) -> Void
    let onHistory: () -> Void
    @State private var showExplanation = false
    @State private var selection: LocalDay

    private var wellness: WellnessRecommendation? {
        guard session.canUseAI,
              let request = try? AIContextBuilder.wellness(snapshot: session.snapshot, today: today) else { return nil }
        return session.ai.wellness(for: request)
    }

    init(session: TrackerSession, today: LocalDay, overview: CycleOverview, onLog: @escaping (LocalDay) -> Void, onHistory: @escaping () -> Void) {
        self.session = session
        self.today = today
        self.overview = overview
        self.onLog = onLog
        self.onHistory = onHistory
        _selection = State(initialValue: today)
    }

    var body: some View {
        TrackerPage(title: "Today") {
            ActivityCalendarStrip(today: today, activityIndex: session.activityIndex,
                                  forecast: session.cycleForecast, selection: $selection)
            TrackerCompactLogActions {
                Button { onLog(selection) } label: {
                    Label("Log period", systemImage: "drop")
                }
                .buttonStyle(TrackerCompactLogButtonStyle(prominent: true))
                .accessibilityLabel("Log period and bleeding days")
                .accessibilityIdentifier("logPeriod")
                SymptomLogButton(session: session, day: selection, title: "Symptoms", compact: true)
                SexualActivityLogButton(session: session, day: selection, compact: true)
            }
            .disabled(selection > today)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Log for \(DayText.full(selection))")
            .accessibilityIdentifier("todayLogActions")
            TodayCalendarLegend()
            ForEach(session.cycleForecast.cycles.filter { selection != today && $0.contains(selection) }) { cycle in
                TrackerCard { ProjectedCycleDetails(cycle: cycle) }
            }
            TrackerCard(highlighted: true) {
                Label("Until your next period", systemImage: "leaf").font(.subheadline.weight(.medium))
                let countdown = TodayPeriodCountdown(outcome: overview.prediction, today: today)
                Text(countdown.title)
                    .font(TrackerTypography.metric).monospacedDigit()
                    .accessibilityIdentifier("periodCountdown")
                if let day = overview.currentDay, let start = overview.latestStart {
                    Text("Day \(day)")
                        .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        .accessibilityIdentifier("cycleDay")
                        .accessibilityHint("Current cycle, counted from your recorded start on \(DayText.full(start))")
                }
                Text(countdown.detail).font(.footnote).foregroundStyle(.secondary)
            }
            TrackerCard {
                PredictionSummary(outcome: overview.prediction, today: today, forecast: session.cycleForecast)
                if session.cycleForecast.nextPeriod(onOrAfter: today) != nil {
                    Button("How this estimate works") { showExplanation = true }
                        .frame(minHeight: 44)
                }
            }
            TrackerCard {
                Text("For today").font(.headline).accessibilityAddTraits(.isHeader)
                if session.privacy.dailyInsightsEnabled {
                    DailyInsightsContent(session: session)
                }
                if let wellness {
                    WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: today)
                    VStack(alignment: .leading, spacing: 12) {
                        if let movement = wellness.movementSuggestions.first { wellnessRow("Movement", text: movement, symbol: "figure.walk") }
                        if let food = wellness.foodSuggestions.first { wellnessRow("Food", text: food, symbol: "fork.knife") }
                        wellnessRow("Hydration", text: wellness.hydrationSuggestion, symbol: "drop")
                        if let recovery = wellness.recoverySuggestions.first { wellnessRow("Recovery", text: recovery, symbol: "leaf") }
                        AISafetyNotice(message: wellness.safetyMessage)
                    }.accessibilityIdentifier("todayWellnessSuggestions")
                } else {
                    Text("Food, movement and recovery ideas based on today’s logs. Generate when you’re ready.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                NavigationLink {
                    AIFeatureView(session: session, feature: .wellness)
                } label: {
                    Label(wellness == nil ? "Get today’s suggestions" : "View all suggestions", systemImage: "sparkles")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("dailyWellnessAI")
                NavigationLink("Edit wellness preferences") { ProfileSettingsView(session: session) }
                    .frame(minHeight: 44).font(.subheadline)
                    .accessibilityIdentifier("todayWellnessPreferences")
                DisclosureGroup("Daily preparation") { DailyInsightsPreference(session: session) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("forTodayCard")
            TrackerCard { UpcomingCycleForecastView(forecast: session.cycleForecast, today: today) }
            DailyLogCard(session: session, selectedDay: selection, today: today)
            if let confirmation = session.confirmation {
                TrackerCard {
                    Label(confirmation, systemImage: "checkmark.circle")
                        .accessibilityIdentifier("saveConfirmation")
                    Button("Dismiss confirmation") { session.confirmation = nil }
                }
                .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
            }
            NavigationLink("Sexual activity history") { SexualActivityHistoryView(session: session) }
                .frame(minHeight: 44).accessibilityIdentifier("sexualActivityHistory")
            Button("Add previous periods", action: onHistory)
                .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
            if let insight = session.insights.first { InsightCard(insight: insight) }
            if let message = session.insightMessage { InlineError(message: message) }
        }
        .onChange(of: today) { old, new in if selection == old { selection = new } }
        .sheet(isPresented: $showExplanation) {
            if let cycle = session.cycleForecast.nextPeriod(onOrAfter: today),
               cycle.isLaterProjection || cycle.referenceNotice != nil {
                NavigationStack {
                    TrackerPage(title: "About this projection") { TrackerCard { ProjectedCycleDetails(cycle: cycle, notBefore: today) } }
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showExplanation = false } } }
                }
            } else if let estimate = overview.estimate {
                PredictionExplanation(estimate: estimate, sources: Array(overview.intervals.suffix(6)), replay: session.predictionReplay)
            }
        }
    }

    private func wellnessRow(_ title: String, text: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
            Text(verbatim: text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Presentation only: never rolls a missed estimate into an unrecorded new cycle.
@MainActor struct TodayPeriodCountdown {
    let title: String
    let detail: String

    init(outcome: PredictionOutcome, today: LocalDay) {
        switch outcome {
        case .available(let estimate):
            let days = today.days(until: estimate.center)
            if days > 0 {
                title = days == 1 ? "About 1 day" : "About \(days) days"
            } else if days == 0 {
                title = "Estimated today"
            } else if today <= estimate.latest {
                title = "Within estimated window"
            } else {
                title = "Estimated window passed"
            }
            detail = "Possible start: \(DayText.range(estimate.earliest, estimate.latest)). An estimate, not a deadline. Missing records can affect it."
        case .insufficientHistory:
            title = "More history needed"
            detail = "Record a period start and your usual cycle length, or add previous starts, for an estimate."
        case .wideVariation:
            title = "Timing uncertain"
            detail = "Your recorded intervals vary too much for a reliable countdown. Your current cycle day still counts from recorded dates."
        case .unavailable(let reason):
            title = "Estimate unavailable"
            detail = reason.localizedDescription
        }
    }
}

struct PredictionSummary: View {
    let outcome: PredictionOutcome
    let today: LocalDay
    let forecast: CycleForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated next period start").font(.headline).accessibilityAddTraits(.isHeader)
            if let cycle = forecast.nextPeriod(onOrAfter: today) {
                Text(DayText.range(max(today, cycle.period.earliest), cycle.period.latest))
                    .font(TrackerTypography.sectionTitle).accessibilityIdentifier("predictionWindow")
                Text("Around \(DayText.short(cycle.period.center))").font(.subheadline)
                    .accessibilityIdentifier("nextPeriodCenter")
                let confidence = primaryConfidence(cycle)
                Label("\(confidence.rawValue) confidence · Rough estimate", systemImage: "circle.dashed")
                    .font(.subheadline)
                if cycle.referenceNotice != nil {
                    Text("Typical-cycle reference · Review recorded starts")
                        .font(.subheadline).accessibilityIdentifier("referencePrediction")
                } else if cycle.isLaterProjection {
                    Text("Provisional projection · Earlier periods are not confirmed")
                        .font(.subheadline).accessibilityIdentifier("projectedPrediction")
                } else if case .available(let estimate) = outcome, estimate.basis == .usualCycle {
                    Text("Starter estimate · based on your usual \(estimate.reportedCycleDays ?? 28)-day cycle, not measured cycle history.")
                        .font(.subheadline).accessibilityIdentifier("starterPrediction")
                }
            } else {
            switch outcome {
            case .available:
                Text("No upcoming date can be estimated. Review your recorded starts.")
            case .insufficientHistory:
                Text("More history is needed for an estimate.").font(.title3)
            case .wideVariation:
                Text("Your recorded intervals vary more than this simple estimate can support.")
            case .unavailable(let reason):
                Text(reason.localizedDescription)
            }
            }
        }
    }

    private func primaryConfidence(_ cycle: ProjectedCycle) -> PredictionConfidence {
        if !cycle.isLaterProjection, cycle.referenceNotice == nil, case .available(let estimate) = outcome {
            return estimate.confidence
        }
        return .low
    }
}

struct PredictionExplanation: View {
    @Environment(\.dismiss) private var dismiss
    let estimate: CyclePrediction
    let sources: [CycleInterval]
    let replay: PredictionReplay?

    var body: some View {
        NavigationStack {
            TrackerPage(title: "About this estimate") {
                TrackerCard(highlighted: true) {
                    Text(DayText.range(estimate.earliest, estimate.latest)).font(TrackerTypography.sectionTitle)
                    Text("Possible next start dates, not a predicted bleeding duration.")
                    Text("\(estimate.confidence.rawValue) confidence · Provisional")
                }
                if estimate.basis == .usualCycle {
                    TrackerCard {
                        Text("A starting point, not measured history").font(.headline)
                        Text("We add your usual cycle length (\(estimate.reportedCycleDays ?? 28) days) to your latest recorded start. The range adds three days on either side as a provisional display rule, not a measured probability or Apple’s algorithm.")
                        Text("The same calculation uses measured intervals as soon as they are available—there is no four-period threshold. With no completed interval, your usual length supplies the starting point and confidence stays low. If the window passes, we don’t invent another period or roll the estimate forward.")
                        Text("Your typical bleeding duration does not create an end date. Add confirmed ends separately.")
                    }
                } else {
                TrackerCard {
                    Text("The recorded intervals behind it").font(.headline)
                    Text(estimate.sourceLengths.map { "\($0)" }.joined(separator: ", ") + " days")
                    Text("The same calculation works from the first recorded start onward. With measured intervals available, it uses up to six recent intervals: the median for the center and two days around the shortest and longest. One interval is limited evidence, not an established pattern.")
                    Text(PredictionEvidence.policy).font(.caption)
                    if let replay {
                        Text(PredictionEvidence.assess(sourceLengths: estimate.sourceLengths, replay: replay).reason)
                            .accessibilityIdentifier("confidenceReason")
                    }
                    Text("Confidence thresholds are provisional display rules, not measured probabilities. Historical coverage is not a future probability.")
                    Text("There is no guaranteed start date. Records are never discarded merely because an interval is unusual.")
                        .foregroundStyle(.secondary)
                }
                TrackerCard {
                    Text("Source dates").font(.headline)
                    ForEach(sources) { source in
                        Text("\(DayText.range(source.start, source.nextStart)): \(source.length) days")
                    }
                    Text("Intervals older than the six most recent remain in your records but do not enter this window. No interval is excluded for being unusually long or short.")
                }
                NavigationLink("Prediction history check") { PredictionHistoryView(replay: replay) }
                    .frame(minHeight: 44).accessibilityIdentifier("predictionReplayLink")
                }
                Text(OvulationNotice.explanation).font(.footnote)
                Text("This is an uncalibrated estimate, not medical advice. Missing records affect it. Do not use it for contraception or diagnosis.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
