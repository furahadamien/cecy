import SwiftUI

struct CycleHistoryView: View {
    let overview: CycleOverview
    @State private var showExplanation = false

    var body: some View {
        TrackerPage(title: "Insights", subtitle: "Your cycle history, from recorded starts.") {
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
            if overview.estimate != nil {
                Button("View prediction evidence") { showExplanation = true }
                    .buttonStyle(.bordered).frame(minHeight: 44)
            }
            ForEach(overview.intervals.reversed()) { interval in
                TrackerCard {
                    Text("\(interval.length) days").font(.title2.weight(.semibold))
                    Text("Start: \(DayText.full(interval.start))")
                    Text("Next start: \(DayText.full(interval.nextStart))")
                }
                .accessibilityElement(children: .combine)
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
            if let estimate = overview.estimate { PredictionExplanation(estimate: estimate) }
        }
    }
}