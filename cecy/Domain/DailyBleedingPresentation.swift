import Foundation

extension DailyBleedingState {
    nonisolated var title: String {
        switch self {
        case .bleeding: "Bleeding"
        case .spotting: "Spotting"
        case .noBleeding: "No bleeding"
        case .unsure: "Not sure"
        }
    }

    nonisolated var symbol: String {
        switch self {
        case .bleeding: "drop.circle.fill"
        case .spotting: "circle.fill"
        case .noBleeding: "minus.circle"
        case .unsure: "questionmark.circle"
        }
    }
}

extension BleedingReconciliation {
    /// A proposal only. Callers must show detached answers before committing.
    nonisolated mutating func replacePeriod(_ period: Period) {
        if let index = periods.firstIndex(where: { $0.id == period.id }) { periods[index] = period }
        else { periods.append(period) }
        for index in observations.indices {
            guard let id = observations[index].periodID,
                  let linked = periods.first(where: { $0.id == id }) else { continue }
            if !DailyBleedingValidation.canAssociate(observations[index].day, with: linked, periods: periods) {
                observations[index].periodID = nil
            }
        }
    }

    nonisolated var detachedAnswers: [DailyBleedingObservation] {
        let current = Dictionary(observations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return expectedObservations.filter { old in
            old.periodID != nil && current[old.id]?.periodID == nil && current[old.id] != nil
        }
    }

    nonisolated var changedPeriods: [Period] {
        periods.filter { value in expectedPeriods.first(where: { $0.id == value.id }) != value }
    }
}
