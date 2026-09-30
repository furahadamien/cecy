import Foundation

nonisolated enum PeriodFlow: String, CaseIterable, Sendable {
    case light, moderate, heavy
    var title: String { rawValue.capitalized }
}

nonisolated struct Period: Identifiable, Equatable, Sendable {
    let id: UUID
    var start: LocalDay
    var end: LocalDay?
    var flow: PeriodFlow?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), start: LocalDay, end: LocalDay? = nil, flow: PeriodFlow? = nil,
         notes: String? = nil, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.flow = flow
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var duration: Int? { end.map { start.days(until: $0) + 1 } }
    func contains(_ day: LocalDay) -> Bool { start <= day && day <= (end ?? start) }
}

nonisolated enum PeriodValidation {
    static let maximumNoteLength = 2_000
    /// No as-of date on loading: travel must never delete a previously saved civil day.
    static func validate(_ periods: [Period], asOf today: LocalDay? = nil) throws {
        guard Set(periods.map(\.id)).count == periods.count else { throw TrackingError.invalidData }
        let sorted = periods.sorted { $0.start < $1.start }
        for (index, period) in sorted.enumerated() {
            guard (period.notes?.count ?? 0) <= maximumNoteLength else { throw TrackingError.noteTooLong }
            guard period.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  period.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
            if let end = period.end, end < period.start { throw TrackingError.reversedEnd }
            if let today, period.start > today || (period.end ?? period.start) > today { throw TrackingError.futureDate }
            if index > 0 {
                let previous = sorted[index - 1]
                if previous.start == period.start { throw TrackingError.duplicateStart }
                if (previous.end ?? previous.start) >= period.start { throw TrackingError.overlap }
            }
        }
    }
}

nonisolated struct CycleInterval: Identifiable, Equatable, Sendable {
    let id: UUID
    let start: LocalDay
    let nextStart: LocalDay
    var length: Int { start.days(until: nextStart) }
}

nonisolated enum PredictionConfidence: String, Sendable {
    case low = "Low", moderate = "Moderate"
}

nonisolated struct CyclePrediction: Equatable, Sendable {
    let center: LocalDay
    let earliest: LocalDay
    let latest: LocalDay
    let confidence: PredictionConfidence
    let sourceLengths: [Int]
    func contains(_ day: LocalDay) -> Bool { earliest <= day && day <= latest }
}

nonisolated enum PredictionOutcome: Equatable, Sendable {
    case insufficientHistory(completedIntervals: Int)
    case wideVariation
    case unavailable(TrackingError)
    case available(CyclePrediction)
}

nonisolated protocol CyclePredicting: Sendable {
    func predict(intervals: [CycleInterval], latestStart: LocalDay) throws -> PredictionOutcome
}

/// Uncalibrated baseline V1. No medical cutoffs, outlier removal, or probability claims.
nonisolated struct BaselinePredictionEngine: CyclePredicting {
    func predict(intervals: [CycleInterval], latestStart: LocalDay) throws -> PredictionOutcome {
        let lengths = Array(intervals.suffix(6).map(\.length))
        guard lengths.count >= 3 else { return .insufficientHistory(completedIntervals: lengths.count) }
        let sorted = lengths.sorted()
        guard let minimum = sorted.first, let maximum = sorted.last, minimum > 0 else { throw TrackingError.invalidData }
        guard maximum - minimum <= 14 else { return .wideVariation }
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2
            : Double(sorted[middle])
        return .available(CyclePrediction(
            center: try latestStart.adding(days: Int(median.rounded(.toNearestOrAwayFromZero))),
            earliest: try latestStart.adding(days: max(1, minimum - 2)),
            latest: try latestStart.adding(days: maximum + 2),
            confidence: lengths.count == 6 && maximum - minimum <= 7 ? .moderate : .low,
            sourceLengths: lengths
        ))
    }
}

nonisolated struct CycleOverview: Equatable, Sendable {
    let latestStart: LocalDay?
    let currentDay: Int?
    let intervals: [CycleInterval]
    let prediction: PredictionOutcome

    var estimate: CyclePrediction? {
        if case .available(let estimate) = prediction { return estimate }
        return nil
    }
}

nonisolated enum CycleCalculator {
    static func overview(periods: [Period], today: LocalDay, engine: any CyclePredicting = BaselinePredictionEngine()) -> CycleOverview {
        do {
            try PeriodValidation.validate(periods, asOf: today)
            let sorted = periods.sorted { $0.start < $1.start }
            let intervals = zip(sorted, sorted.dropFirst()).map {
                CycleInterval(id: $0.id, start: $0.start, nextStart: $1.start)
            }
            guard let last = sorted.last else {
                return CycleOverview(latestStart: nil, currentDay: nil, intervals: [], prediction: .insufficientHistory(completedIntervals: 0))
            }
            return CycleOverview(latestStart: last.start, currentDay: last.start.days(until: today) + 1,
                                 intervals: intervals, prediction: try engine.predict(intervals: intervals, latestStart: last.start))
        } catch {
            return CycleOverview(latestStart: nil, currentDay: nil, intervals: [], prediction: .unavailable(error as? TrackingError ?? .invalidData))
        }
    }
}

nonisolated struct TrackerSnapshot: Equatable, Sendable {
    var periods: [Period] = []
    var onboardingCompletedAt: Date?
    var symptoms: [SymptomEntry] = []
    var profile: LocalProfile?
}

@MainActor
protocol PeriodRepository {
    func load() throws -> TrackerSnapshot
    func add(_ periods: [Period], completingOnboarding: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func update(_ period: Period, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func delete(id: UUID) throws -> TrackerSnapshot
    func deleteAll() throws -> TrackerSnapshot
    func saveSymptom(_ entry: SymptomEntry, editing: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func deleteSymptom(id: UUID) throws -> TrackerSnapshot
    func saveProfile(_ profile: LocalProfile, today: LocalDay) throws -> TrackerSnapshot
    func prepareOnboarding(_ draft: OnboardingDraft, today: LocalDay) throws -> TrackerSnapshot
    func completeOnboarding(profileID: UUID, today: LocalDay, now: Date) throws -> TrackerSnapshot
}
