import Foundation

nonisolated struct LengthFrequency: Identifiable, Equatable, Sendable {
    let length: Int
    let count: Int
    var id: Int { length }
}

nonisolated struct RecordedStatistics: Equatable, Sendable {
    let count: Int
    let mean: Double
    let median: Double
    let minimum: Int
    let maximum: Int
    let standardDeviation: Double?
    let distribution: [LengthFrequency]
    var spread: Int { maximum - minimum }

    init?(lengths: [Int]) {
        guard !lengths.isEmpty, lengths.allSatisfy({ $0 > 0 }) else { return nil }
        let sorted = lengths.sorted()
        count = sorted.count
        mean = sorted.reduce(0.0) { $0 + Double($1) } / Double(count)
        let middle = count / 2
        median = count.isMultiple(of: 2)
            ? (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2
            : Double(sorted[middle])
        minimum = sorted[0]
        maximum = sorted[count - 1]
        let average = mean
        standardDeviation = count > 1
            ? sqrt(sorted.reduce(0.0) { $0 + pow(Double($1) - average, 2) } / Double(count)) : nil
        distribution = Dictionary(grouping: sorted, by: { $0 }).map {
            LengthFrequency(length: $0.key, count: $0.value.count)
        }.sorted { $0.length < $1.length }
    }
}

nonisolated struct CycleStatistics: Equatable, Sendable {
    let cycles: RecordedStatistics?
    let bleeding: RecordedStatistics?
    let unconfirmedEndCount: Int

    static func calculate(periods: [Period], today: LocalDay) throws -> Self {
        try PeriodValidation.validate(periods, asOf: today)
        let sorted = periods.sorted { $0.start < $1.start }
        let lengths = zip(sorted, sorted.dropFirst()).map { $0.start.days(until: $1.start) }
        return Self(cycles: RecordedStatistics(lengths: lengths),
                    bleeding: RecordedStatistics(lengths: periods.compactMap(\.duration)),
                    unconfirmedEndCount: periods.filter { $0.end == nil }.count)
    }
}