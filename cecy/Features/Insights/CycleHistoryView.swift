import SwiftUI

struct CycleHistoryView: View {
    let session: TrackerSession
    let overview: CycleOverview
    @State private var showExplanation = false

    var body: some View {
        TrackerPage(title: "Insights", subtitle: "Your cycle history, from recorded starts.") {
            NavigationLink {
                AIFeatureView(session: session, feature: .question)
            } label: { Label("Ask about your records", systemImage: "sparkles").frame(minHeight: 44) }
            .accessibilityIdentifier("askCecy")
            NavigationLink {
                ObservationsView(session: session)
            } label: {
                Label("Observations and patterns", systemImage: "square.text.square").frame(minHeight: 44)
            }
            .accessibilityIdentifier("manageObservations")
            NavigationLink {
                RecordedPeriodsView(session: session)
            } label: {
                Label("Manage recorded periods", systemImage: "list.bullet.rectangle").frame(minHeight: 44)
            }
            .accessibilityIdentifier("managePeriods")
            NavigationLink {
                PredictionHistoryView(replay: session.predictionReplay)
            } label: {
                Label("Prediction history check", systemImage: "calendar.badge.clock").frame(minHeight: 44)
            }
            .accessibilityIdentifier("predictionReplayLink")
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
                    Text("\(interval.length) days").font(.title2.weight(.semibold))
                    Text("Start: \(DayText.full(interval.start))")
                    Text("Next start: \(DayText.full(interval.nextStart))")
                    if session.snapshot.periods.contains(where: { $0.start == interval.start && $0.end != nil }) {
                        NavigationLink("Your cycle summary · AI") {
                            AIFeatureView(session: session, feature: .summary(interval.start))
                        }
                        .frame(minHeight: 44).accessibilityIdentifier("cycleSummaryAI_\(interval.start.key)")
                    } else {
                        Text("An AI summary also needs a confirmed bleeding end date.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .contain)
            }
            if let start = overview.latestStart {
                TrackerCard {
                    Text("Latest recorded start").font(.headline)
                    Text(DayText.full(start))
                    Text("The interval since this start is not complete and is not included in the estimate.")
                        .font(.footnote).foregroundStyle(.secondary)
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
            LazyVStack(spacing: 16) {
                ForEach(session.snapshot.periods.reversed()) { period in
                    TrackerCard {
                        Text(DayText.full(period.start)).font(.headline)
                        Text(period.end.map { "Ended \(DayText.full($0))" } ?? "End not recorded")
                        if let duration = period.duration { Text("\(duration) days, inclusive") }
                        PeriodExtraDetails(period: period)
                        PeriodRecordActions(session: session, period: period)
                    }
                }
            }
        }
    }
}
