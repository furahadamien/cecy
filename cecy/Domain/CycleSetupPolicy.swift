import Foundation

/// Editable setup defaults, not population-based diagnoses or observed cycle data.
nonisolated enum CycleSetupPolicy {
    static let defaultPeriodDays = 5
    static let defaultCycleDays = 28
    static let periodDays = 1...30
    static let cycleDays = 10...120
    // Explicit uncalibrated starter display range; not an Apple formula or probability interval.
    static let starterPaddingDays = 3

    static func starter(lastStart: LocalDay, cycleDays: Int, periodDays: Int?) throws -> CyclePrediction {
        guard self.cycleDays.contains(cycleDays),
              periodDays.map({ self.periodDays.contains($0) && $0 <= cycleDays }) ?? true else {
            throw TrackingError.invalidData
        }
        return CyclePrediction(center: try lastStart.adding(days: cycleDays),
            earliest: try lastStart.adding(days: cycleDays - starterPaddingDays),
            latest: try lastStart.adding(days: cycleDays + starterPaddingDays),
            confidence: .low, sourceLengths: [], basis: .usualCycle,
            reportedCycleDays: cycleDays, reportedPeriodDays: periodDays)
    }
}
