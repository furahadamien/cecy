import Foundation

/// Operational eligibility, separate from measured facts and retrospective scoring.
nonisolated enum ForecastAvailabilityPolicy {
    static func applying(to overview: CycleOverview) -> CycleOverview {
        guard let estimate = overview.estimate else { return overview }
        // Match the existing projection bounds; never replace unsuitable history
        // with a dated estimate from the profile. Records and intervals stay intact.
        guard let start = overview.latestStart,
              CycleSetupPolicy.cycleDays.contains(start.days(until: estimate.center)) else {
            return CycleOverview(latestStart: overview.latestStart, currentDay: overview.currentDay,
                                 intervals: overview.intervals, prediction: .unavailable(.unsupportedEstimate))
        }
        return overview
    }
}