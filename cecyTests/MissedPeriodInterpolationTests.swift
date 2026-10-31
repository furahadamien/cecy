import Foundation
import Testing
@testable import cecy

/// A forgotten month must not wipe out the forecast: the missing start is interpolated.
nonisolated struct MissedPeriodInterpolationTests {
    private let today = try! LocalDay(key: 20261025)

    private func periods(_ keys: [Int]) -> [Period] {
        keys.map { Period(start: try! LocalDay(key: $0)) }
    }

    private func overview(_ keys: [Int], profile: LocalProfile? = nil, factors: [CycleFactor] = []) -> CycleOverview {
        ForecastAvailabilityPolicy.applying(to: CycleCalculator.overview(periods: periods(keys), today: today,
                                                                         engine: EvidencePredictionEngine(),
                                                                         profile: profile, factors: factors))
    }

    /// The reported bug: June, July, August and October logged, September forgotten.
    @Test func missingSeptemberStillProducesAForecast() throws {
        let result = overview([20260603, 20260701, 20260729, 20260826, 20261021])
        let estimate = try #require(result.estimate, "Forecast disappeared: \(result.prediction)")
        // The next start follows the usual 28-day rhythm, not the 56-day gap.
        #expect(try estimate.center == LocalDay(key: 20261118))
        #expect(estimate.sourceLengths == [28, 28, 28, 28, 28])
        #expect(estimate.confidence == .low)
        #expect(try result.inferredStarts == [LocalDay(key: 20260923)])
        // Recorded history is never rewritten: the 56-day interval stays as logged.
        #expect(result.intervals.map(\.length) == [28, 28, 28, 56])
    }

    @Test func missingMonthWithOnlyTwoMeasuredIntervals() throws {
        // June, July, then August forgotten, September logged.
        let result = overview([20260603, 20260701, 20260826])
        let estimate = try #require(result.estimate)
        #expect(estimate.sourceLengths == [28, 28, 28])
        #expect(try estimate.center == LocalDay(key: 20260923))
    }

    @Test func singleGapUsesTheUsualCycleLengthWhenThereIsNoOtherHistory() throws {
        var profile = LocalProfile()
        profile.typicalCycleDays = 30
        let result = overview([20260822, 20261021], profile: profile)
        let estimate = try #require(result.estimate)
        #expect(estimate.sourceLengths == [30, 30])
        #expect(try result.inferredStarts == [LocalDay(key: 20260921)])
    }

    @Test func twoMissedMonthsAreBothInterpolated() throws {
        let result = overview([20260408, 20260506, 20260603, 20260701, 20260923])
        let estimate = try #require(result.estimate)
        #expect(estimate.sourceLengths.suffix(3) == [28, 28, 28])
        #expect(try result.inferredStarts == [LocalDay(key: 20260729), LocalDay(key: 20260826)])
    }

    @Test func slightlyUnevenGapIsSplitAsEvenlyAsPossible() throws {
        // 57 days ≈ two 28–29 day cycles.
        let result = overview([20260603, 20260701, 20260729, 20260924])
        let estimate = try #require(result.estimate)
        #expect(estimate.sourceLengths.suffix(2).sorted() == [28, 29])
    }

    @Test func genuinelyIrregularCyclesAreNotSplit() {
        // 41 days is not close to a multiple of 28, so nothing is invented.
        let result = overview([20260603, 20260701, 20260729, 20260908])
        #expect(result.inferredStarts.isEmpty)
        #expect(result.estimate?.sourceLengths.contains(41) ?? true)
    }

    @Test func consistentlyLongCyclesAreNotSplit() {
        // Someone whose cycles are always ~56 days has no missing months.
        let result = overview([20260201, 20260329, 20260524, 20260719, 20260913])
        #expect(result.inferredStarts.isEmpty)
        #expect(result.estimate?.sourceLengths == [56, 56, 56, 56])
    }

    @Test func singleIntervalWithoutAReferenceIsLeftAlone() {
        let result = overview([20260826, 20261021])
        #expect(result.inferredStarts.isEmpty)
        #expect(result.estimate?.sourceLengths == [56])
    }

    @Test func regularHistoryIsUnchanged() {
        let result = overview([20260603, 20260701, 20260729, 20260826, 20260923, 20261021])
        #expect(result.inferredStarts.isEmpty)
        #expect(result.estimate?.sourceLengths == [28, 28, 28, 28, 28])
    }

    @Test func intervalsExcludedByAFactorAreNotInterpolated() throws {
        // A pregnancy (excluded from forecasts) explains the long gap; it must not be split.
        let factor = CycleFactor(kind: .pregnancy, start: try LocalDay(key: 20260801), end: try LocalDay(key: 20260815),
                                 excludesFromForecast: true)
        let result = overview([20260603, 20260701, 20260729, 20261021], factors: [factor])
        #expect(result.inferredStarts.isEmpty)
        #expect(result.estimate?.sourceLengths == [28, 28])
    }
}
