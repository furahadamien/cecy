import Foundation

/// Suggestions for explicit user choice, never automatic merging or inferred bleeding.
nonisolated enum PeriodLogSelection {
    static func existing(on day: LocalDay, periods: [Period]) -> Period? {
        periods.first { $0.contains(day) }
    }

    static func continuation(on day: LocalDay, periods: [Period]) -> Period? {
        guard existing(on: day, periods: periods) == nil,
              let previous = periods.filter({ $0.start < day }).max(by: { $0.start < $1.start }),
              previous.start.days(until: day) < 30 else { return nil }
        return previous
    }
}
