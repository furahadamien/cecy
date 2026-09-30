import SwiftUI

struct TodayView: View {
    @Bindable var session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    let onLog: (LocalDay) -> Void
    let onHistory: () -> Void
    @State private var showExplanation = false

    var body: some View {
        TrackerPage(title: "Today", subtitle: DayText.full(today)) {
            if let confirmation = session.confirmation {
                TrackerCard {
                    Label(confirmation, systemImage: "checkmark.circle")
                        .accessibilityIdentifier("saveConfirmation")
                    Button("Dismiss confirmation") { session.confirmation = nil }
                }
                .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
            }
            TrackerCard(highlighted: true) {
                Label("Your recorded cycle", systemImage: "leaf").font(.subheadline.weight(.medium))
                if let day = overview.currentDay, let start = overview.latestStart {
                    Text("Day \(day)")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .accessibilityIdentifier("cycleDay")
                    Text("Since your recorded start on \(DayText.full(start)).")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if case .unavailable(let reason) = overview.prediction {
                    InlineError(message: reason.localizedDescription)
                } else {
                    Text("Your cycle history starts here.").font(.title2.weight(.semibold))
                    Text("Record a period start or add dates you remember.").foregroundStyle(.secondary)
                }
            }
            TrackerCard {
                PredictionSummary(outcome: overview.prediction, today: today)
                if overview.estimate != nil {
                    Button("How this estimate works") { showExplanation = true }
                        .frame(minHeight: 44)
                }
            }
            VStack(spacing: 12) {
                Button { onLog(today) } label: {
                    Label("Log period start", systemImage: "drop")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("logPeriod")
                SymptomLogButton(session: session, day: today)
                Button("Add previous periods", action: onHistory)
                    .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.bordered)
            }
            Text("A count from recorded dates—not an estimate of cycle phase. Missing records can affect the result.")
                .font(.footnote).foregroundStyle(.secondary)
            if let insight = session.insights.first { InsightCard(insight: insight) }
            if let message = session.insightMessage { InlineError(message: message) }
            if let latest = session.snapshot.periods.last {
                TrackerCard {
                    Text("Latest recorded period").font(.headline)
                    Text(DayText.full(latest.start))
                    Text(latest.end.map { "Ended \(DayText.full($0))" }
                         ?? "End not recorded. If this period is ongoing, you can add its end later.")
                    PeriodExtraDetails(period: latest)
                    PeriodRecordActions(session: session, period: latest).id(latest.id)
                }
            }
        }
        .sheet(isPresented: $showExplanation) {
            if let estimate = overview.estimate {
                PredictionExplanation(estimate: estimate, sources: Array(overview.intervals.suffix(6)), replay: session.predictionReplay)
            }
        }
    }
}

struct PredictionSummary: View {
    let outcome: PredictionOutcome
    let today: LocalDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated next start").font(.headline).accessibilityAddTraits(.isHeader)
            switch outcome {
            case .available(let estimate):
                Text(DayText.range(estimate.earliest, estimate.latest))
                    .font(.title2.weight(.semibold)).accessibilityIdentifier("predictionWindow")
                Label("\(estimate.confidence.rawValue) confidence · Rough estimate", systemImage: "circle.dashed")
                    .font(.subheadline)
                if today > estimate.latest {
                    Text("Estimated window passed. No new start has been recorded.")
                        .accessibilityIdentifier("passedWindow")
                } else if estimate.contains(today) {
                    Text("You’re within the estimated start window.")
                }
                Text("These are possible start dates—not predicted bleeding days.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .insufficientHistory(let count):
                Text("More history is needed for an estimate.").font(.title3)
                Text(count == 0 ? "Four recorded starts are needed. You can begin with fewer."
                     : "\(count) of 3 completed intervals available. Four recorded starts are needed for an initial estimate.")
                    .foregroundStyle(.secondary)
            case .wideVariation:
                Text("Your recorded intervals vary more than this simple estimate can support.")
                Text("Review your recorded starts in Insights. A long gap may include an unrecorded period, but Cecy won’t assume one.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .unavailable(let reason):
                Text(reason.localizedDescription)
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
                    Text(DayText.range(estimate.earliest, estimate.latest)).font(.title2.weight(.semibold))
                    Text("Possible next start dates, not a predicted bleeding duration.")
                    Text("\(estimate.confidence.rawValue) confidence · Provisional")
                }
                TrackerCard {
                    Text("The recorded intervals behind it").font(.headline)
                    Text(estimate.sourceLengths.map { "\($0)" }.joined(separator: ", ") + " days")
                    Text("This early model uses up to six recent completed intervals. It uses the median for the center and adds two days around the shortest and longest intervals.")
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
                Text("This is an uncalibrated estimate, not medical advice. Missing records affect it. Do not use it for contraception or diagnosis.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
