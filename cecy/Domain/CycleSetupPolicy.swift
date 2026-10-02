import Foundation

/// Editable setup defaults, not population-based diagnoses or observed cycle data.
nonisolated enum CycleSetupPolicy {
    static let defaultPeriodDays = 5
    static let defaultCycleDays = 28
    static let periodDays = 1...30
    static let cycleDays = 10...120
}
