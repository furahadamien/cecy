import SwiftUI

struct CycleHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let overview: CycleOverview
    @State private var showExplanation = false

    var body: some View {
        TrackerPage(title: "Insights", showsHeading: false,
                    backgroundColor: colorScheme == .dark ? TrackerPalette(scheme: colorScheme).background : Color(red: 0.965, green: 0.980, blue: 0.963),
                    sectionSpacing: 16, topInset: 6) {
            Text("Your cycle history, from recorded starts.").font(.caption).foregroundStyle(.secondary)
            if let today = session.today { RecordingCoverageCard(session: session, today: today) }
            if let today = session.today { ForTodayCard(session: session, today: today) }
            TrackerCard {
                InsightSectionHeader(title: "Explore your records", symbol: "square.text.square")
                NavigationLink {
                    AIFeatureView(session: session, feature: .records)
                } label: { TrackerNavigationLabel(title: "Generate insights", symbol: "sparkles") }
                .accessibilityIdentifier("generateRecordInsights")
                Text("Start with the records you have. Limited data will be described, not treated as a pattern.")
                    .font(.footnote).foregroundStyle(.secondary)
                Divider()
                NavigationLink {
                    AIFeatureView(session: session, feature: .question)
                } label: { TrackerNavigationLabel(title: "Ask about your records", symbol: "sparkles") }
                .accessibilityIdentifier("askCecy")
                Divider()
                NavigationLink {
                    ObservationsView(session: session)
                } label: {
                    TrackerNavigationLabel(title: "Observations and patterns", symbol: "square.text.square")
                }
                .accessibilityIdentifier("manageObservations")
                Divider()
                NavigationLink {
                    RecordedPeriodsView(session: session)
                } label: {
                    TrackerNavigationLabel(title: "Manage recorded periods", symbol: "list.bullet.rectangle")
                }
                .accessibilityIdentifier("managePeriods")
                Divider()
                NavigationLink {
                    PredictionHistoryView(replay: session.predictionReplay)
                } label: {
                    TrackerNavigationLabel(title: "Prediction history check", symbol: "calendar.badge.clock")
                }
                .accessibilityIdentifier("predictionReplayLink")
            }
            .buttonStyle(.plain)
            if let today = session.today {
                InsightChartsView(intervals: overview.intervals, symptoms: session.snapshot.symptoms, today: today,
                                  periods: session.snapshot.periods)
            }
            TrackerCard {
                InsightSectionHeader(title: "Completed cycle intervals", symbol: "calendar")
                Text("An interval is the number of calendar days between two recorded starts. Bleeding end dates are not needed to calculate it.")
                if overview.intervals.isEmpty {
                    Text("Completed intervals appear after two period starts are recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(overview.intervals.count) completed intervals").font(.title3.weight(.semibold))
                        .accessibilityIdentifier("intervalCount")
                }
            }
            if case .unavailable(let reason) = overview.prediction {
                InlineError(message: reason.localizedDescription)
            }
            if let statistics = session.statistics { CycleStatisticsView(statistics: statistics) }
            if overview.estimate != nil {
                Button { showExplanation = true } label: {
                    TrackerCard(padding: 12) {
                        TrackerNavigationLabel(title: "View prediction evidence", symbol: "chart.bar.doc.horizontal")
                    }
                }.buttonStyle(.plain)
            }
            ForEach(overview.intervals.reversed()) { interval in
                TrackerCard {
                    Text("\(interval.length) days").font(TrackerTypography.sectionTitle).monospacedDigit()
                    Text("Start: \(DayText.full(interval.start))")
                    Text("Next start: \(DayText.full(interval.nextStart))")
                    Divider()
                    NavigationLink {
                        AIFeatureView(session: session, feature: .summary(interval.start))
                    } label: { TrackerNavigationLabel(title: "Your cycle summary", symbol: "doc.text") }
                    .frame(minHeight: 44).accessibilityIdentifier("cycleSummaryAI_\(interval.start.key)")
                }
                .accessibilityElement(children: .contain)
            }
            if let start = overview.latestStart {
                TrackerCard {
                    InsightSectionHeader(title: "Latest recorded start", symbol: "drop.fill")
                    Text(DayText.full(start)).font(.title3.weight(.semibold))
                    Text("The interval since this start is not complete, so its length is still unknown.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Divider()
                    NavigationLink {
                        AIFeatureView(session: session, feature: .summary(start))
                    } label: { TrackerNavigationLabel(title: "Summary of available records", symbol: "doc.text") }
                    .frame(minHeight: 44).accessibilityIdentifier("cycleSummaryAI_\(start.key)")
                }
            }
            Text("Missing records can lengthen an observed interval. Cecy never inserts an assumed period or removes an unusual interval.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showExplanation) {
            if let estimate = overview.estimate {
                PredictionDetailView(estimate: estimate, sources: Array(overview.intervals.suffix(6)), replay: session.predictionReplay)
            }
        }
    }
}

/// The detailed explanation of an estimate, kept in Insights for anyone who wants the full reasoning.
/// Today's "?" shows only the short `PredictionExplanation`.
private struct PredictionDetailView: View {
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
                        Text(notice).accessibilityIdentifier("starterPrediction")
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
                }
                Text(OvulationNotice.explanation).font(.footnote)
                Text("This is an uncalibrated estimate, not medical advice. Missing records affect it. Do not use it for contraception or diagnosis.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct RecordedPeriodsView: View {
    let session: TrackerSession
    var body: some View {
        TrackerPage(title: "Recorded periods") {
            if let confirmation = session.confirmation {
                Label(confirmation, systemImage: "checkmark.circle")
                    .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
                Button("Dismiss confirmation") { session.confirmation = nil }
            }
            if session.snapshot.periods.isEmpty {
                Text("No periods recorded. Add a start or previous dates from Calendar.")
            }
            LazyVStack(spacing: 10) {
                ForEach(session.snapshot.periods.reversed()) { period in
                    PeriodRecordSummary(session: session, period: period)
                }
            }
        }
    }
}
