import Foundation
import Testing
@testable import cecy

@MainActor struct TodayPresentationTests {
    private func estimate(center: LocalDay) throws -> PredictionOutcome {
        .available(CyclePrediction(center: center, earliest: try center.adding(days: -3),
                                   latest: try center.adding(days: 3), confidence: .low, sourceLengths: [28]))
    }

    @Test func countdownUsesCivilDaysAcrossLeapDay() throws {
        let center = try LocalDay(key: 20240301)
        let outcome = try estimate(center: center)
        #expect(TodayPeriodCountdown(outcome: outcome, today: try LocalDay(key: 20240228)).title == "About 2 days")
        #expect(TodayPeriodCountdown(outcome: outcome, today: try LocalDay(key: 20240229)).title == "About 1 day")
        #expect(TodayPeriodCountdown(outcome: outcome, today: center).title == "Estimated today")
    }

    @Test func passedCenterDoesNotProduceNegativeCountdownOrRollForward() throws {
        let center = try LocalDay(key: 20260930)
        let outcome = try estimate(center: center)
        for offset in [1, 3] {
            #expect(TodayPeriodCountdown(outcome: outcome, today: try center.adding(days: offset)).title == "Within estimated window")
        }
        for offset in [4, 30, 365] {
            let display = TodayPeriodCountdown(outcome: outcome, today: try center.adding(days: offset))
            #expect(display.title == "Estimated window passed")
            #expect(display.detail.contains("An estimate, not a deadline"))
        }
    }

    @Test func missingVariableAndInvalidHistoryDoNotInventDates() throws {
        let today = try LocalDay(key: 20260929)
        #expect(TodayPeriodCountdown(outcome: .insufficientHistory(completedIntervals: 0), today: today).title == "More history needed")
        #expect(TodayPeriodCountdown(outcome: .wideVariation, today: today).title == "Timing uncertain")
        let invalid = TodayPeriodCountdown(outcome: .unavailable(.invalidData), today: today)
        #expect(invalid.title == "Estimate unavailable")
        #expect(invalid.detail == TrackingError.invalidData.localizedDescription)
    }

    @Test func countdownPresentationDoesNotChangeRecordedCycleDayOrStarterEstimate() throws {
        let today = try LocalDay(key: 20260929)
        var profile = LocalProfile()
        profile.typicalCycleDays = 28
        let overview = CycleCalculator.overview(periods: [Period(start: try LocalDay(key: 20260902))],
                                                today: today, profile: profile)
        #expect(TodayPeriodCountdown(outcome: overview.prediction, today: today).title == "About 1 day")
        #expect(overview.currentDay == 28)
        #expect(overview.estimate?.basis == .usualCycle)
    }
}
