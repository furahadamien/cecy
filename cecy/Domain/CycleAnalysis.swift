import Foundation

nonisolated enum PeriodFlow: String, CaseIterable, Sendable {
    case light, moderate, heavy
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .light: "drop"
        case .moderate: "drop.halffull"
        case .heavy: "drop.fill"
        }
    }
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

nonisolated enum PredictionBasis: Equatable, Sendable { case recordedHistory, usualCycle }

nonisolated struct CyclePrediction: Equatable, Sendable {
    let center: LocalDay
    let earliest: LocalDay
    let latest: LocalDay
    let confidence: PredictionConfidence
    let sourceLengths: [Int]
    var basis: PredictionBasis = .recordedHistory
    var reportedCycleDays: Int? = nil
    var reportedPeriodDays: Int? = nil
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
    func predict(intervals: [CycleInterval], latestStart: LocalDay, profile: LocalProfile?) throws -> PredictionOutcome
}

nonisolated extension CyclePredicting {
    func predict(intervals: [CycleInterval], latestStart: LocalDay, profile: LocalProfile?) throws -> PredictionOutcome {
        try predict(intervals: intervals, latestStart: latestStart)
    }
}

/// Unified median window. Assumptions supply an input only when no measured interval exists.
nonisolated struct BaselinePredictionEngine: CyclePredicting {
    func predict(intervals: [CycleInterval], latestStart: LocalDay) throws -> PredictionOutcome {
        try predict(intervals: intervals, latestStart: latestStart, profile: nil)
    }

    func predict(intervals: [CycleInterval], latestStart: LocalDay, profile: LocalProfile?) throws -> PredictionOutcome {
        try PredictionBacktester.validate(intervals)
        guard intervals.last.map({ $0.nextStart == latestStart }) ?? true else { throw TrackingError.invalidData }
        let lengths = Array(intervals.suffix(6).map(\.length))
        let usesReportedLength = lengths.isEmpty
        let inputs: [Int]
        if usesReportedLength {
            guard let days = profile?.typicalCycleDays else { return .insufficientHistory(completedIntervals: 0) }
            guard CycleSetupPolicy.cycleDays.contains(days),
                  profile?.typicalPeriodDays.map({ CycleSetupPolicy.periodDays.contains($0) && $0 <= days }) ?? true else {
                throw TrackingError.invalidData
            }
            inputs = [days]
        } else {
            inputs = lengths
        }
        let sorted = inputs.sorted()
        guard let minimum = sorted.first, let maximum = sorted.last, minimum > 0 else { throw TrackingError.invalidData }
        guard maximum - minimum <= 14 else { return .wideVariation }
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2)
            ? (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2
            : Double(sorted[middle])
        let padding = usesReportedLength ? 3 : 2
        return .available(CyclePrediction(
            center: try latestStart.adding(days: Int(median.rounded(.toNearestOrAwayFromZero))),
            earliest: try latestStart.adding(days: max(1, minimum - padding)),
            latest: try latestStart.adding(days: maximum + padding),
            confidence: lengths.count == 6 && maximum - minimum <= 7 ? .moderate : .low,
            sourceLengths: lengths,
            basis: usesReportedLength ? .usualCycle : .recordedHistory,
            reportedCycleDays: usesReportedLength ? profile?.typicalCycleDays : nil,
            reportedPeriodDays: usesReportedLength ? profile?.typicalPeriodDays : nil
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
    static func overview(periods: [Period], today: LocalDay, engine: any CyclePredicting = BaselinePredictionEngine(),
                         profile: LocalProfile? = nil) -> CycleOverview {
        do {
            try PeriodValidation.validate(periods, asOf: today)
            let sorted = periods.sorted { $0.start < $1.start }
            let intervals = zip(sorted, sorted.dropFirst()).map {
                CycleInterval(id: $0.id, start: $0.start, nextStart: $1.start)
            }
            guard let last = sorted.last else {
                return CycleOverview(latestStart: nil, currentDay: nil, intervals: [], prediction: .insufficientHistory(completedIntervals: 0))
            }
            let prediction = try engine.predict(intervals: intervals, latestStart: last.start, profile: profile)
            return CycleOverview(latestStart: last.start, currentDay: last.start.days(until: today) + 1,
                                 intervals: intervals, prediction: prediction)
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
    var sexualActivities: [SexualActivityEntry] = []
    var healthImports: [HealthImportReceipt] = []
}

@MainActor
protocol PeriodRepository {
    func load() throws -> TrackerSnapshot
    func add(_ periods: [Period], completingOnboarding: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func update(_ period: Period, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func delete(id: UUID) throws -> TrackerSnapshot
    func deleteAll() throws -> TrackerSnapshot
    func saveSymptom(_ entry: SymptomEntry, editing: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func addSymptoms(_ entries: [SymptomEntry], today: LocalDay, now: Date) throws -> TrackerSnapshot
    func deleteSymptom(id: UUID) throws -> TrackerSnapshot
    func saveSexualActivity(_ entry: SexualActivityEntry, editing: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func deleteSexualActivity(id: UUID) throws -> TrackerSnapshot
    func saveProfile(_ profile: LocalProfile, today: LocalDay) throws -> TrackerSnapshot
    func prepareOnboarding(_ draft: OnboardingDraft, today: LocalDay) throws -> TrackerSnapshot
    func completeOnboarding(profileID: UUID, today: LocalDay, now: Date) throws -> TrackerSnapshot
    func importHealthStart(_ sample: HealthFlowSample, confirmedStart: LocalDay,
                           today: LocalDay, now: Date, timeZone: TimeZone) throws -> TrackerSnapshot
}

extension PeriodRepository {
    // Older test repositories do not gain an implicit, non-atomic import implementation.
    func importHealthStart(_ sample: HealthFlowSample, confirmedStart: LocalDay,
                           today: LocalDay, now: Date, timeZone: TimeZone) throws -> TrackerSnapshot {
        throw HealthImportError.unavailable
    }
}
