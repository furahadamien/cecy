import Foundation

/// One explicit answer, not inferred coverage. A missing row remains unrecorded.
nonisolated enum DailyBleedingState: String, CaseIterable, Sendable {
    case bleeding, spotting, noBleeding, unsure
}

nonisolated struct DailyBleedingObservation: Identifiable, Equatable, Sendable {
    let id: UUID
    var day: LocalDay
    var state: DailyBleedingState
    var flow: PeriodFlow?
    var periodID: UUID?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), day: LocalDay, state: DailyBleedingState, flow: PeriodFlow? = nil,
         periodID: UUID? = nil, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.state = state
        self.flow = flow
        self.periodID = periodID
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

nonisolated enum DailyBleedingError: Error, LocalizedError, Equatable {
    case duplicateDay, invalidFlow, invalidAssociation, episodeConflict, staleReview, unavailable

    var errorDescription: String? {
        switch self {
        case .duplicateDay: "An answer already exists for this day. Review and edit that answer instead."
        case .invalidFlow: "A flow amount can only be saved with bleeding."
        case .invalidAssociation: "Review the daily answer’s period link before changing these records. An unknown end does not confirm additional bleeding days."
        case .episodeConflict: "This daily answer conflicts with a recorded period. Review the period dates and daily answer together, or cancel."
        case .staleReview: "These records changed after review began. Review the latest records before saving."
        case .unavailable: "Daily bleeding records aren’t available in this store. No records were changed."
        }
    }
}

nonisolated enum DailyBleedingValidation {
    static func sorted(_ observations: [DailyBleedingObservation]) -> [DailyBleedingObservation] {
        observations.sorted { $0.day < $1.day }
    }

    /// Uses civil days and explicit inclusive spans only, never a typical duration or an open-end guess.
    /// Loading omits asOf so travel never makes a previously recorded civil day unreadable.
    static func validate(_ observations: [DailyBleedingObservation], periods: [Period],
                         asOf today: LocalDay? = nil) throws {
        try PeriodValidation.validate(periods)
        guard Set(observations.map(\.id)).count == observations.count else { throw TrackingError.invalidData }
        guard Set(observations.map(\.day)).count == observations.count else { throw DailyBleedingError.duplicateDay }
        let byID = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
        let orderedPeriods = periods.sorted { $0.start < $1.start }
        var index = 0
        for observation in sorted(observations) {
            guard observation.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  observation.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
            if let today, observation.day > today { throw TrackingError.futureDate }
            if observation.flow != nil && observation.state != .bleeding { throw DailyBleedingError.invalidFlow }
            if let id = observation.periodID {
                guard observation.state == .bleeding, let period = byID[id], period.contains(observation.day) else {
                    throw DailyBleedingError.invalidAssociation
                }
            }
            while index < orderedPeriods.count && (orderedPeriods[index].end ?? orderedPeriods[index].start) < observation.day {
                index += 1
            }
            if index < orderedPeriods.count, orderedPeriods[index].contains(observation.day),
               observation.state == .spotting || observation.state == .noBleeding {
                throw DailyBleedingError.episodeConflict
            }
        }
    }
}

/// A complete review of the period/daily-record scope, not the whole tracker store.
/// Omission from a replacement array explicitly deletes that record. Callers must present
/// these changes for confirmation. Expected arrays detect insertions as well as edits/deletes;
/// unrelated symptom/profile changes neither become stale nor get overwritten.
nonisolated struct BleedingReconciliation: Equatable, Sendable {
    let expectedPeriods: [Period]
    let expectedObservations: [DailyBleedingObservation]
    var periods: [Period]
    var observations: [DailyBleedingObservation]

    init(snapshot: TrackerSnapshot) {
        expectedPeriods = snapshot.periods.sorted { $0.start < $1.start }
        expectedObservations = DailyBleedingValidation.sorted(snapshot.dailyBleeding)
        periods = expectedPeriods
        observations = expectedObservations
    }

    /// Default deletion proposal retains observations and their IDs; confirmation is still required.
    static func retainingDailyRecordsWhenDeleting(_ periodID: UUID, from snapshot: TrackerSnapshot) throws -> Self {
        guard snapshot.periods.contains(where: { $0.id == periodID }) else { throw TrackingError.missingRecord }
        var review = Self(snapshot: snapshot)
        review.periods.removeAll { $0.id == periodID }
        for index in review.observations.indices where review.observations[index].periodID == periodID {
            review.observations[index].periodID = nil
        }
        return review
    }
}
