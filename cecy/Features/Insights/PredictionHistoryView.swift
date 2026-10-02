import SwiftUI

struct PredictionHistoryView: View {
    let replay: PredictionReplay?

    var body: some View {
        TrackerPage(title: "Prediction history check") {
            TrackerCard {
                Text("Reconstructed, not previously issued predictions").font(.headline)
                    .accessibilityIdentifier("replayDisclosure")
                Text("Each check uses only intervals before its target start-to-start interval. It is recalculated from your current records, not a record of what Cecy showed at the time. Late logging and corrections can change these results.")
                Text("Starter estimates based on your entered typical cycle length are not scored here. That preference is not past observed evidence.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Missing starts can affect every comparison. These results do not establish medical accuracy or the chance of a future start falling in a window.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let replay {
                ReplayMetrics(replay: replay)
                if replay.scored.isEmpty {
                    Text(replay.rows.count < 4
                         ? "Five recorded starts are needed for the first historical check. A starter estimate can be available sooner from your last start and typical cycle length."
                         : "No estimate was available for these historical checks. Withheld estimates are listed below, not counted as accurate or inaccurate.")
                        .accessibilityIdentifier("replayEmpty")
                }
                LazyVStack(spacing: 16) {
                    ForEach(replay.rows.reversed()) { row in
                        TrackerCard {
                            Text("Recorded next start: \(DayText.full(row.target.nextStart))").font(.headline)
                            Text("Estimated from start: \(DayText.full(row.target.start))")
                            if let estimate = row.estimate {
                                Text("Reconstructed window: \(DayText.range(estimate.earliest, estimate.latest))")
                                Text("Center: \(DayText.full(estimate.center))")
                                if let error = row.signedError {
                                    Text(error == 0 ? "Recorded start matched the center."
                                         : "Recorded start was \(abs(error)) days \(error > 0 ? "later" : "earlier") than the center.")
                                }
                                Text(row.covered == true ? "Inside the window (including its boundaries)."
                                     : "Outside the window by \(row.outsideWindowDays ?? 0) days.")
                                Text("Window span: \(row.windowSpan ?? 0) days between its boundaries.")
                            } else {
                                switch row.outcome {
                                case .insufficientHistory(let count): Text("Warm-up: \(count) of 3 earlier intervals available.")
                                case .wideVariation: Text("Withheld: earlier intervals varied by more than 14 days.")
                                case .unavailable: Text("Withheld: date arithmetic could not produce this estimate.")
                                case .available: EmptyView()
                                }
                            }
                            DisclosureGroup("Source intervals") {
                                ForEach(row.sources) { source in
                                    Text("\(DayText.range(source.start, source.nextStart)): \(source.length) days")
                                }
                                if row.sources.isEmpty { Text("No earlier completed intervals.") }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            } else {
                InlineError(message: "Checks are unavailable in the current date context. Review your recorded dates; no records have been removed.")
            }
        }
    }
}

struct ReplayMetrics: View {
    let replay: PredictionReplay
    var body: some View {
        TrackerCard {
            Text("Recorded-history results").font(.headline)
            Text("\(replay.coveredCount) of \(replay.scored.count) checked starts inside their windows")
                .accessibilityIdentifier("replayCoverage")
            if let error = replay.meanAbsoluteError {
                Text("Average absolute center error: \(error.formatted(.number.precision(.fractionLength(1)))) days")
            }
            if let span = replay.meanWindowSpan {
                Text("Average window span: \(span.formatted(.number.precision(.fractionLength(1)))) days between boundaries")
            }
            Text("\(replay.warmUpCount) warm-up intervals · \(replay.withheldCount) withheld estimates")
            Text("Only available estimates enter the error and coverage counts. Wider windows can include more starts without improving the center estimate.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
