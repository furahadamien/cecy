import Foundation

/// Suggestions for explicit user choice, never automatic merging or inferred bleeding.
nonisolated enum PeriodLogSelection {
    static func existing(on day: LocalDay, periods: [Period], dailyBleeding: [DailyBleedingObservation] = []) -> Period? {
        if let period = periods.first(where: { $0.contains(day) }) { return period }
        guard let answer = dailyBleeding.first(where: { $0.day == day && $0.state == .bleeding }),
              let id = answer.periodID, let period = periods.first(where: { $0.id == id }),
              DailyBleedingValidation.canAssociate(day, with: period, periods: periods) else { return nil }
        return period
    }

    static func continuation(on day: LocalDay, periods: [Period]) -> Period? {
        guard existing(on: day, periods: periods) == nil,
              let previous = periods.filter({ $0.start < day }).max(by: { $0.start < $1.start }),
              previous.start.days(until: day) < 30 else { return nil }
        return previous
    }
}
