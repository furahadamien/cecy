import SwiftUI

struct TodayView: View {
    @Bindable var session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    let onLog: (LocalDay) -> Void
    let onHistory: () -> Void
    @State private var showExplanation = false
    @State private var selection: LocalDay

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
            VStack(alignment: .leading, spacing: 8) {
                Button { onLog(selection) } label: {
                    Label("Log period", systemImage: "drop.fill")
                }
                .buttonStyle(TrackerCompactLogButtonStyle(prominent: true))
                .accessibilityLabel("Log period")
                .accessibilityHint("Record a period start or update its end date.")
                .accessibilityIdentifier("logPeriod")
                TrackerCompactLogActions {
                    SymptomLogButton(session: session, day: selection, title: "Symptoms", compact: true)
                    SexualActivityLogButton(session: session, day: selection, compact: true)
                    DailyBleedingLogButton(session: session, day: selection)
                }
            }
            .environment(\.compactLogLabels, true)
            .disabled(selection > today)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Log for \(DayText.full(selection))")
            .accessibilityIdentifier("todayLogActions")
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
                if overview.estimate != nil {
                    PredictionSummary(outcome: overview.prediction, today: today)
                    Button("How this estimate works") { showExplanation = true }
                        .frame(minHeight: 44)
                } else {
                    Text(countdown.detail).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("nextPeriodCard")
            CyclePhaseRingView(session: session, today: today, overview: overview)
            if !session.cycleForecast.cycles.isEmpty {
                TodayEstimatesCard(forecast: session.cycleForecast, today: today)
                TrackerCard { UpcomingCycleForecastView(forecast: session.cycleForecast, today: today) }
            }
            DailyLogCard(session: session, selectedDay: selection, today: today)
            if let confirmation = session.confirmation {
                TrackerCard {
                    Label(confirmation, systemImage: "checkmark.circle")
                        .accessibilityIdentifier("saveConfirmation")
                    Button("Dismiss confirmation") { session.confirmation = nil }
                }
                .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
            }
            if let insight = session.insights.first { InsightCard(insight: insight) }
            if let message = session.insightMessage { InlineError(message: message) }
        }
        .onChange(of: today) { old, new in if selection == old { selection = new } }
        .sheet(isPresented: $showExplanation) {
            if let estimate = overview.estimate {
                PredictionExplanation(estimate: estimate, sources: Array(overview.intervals.suffix(6)), replay: session.predictionReplay)
            }
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
            detail = "Log periods as they happen. Estimates can come later."
        case .wideVariation:
            title = "Timing uncertain"
            detail = "Your recorded cycles vary. Keep tracking without a date estimate."
        case .unavailable(let reason):
            title = "Estimate unavailable"
            detail = reason.localizedDescription
        }
    }
}

struct PredictionSummary: View {
    @Environment(\.colorScheme) private var colorScheme
    let outcome: PredictionOutcome
    let today: LocalDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if case .available(let estimate) = outcome {
                VStack(alignment: .leading, spacing: 8) {
                Label("Estimated period start window", systemImage: "circle.dashed").font(.headline)
                Text(DayText.range(estimate.earliest, estimate.latest))
                    .font(TrackerTypography.sectionTitle).accessibilityIdentifier("predictionWindow")
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(TrackerPalette(scheme: colorScheme).recordedSurface, in: RoundedRectangle(cornerRadius: 16))
                Text("Around \(DayText.short(estimate.center))").font(.subheadline)
                    .accessibilityIdentifier("nextPeriodCenter")
                Label("\(estimate.confidence.rawValue) confidence · Rough estimate", systemImage: "circle.dashed")
                    .font(.subheadline)
                if let notice = estimate.starterNotice {
                    Text(notice)
                        .font(.subheadline).accessibilityIdentifier("starterPrediction")
                }
                Text("Possible start dates, not confirmed bleeding days. Missing records can affect timing.").font(.footnote).foregroundStyle(.secondary)
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
                if let notice = estimate.starterNotice {
                    TrackerCard {
                        Text("A starting point, not measured history").font(.headline)
                        Text(notice)
                        Text("We count from your recorded start, with three days on either side of the estimated next start. This is a rough range, not a probability.")
                        Text("New records replace assumptions. Estimated period days never become recorded days, and an overdue estimate does not start a new cycle.")
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
