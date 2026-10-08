import Foundation
import Testing
@testable import cecy

nonisolated struct CycleDomainTests {
    private func day(_ key: Int) throws -> LocalDay { try LocalDay(key: key) }
    private func history(_ lengths: [Int]) throws -> [Period] {
        var periods = [Period(start: try day(20200101))]
        for length in lengths { periods.append(Period(start: try periods.last!.start.adding(days: length))) }
        return periods
    }

    @Test func civilDatesAndBoundaries() throws {
        #expect(throws: TrackingError.invalidDay) { try day(20260230) }
        #expect(throws: TrackingError.invalidDay) { try day(0) }
        #expect(throws: TrackingError.invalidDay) { try day(100000101) }
        #expect(try day(20240228).days(until: day(20240301)) == 2)
        #expect(try day(20250228).days(until: day(20250301)) == 1)
        #expect(try day(20251231).adding(days: 1) == day(20260101))
        #expect(try day(20260307).days(until: day(20260309)) == 2)
        #expect(try day(20261031).days(until: day(20261102)) == 2)
        #expect(try day(20260131).adding(months: 1) == day(20260228))
        #expect(throws: TrackingError.invalidDay) { try day(99991231).adding(days: 1) }
        #expect(throws: TrackingError.invalidDay) { try day(10101).adding(days: -1) }
        #expect(throws: TrackingError.invalidDay) { try day(10101).adding(months: -1) }
    }

    @Test func timeZonesNeverRewriteRecordedDay() throws {
        let recorded = try day(20260902)
        let instant = ISO8601DateFormatter().date(from: "2026-09-29T08:00:00Z")!
        #expect(try LocalDay(date: instant, timeZone: TimeZone(identifier: "America/Los_Angeles")!) == day(20260929))
        #expect(try LocalDay(date: instant, timeZone: TimeZone(identifier: "Pacific/Kiritimati")!) == day(20260929))
        let crossing = instant.addingTimeInterval(4 * 3600)
        #expect(try LocalDay(date: crossing, timeZone: TimeZone(identifier: "Pacific/Kiritimati")!) == day(20260930))
        for name in ["America/Los_Angeles", "Pacific/Kiritimati", "Europe/Paris"] {
            let zone = TimeZone(identifier: name)!
            #expect(try LocalDay(date: recorded.pickerDate(in: zone), timeZone: zone) == recorded)
        }
        #expect(recorded.key == 20260902)
    }

    @Test func validationAndDuration() throws {
        let today = try day(20260929)
        let start = try day(20260902)
        let period = Period(start: start, end: try day(20260906))
        #expect(period.duration == 5)
        #expect(Period(start: start, end: start).duration == 1)
        #expect(Period(start: start).duration == nil)
        #expect(throws: TrackingError.duplicateStart) {
            try PeriodValidation.validate([period, Period(start: start)], asOf: today)
        }
        #expect(throws: TrackingError.overlap) {
            try PeriodValidation.validate([period, Period(start: day(20260906))], asOf: today)
        }
        #expect(throws: TrackingError.futureDate) {
            try PeriodValidation.validate([Period(start: day(20260930))], asOf: today)
        }
        #expect(throws: TrackingError.reversedEnd) {
            try PeriodValidation.validate([Period(start: start, end: day(20260901))], asOf: today)
        }
        try PeriodValidation.validate([Period(start: start), Period(start: day(20260903))], asOf: today)
    }

    @Test func workedFixtureAndPassedWindow() throws {
        let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try day($0)) }
        let result = CycleCalculator.overview(periods: periods.reversed(), today: try day(20260929))
        #expect(result.currentDay == 28)
        #expect(result.intervals.map(\.length) == [28, 30, 29])
        let prediction = try #require(result.estimate)
        #expect(try prediction.center == day(20261001))
        #expect(try prediction.earliest == day(20260928))
        #expect(try prediction.latest == day(20261004))
        #expect(prediction.confidence == .low)
        let passed = CycleCalculator.overview(periods: periods, today: try day(20261005))
        #expect(passed.currentDay == 34)
        #expect(passed.estimate == prediction)
        let skew = CycleCalculator.overview(periods: periods, today: try day(20260901))
        #expect(skew.currentDay == nil)
        #expect(skew.prediction == .unavailable(.futureDate))
    }

    @Test func availableMeasuredIntervalsNeverRequireFourStarts() throws {
        for count in 0...3 {
            let periods = Array(try history([28, 29]).prefix(count))
            let overview = CycleCalculator.overview(periods: periods, today: try day(20210101))
            if count == 0 {
                #expect(overview.estimate == nil)
                #expect(overview.prediction == .insufficientHistory(completedIntervals: 0))
            } else if count == 1 {
                #expect(overview.estimate?.basis == .cecyDefault)
                #expect(overview.estimate?.sourceLengths.isEmpty == true)
            } else {
                #expect(overview.estimate?.sourceLengths.count == count - 1)
                #expect(overview.estimate?.confidence == .low)
            }
        }
    }

    @Test func confidenceSpreadRoundingAndRecentHistory() throws {
        let today = try day(20250101)
        func estimate(_ lengths: [Int]) throws -> CycleOverview {
            CycleCalculator.overview(periods: try history(lengths), today: today)
        }
        #expect(try estimate([28, 29, 30, 28, 29, 30]).estimate?.confidence == .moderate)
        #expect(try estimate([28, 28, 28, 28, 28, 35]).estimate?.confidence == .moderate)
        #expect(try estimate([28, 28, 28, 28, 28, 36]).estimate?.confidence == .low)
        #expect(try estimate([28, 28, 42]).estimate != nil)
        #expect(try estimate([28, 28, 43]).prediction == .wideVariation)
        #expect(try estimate([20, 29, 40]).prediction == .wideVariation)
        let equal = try #require(estimate([28, 28, 28]).estimate)
        #expect(equal.earliest.days(until: equal.latest) == 4)
        let rounded = try estimate([28, 29, 30, 31])
        #expect(try #require(rounded.latestStart).days(until: #require(rounded.estimate).center) == 30)
        let recent = try estimate([90, 28, 29, 30, 28, 29, 30])
        #expect(recent.intervals.count == 7)
        #expect(recent.estimate?.sourceLengths == [28, 29, 30, 28, 29, 30])
        let small = try #require(estimate([1, 1, 1]).estimate)
        #expect(small.earliest.days(until: small.latest) == 2)
    }

    @Test func recordedSpansAndEstimatedStartsRemainDistinct() throws {
        let start = try day(20260902)
        let onlyStart = Period(start: start)
        #expect(onlyStart.contains(start))
        #expect(try !onlyStart.contains(day(20260903)))
        let span = Period(start: start, end: try day(20260906))
        #expect(try span.contains(day(20260906)))
        #expect(try !span.contains(day(20260907)))
        let periods = try [20261007, 20261104, 20261202, 20261230].map { Period(start: try day($0)) }
        let result = CycleCalculator.overview(periods: periods, today: try day(20261231))
        let estimate = try #require(result.estimate)
        #expect(try estimate.earliest == day(20270125))
        #expect(try estimate.latest == day(20270129))
        #expect(estimate.contains(estimate.latest))
        #expect(try !estimate.contains(estimate.latest.adding(days: 1)))
    }

    @Test func manyYearsOfHistoryUseOnlyRecentPredictionInputs() throws {
        let periods = try history(Array(repeating: 28, count: 300))
        let latest = try #require(periods.last).start
        let result = CycleCalculator.overview(periods: periods, today: try latest.adding(days: 10))
        #expect(result.currentDay == 11)
        #expect(result.intervals.count == 300)
        #expect(result.estimate?.sourceLengths == Array(repeating: 28, count: 6))
    }
}
