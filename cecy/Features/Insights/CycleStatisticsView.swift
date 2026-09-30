import SwiftUI

struct CycleStatisticsView: View {
    let statistics: CycleStatistics

    var body: some View {
        if let cycles = statistics.cycles {
            TrackerCard {
                Text("Recorded cycle lengths").font(.headline).accessibilityAddTraits(.isHeader)
                Text("Based on all \(cycles.count) completed intervals. The current open interval is excluded.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Average: \(decimal(cycles.mean)) days").accessibilityIdentifier("averageCycle")
                Text("Median: \(decimal(cycles.median)) days")
                Text("Recorded range: \(cycles.minimum)–\(cycles.maximum) days")
                Text("Spread: \(cycles.spread) days")
                if let variability = cycles.standardDeviation {
                    Text("Variability: \(decimal(variability)) days")
                    Text("Population standard deviation describes how spread out these recorded lengths are. It is not a medical assessment or a measure of prediction accuracy.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("One interval is not enough to describe variability.").font(.footnote)
                }
                DisclosureGroup("Cycle length distribution") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(cycles.distribution) { frequency in
                            Text("\(frequency.length)-day cycles: \(frequency.count) recorded intervals")
                        }
                    }.padding(.top, 8)
                }
            }
        }
        TrackerCard {
            Text("Recorded bleeding duration").font(.headline).accessibilityAddTraits(.isHeader)
            if let bleeding = statistics.bleeding {
                Text("Average: \(decimal(bleeding.mean)) days").accessibilityIdentifier("averageDuration")
                Text("Based on \(bleeding.count) periods with confirmed ends. Start and end days are included.")
                if bleeding.count == 1 { Text("One recorded duration is not an established pattern.").font(.footnote) }
            } else {
                Text("Add a confirmed end date to see recorded duration. Cecy never assumes an end.")
            }
            Text("\(statistics.unconfirmedEndCount) periods without an end are excluded.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}