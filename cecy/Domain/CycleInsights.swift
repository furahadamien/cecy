import Foundation

nonisolated enum InsightCategory: String, Sendable {
    case symptomTiming, cycleLength, cycleVariability, bleedingDuration
}

nonisolated enum InsightEvidence: String, Sendable {
    case limited = "Limited recorded evidence"
    case repeated = "Repeated recorded evidence"
}

nonisolated struct TimingSupport: Equatable, Sendable {
    let start: LocalDay
    let logDays: [LocalDay]
}

nonisolated struct CycleInsight: Identifiable, Equatable, Sendable {
    let id: String
    let category: InsightCategory
    let title: String
    let explanation: String
    let evidence: InsightEvidence
    let generatedDay: LocalDay
    let rangeStart: LocalDay
    let rangeEnd: LocalDay
    let sourceIDs: [UUID]
    var timing: [TimingSupport] = []
    var previousValues: [Int] = []
    var recentValues: [Int] = []
    var previousMetric: Double?
    var recentMetric: Double?
    var matchedStarts: Int { timing.filter { !$0.logDays.isEmpty }.count }
}

/// Display heuristics only: no clinical thresholds, calibrated confidence, or inferred absence.
nonisolated enum CycleInsightEngine {
    static let policyVersion = 1

    static func generate(periods: [Period], symptoms: [SymptomEntry], today: LocalDay) throws -> [CycleInsight] {
        try PeriodValidation.validate(periods, asOf: today)
        try SymptomValidation.validate(symptoms, asOf: today)
        let periods = periods.sorted { $0.start < $1.start }
        var insights = timingInsights(periods: periods, symptoms: symptoms, today: today)
        let intervals = zip(periods, periods.dropFirst()).map { $0.start.days(until: $1.start) }
        if intervals.count >= 6 {
            let lengths = Array(intervals.suffix(6))
            let sources = Array(periods.suffix(7))
            let previous = Array(lengths.prefix(3)), recent = Array(lengths.suffix(3))
            appendComparison(to: &insights, category: .cycleLength, previous: previous, recent: recent,
                             old: mean(previous), new: mean(recent), threshold: 3, metric: "Average cycle interval",
                             increased: "longer", decreased: "shorter", sources: sources, today: today)
            appendComparison(to: &insights, category: .cycleVariability, previous: previous, recent: recent,
                             old: deviation(previous), new: deviation(recent), threshold: 2, metric: "Cycle interval variability (population standard deviation)",
                             increased: "more variable", decreased: "less variable", sources: sources, today: today)
        }
        let completed = Array(periods.suffix(6))
        if completed.count == 6, completed.allSatisfy({ $0.duration != nil }) {
            let durations = completed.compactMap(\.duration)
            let previous = Array(durations.prefix(3)), recent = Array(durations.suffix(3))
            appendComparison(to: &insights, category: .bleedingDuration, previous: previous, recent: recent,
                             old: mean(previous), new: mean(recent), threshold: 1, metric: "Average confirmed bleeding duration",
                             increased: "longer", decreased: "shorter", sources: completed, today: today)
        }
        return insights
    }

    static func timingSupport(periods: [Period], symptoms: [SymptomEntry], today: LocalDay,
                              kind: SymptomKind, offsets: ClosedRange<Int>) -> [TimingSupport] {
        let periods = periods.sorted { $0.start < $1.start }
        let eligible = Array(periods.enumerated().compactMap { index, period -> Period? in
            guard let end = try? period.start.adding(days: 2), end < today,
                  (try? period.start.adding(days: -3)) != nil,
                  index == 0 || periods[index - 1].start.days(until: period.start) >= 6,
                  index + 1 == periods.count || period.start.days(until: periods[index + 1].start) >= 6 else { return nil }
            return period
        }.suffix(6))
        let logs = SymptomValidation.sorted(symptoms.filter { $0.kind == kind && kind.qualifiesForTiming(value: $0.value) })
        return eligible.map { period in
            TimingSupport(start: period.start, logDays: logs.filter {
                offsets.contains(period.start.days(until: $0.day))
            }.map(\.day))
        }
    }

    private static func timingInsights(periods: [Period], symptoms: [SymptomEntry], today: LocalDay) -> [CycleInsight] {
        return SymptomKind.allCases.compactMap { kind in
            let logs = SymptomValidation.sorted(symptoms.filter { $0.kind == kind && kind.qualifiesForTiming(value: $0.value) })
            let before = timingSupport(periods: periods, symptoms: symptoms, today: today, kind: kind, offsets: -3 ... -1)
            let after = timingSupport(periods: periods, symptoms: symptoms, today: today, kind: kind, offsets: 0...2)
            let eligible = periods.filter { period in before.contains { $0.start == period.start } }
            guard eligible.count >= 3 else { return nil }
            let beforeCount = before.filter { !$0.logDays.isEmpty }.count
            let afterCount = after.filter { !$0.logDays.isEmpty }.count
            let chooseBefore = beforeCount >= afterCount
            let matches = max(beforeCount, afterCount)
            guard matches >= 3, matches * 5 >= eligible.count * 3 else { return nil }
            let selected = chooseBefore ? before : after
            let days = Set(selected.flatMap(\.logDays))
            let window = chooseBefore ? "in the three days before" : "on the start day or two days after"
            return CycleInsight(id: "v1.timing.\(kind.rawValue)", category: .symptomTiming,
                                title: "\(kind.timingTitle) recorded near period starts",
                                explanation: "Recorded \(window) \(matches) of \(eligible.count) eligible starts. A start without a matching log does not mean the observation was absent.",
                                evidence: eligible.count == 6 && matches >= 5 ? .repeated : .limited,
                                generatedDay: today,
                                rangeStart: min(eligible[0].start, days.min() ?? eligible[0].start),
                                rangeEnd: max(eligible.last!.start, days.max() ?? eligible.last!.start),
                                sourceIDs: eligible.map(\.id) + logs.filter { days.contains($0.day) }.map(\.id),
                                timing: selected)
        }
    }

    private static func mean(_ values: [Int]) -> Double { Double(values.reduce(0, +)) / Double(values.count) }
    private static func deviation(_ values: [Int]) -> Double {
        let average = mean(values)
        return sqrt(values.reduce(0.0) { $0 + pow(Double($1) - average, 2) } / Double(values.count))
    }

    private static func appendComparison(to insights: inout [CycleInsight], category: InsightCategory,
                                         previous: [Int], recent: [Int], old: Double, new: Double,
                                         threshold: Double, metric: String, increased: String, decreased: String,
                                         sources: [Period], today: LocalDay) {
        guard abs(new - old) >= threshold else { return }
        insights.append(CycleInsight(id: "v1.\(category.rawValue)", category: category,
                                     title: "Recent records were \(new > old ? increased : decreased)",
                                     explanation: "\(metric): comparing the previous three records with the most recent three. This describes recorded information, not a diagnosis or a forecast. Missing periods can lengthen recorded intervals.",
                                     evidence: .limited, generatedDay: today,
                                     rangeStart: sources[0].start,
                                     rangeEnd: category == .bleedingDuration ? sources.last!.end! : sources.last!.start,
                                     sourceIDs: sources.map(\.id), previousValues: previous, recentValues: recent,
                                     previousMetric: old, recentMetric: new))
    }
}
