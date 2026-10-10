import SwiftUI

struct TodayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        TrackerPage(title: "Today", showsHeading: false,
                    backgroundColor: colorScheme == .dark ? TrackerPalette(scheme: colorScheme).background : Color(red: 0.965, green: 0.980, blue: 0.963),
                    sectionSpacing: 12, topInset: 6) {
            ActivityCalendarStrip(today: today, activityIndex: session.activityIndex,
                                  forecast: session.cycleForecast, selection: $selection, compact: true)
            hero
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { loggingButtons }
                } else {
                    HStack(alignment: .top, spacing: 8) { loggingButtons }
                }
            }
            .environment(\.todayLogCards, true)
            .disabled(selection > today)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Log for \(DayText.full(selection))")
            .accessibilityIdentifier("todayLogActions")
            CyclePhaseRingView(session: session, today: today, overview: overview)
            ForEach(session.cycleForecast.cycles.filter { selection != today && $0.contains(selection) }) { cycle in
                TrackerCard { ProjectedCycleDetails(cycle: cycle, todayStyle: true) }
            }
            DailyInsightsCard(session: session)
            if !session.cycleForecast.cycles.isEmpty {
                TrackerCard { UpcomingCycleForecastView(forecast: session.cycleForecast, today: today, todayStyle: true) }
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

    private var hero: some View {
        TrackerCard(padding: 12, spacing: 8) {
            if dynamicTypeSize > .large {
                VStack(spacing: 20) { heroRing.frame(height: 250); countdown }
            } else {
                TodayHeroColumns {
                    heroRing
                    countdown
                }
            }
            if let estimate = overview.estimate {
                Label("\(estimate.confidence.rawValue) confidence · Rough estimate", systemImage: "circle.dashed")
                    .font(.caption).foregroundStyle(.secondary)
                if let notice = estimate.starterNotice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("starterPrediction")
                }
            }
            if let status = TodayCurrentPeriodStatus(periods: session.snapshot.periods,
                                                     forecast: session.cycleForecast, today: today, dailyBleeding: session.snapshot.dailyBleeding) {
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill").font(.title3).foregroundStyle(TrackerPalette(scheme: colorScheme).recorded).accessibilityHidden(true)
                    Text(status.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(status.title)
                .accessibilityIdentifier("currentPeriodStatus")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nextPeriodCard")
    }

    private var heroRing: some View {
        CyclePhaseRingView(session: session, today: today, overview: overview, ringOnly: true)
    }

    private var countdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            if overview.estimate != nil {
                Button { showExplanation = true } label: {
                    HStack(spacing: 6) {
                        Text("Until your next period")
                        Image(systemName: "questionmark.circle").accessibilityHidden(true)
                    }
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How this estimate works")
            } else {
                Text("Until your next period").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            let value = TodayPeriodCountdown(outcome: overview.prediction, today: today)
            Text(value.title).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("periodCountdown")
            if overview.estimate != nil {
                PredictionSummary(outcome: overview.prediction, today: today, compact: true)
            } else {
                Text(value.detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var loggingButtons: some View {
        Button { onLog(selection) } label: {
            Label { Text("Log period") } icon: { Image(systemName: "drop.fill").foregroundStyle(TrackerPalette(scheme: colorScheme).recorded) }
        }
        .buttonStyle(TrackerCompactLogButtonStyle(prominent: true))
        .accessibilityLabel("Log period")
        .accessibilityHint("Record a period start or update its end date.")
        .accessibilityIdentifier("logPeriod")
        SymptomLogButton(session: session, day: selection, title: "Symptoms", compact: true)
        SexualActivityLogButton(session: session, day: selection, compact: true)
        DailyBleedingLogButton(session: session, day: selection)
    }

}

/// Propose each column's actual width rather than testing unwrapped text widths.
private struct TodayHeroColumns: Layout {
    private func columns(_ width: CGFloat) -> (ring: CGFloat, detail: CGFloat) {
        let ring = min(250, width * 0.44)
        return (ring, max(0, width - ring - 12))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 330
        let sizes = columns(width)
        let detail = subviews[1].sizeThatFits(ProposedViewSize(width: sizes.detail, height: nil))
        return CGSize(width: width, height: max(sizes.ring, detail.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let sizes = columns(bounds.width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY - sizes.ring / 2), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes.ring, height: sizes.ring))
        subviews[1].place(at: CGPoint(x: bounds.minX + sizes.ring + 12, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes.detail, height: bounds.height))
    }
}

/// Uses today's evidence, not the selected calendar day or an assumed ongoing period.
nonisolated enum TodayCurrentPeriodStatus: Equatable {
    case recorded, estimated

    init?(periods: [Period], forecast: CycleForecast, today: LocalDay, dailyBleeding: [DailyBleedingObservation] = []) {
        if PeriodLogSelection.existing(on: today, periods: periods, dailyBleeding: dailyBleeding) != nil {
            self = .recorded
        } else if forecast.bleeding(on: today) != nil {
            self = .estimated
        } else {
            return nil
        }
    }

    var title: String {
        self == .recorded ? "You’re on your period" : "You may be on your period"
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
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 12) {
            if case .available(let estimate) = outcome {
                VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                Label("Estimated period start window", systemImage: "circle.dashed").font(compact ? .caption : .headline)
                Text(DayText.range(estimate.earliest, estimate.latest))
                    .font(compact ? .subheadline.weight(.semibold) : TrackerTypography.sectionTitle).accessibilityIdentifier("predictionWindow")
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(compact ? 8 : 12)
                .background(TrackerPalette(scheme: colorScheme).recordedSurface, in: RoundedRectangle(cornerRadius: 16))
                Text("Around \(DayText.short(estimate.center))").font(compact ? .caption : .subheadline)
                    .accessibilityIdentifier("nextPeriodCenter")
                if !compact {
                Label("\(estimate.confidence.rawValue) confidence · Rough estimate", systemImage: "circle.dashed")
                    .font(compact ? .caption : .subheadline)
                if let notice = estimate.starterNotice {
                    Text(notice)
                        .font(compact ? .caption : .subheadline).foregroundStyle(.secondary).accessibilityIdentifier("starterPrediction")
                }
                    Text("Possible start dates, not confirmed bleeding days. Missing records can affect timing.").font(.footnote).foregroundStyle(.secondary)
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
