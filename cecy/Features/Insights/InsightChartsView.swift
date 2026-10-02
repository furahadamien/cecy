import SwiftUI
import Charts

struct InsightChartsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let intervals: [CycleInterval]
    let symptoms: [SymptomEntry]
    let today: LocalDay

    private var cycles: [CycleInterval] { InsightChartData.recentIntervals(intervals, today: today) }
    private var counts: [InsightChartData.ObservationCount] {
        Array(InsightChartData.observationCounts(symptoms, today: today).prefix(6))
    }

    var body: some View {
        TrackerCard {
            Label("Your cycle lengths", systemImage: "chart.xyaxis.line")
                .font(.headline).accessibilityAddTraits(.isHeader)
            if cycles.isEmpty {
                Text("Record two period starts to see your first completed interval.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(Array(cycles.enumerated()), id: \.element.id) { index, interval in
                        LineMark(x: .value("Recorded interval", index + 1), y: .value("Days", interval.length))
                            .foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
                            .accessibilityHidden(true)
                        PointMark(x: .value("Recorded interval", index + 1), y: .value("Days", interval.length))
                            .foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
                            .symbolSize(45)
                            .accessibilityLabel("Start \(DayText.full(interval.start))")
                            .accessibilityValue("\(interval.length) days to the next recorded start")
                    }
                }
                .chartXScale(domain: 0.5...(Double(cycles.count) + 0.5))
                .chartYScale(domain: 0...max(5, cycles.map(\.length).max() ?? 5))
                .chartXAxis { AxisMarks(values: Array(1...cycles.count)) }
                .chartYAxisLabel("Days")
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 260 : 180)
                .accessibilityIdentifier("cycleLengthChart")
                Text("\(cycles.count) latest completed intervals · oldest to newest. Missing starts can lengthen an interval; this is not a forecast.")
                    .font(.footnote).foregroundStyle(.secondary)
                DisclosureGroup("Chart values") {
                    ForEach(cycles) { interval in
                        Text("\(DayText.short(interval.start)): \(interval.length) days")
                            .font(.subheadline)
                    }
                }
            }
        }
        TrackerCard {
            Label("What you’ve logged", systemImage: "chart.bar.xaxis")
                .font(.headline).accessibilityAddTraits(.isHeader)
            if counts.isEmpty {
                Text("Log an observation to start your 90-day picture.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Chart(counts) { count in
                    BarMark(x: .value("Logged days", count.days), y: .value("Observation", count.kind.title))
                        .foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
                        .cornerRadius(5)
                        .annotation(position: .trailing) { Text(count.days.formatted()).font(.caption.monospacedDigit()) }
                        .accessibilityLabel(count.kind.title)
                        .accessibilityValue("\(count.days) logged days in the last 90 days")
                }
                .chartXScale(domain: 0...max(1, counts.map(\.days).max() ?? 1))
                .chartXAxis {
                    AxisMarks(values: .stride(by: Double(max(1, (counts.map(\.days).max() ?? 1) / 4))))
                }
                .chartYAxis { AxisMarks { _ in AxisValueLabel() } }
                .frame(height: CGFloat(counts.count) * (dynamicTypeSize.isAccessibilitySize ? 70 : 38) + 30)
                .accessibilityIdentifier("observationDaysChart")
                DisclosureGroup("Chart values") {
                    ForEach(counts) { count in Text("\(count.kind.title): \(count.days) logged days").font(.subheadline) }
                }
            }
            Text("Up to six most-logged observations in the last 90 days, including today. Counts describe records, not symptom frequency. Sleep and energy are ratings. Unlogged days do not mean symptom-free days.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
