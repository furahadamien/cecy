import SwiftUI

struct CycleHistoryView: View {
    let session: TrackerSession
    let overview: CycleOverview
    @State private var showExplanation = false

    var body: some View {
        TrackerPage(title: "Insights", subtitle: "Your cycle history, from recorded starts.") {
            DailyInsightsCard(session: session)
            TrackerCard {
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
            TrackerCard(highlighted: true) {
                Text("Completed cycle intervals").font(.headline).accessibilityAddTraits(.isHeader)
                Text("An interval is the number of calendar days between two recorded starts. Bleeding end dates are not needed to calculate it.")
                if overview.intervals.isEmpty {
                    Text("Completed intervals appear after two period starts are recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(overview.intervals.count) completed intervals")
                        .accessibilityIdentifier("intervalCount")
                }
            }
            if case .unavailable(let reason) = overview.prediction {
                InlineError(message: reason.localizedDescription)
            }
            if let statistics = session.statistics { CycleStatisticsView(statistics: statistics) }
            if overview.estimate != nil {
                Button("View prediction evidence") { showExplanation = true }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }
            ForEach(overview.intervals.reversed()) { interval in
                TrackerCard {
                    Text("\(interval.length) days").font(TrackerTypography.sectionTitle).monospacedDigit()
                    Text("Start: \(DayText.full(interval.start))")
                    Text("Next start: \(DayText.full(interval.nextStart))")
                    NavigationLink("Your cycle summary") {
                        AIFeatureView(session: session, feature: .summary(interval.start))
                    }
                    .frame(minHeight: 44).accessibilityIdentifier("cycleSummaryAI_\(interval.start.key)")
                }
                .accessibilityElement(children: .contain)
            }
            if let start = overview.latestStart {
                TrackerCard {
                    Text("Latest recorded start").font(.headline)
                    Text(DayText.full(start))
                    Text("The interval since this start is not complete, so its length is still unknown.")
                        .font(.footnote).foregroundStyle(.secondary)
                    NavigationLink("Summary of available records") {
                        AIFeatureView(session: session, feature: .summary(start))
                    }
                    .frame(minHeight: 44).accessibilityIdentifier("cycleSummaryAI_\(start.key)")
                }
            }
            Text("Missing records can lengthen an observed interval. Cecy never inserts an assumed period or removes an unusual interval.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showExplanation) {
            if let estimate = overview.estimate {
                PredictionExplanation(estimate: estimate, sources: Array(overview.intervals.suffix(6)), replay: session.predictionReplay)
            }
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
                Text("No periods recorded. Add a start or previous dates from Today.")
            }
            LazyVStack(spacing: 10) {
                ForEach(session.snapshot.periods.reversed()) { period in
                    TrackerCard(padding: 14) {
                        PeriodRecordSummary(session: session, period: period)
                    }
                }
            }
        }
    }
}
