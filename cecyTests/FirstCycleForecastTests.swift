import Foundation
import Testing
@testable import cecy

nonisolated struct FirstCycleForecastTests {
    let start = try! LocalDay(key: 20261007)

    @Test(arguments: [nil, 32] as [Int?])
    func firstStartUsesKnownCycleOrLabelledDefault(cycleDays: Int?) throws {
        var profile = LocalProfile()
        profile.typicalCycleDays = cycleDays
        profile.typicalPeriodDays = 5
        let periods = [Period(start: start)]
        let overview = CycleCalculator.overview(periods: periods, today: start, engine: EvidencePredictionEngine(), profile: profile)
        let estimate = try #require(overview.estimate)
        #expect(start.days(until: estimate.center) == (cycleDays ?? 28))
        #expect(estimate.basis == (cycleDays == nil ? .cecyDefault : .usualCycle))
        #expect(estimate.reportedCycleDays == cycleDays && estimate.sourceLengths.isEmpty && estimate.confidence == .low)
        let forecast = CycleForecast.calculate(overview: overview, profile: profile, periods: periods)
        #expect(forecast.bleeding(on: start) == nil)
        for key in 20261008...20261011 { #expect(try forecast.bleeding(on: LocalDay(key: key)) != nil) }
        #expect(try forecast.bleeding(on: LocalDay(key: 20261012)) == nil)
        #expect(forecast.cycles.first?.ovulation?.center == (try estimate.center.adding(days: -14)))
        #expect(forecast.cycles.first?.fertileWindow?.start == (try estimate.center.adding(days: -19)))
        let phase = try #require(CyclePhaseTimeline.make(overview: overview, forecast: forecast, periods: periods, profile: profile, today: start))
        #expect(phase.cycleDay == 1 && phase.currentIsRecorded && phase.currentPhase == .menstrual)
        #expect(phase.segments.first?.days == 1...5)
        #expect(periods[0].end == nil && profile.typicalCycleDays == cycleDays)
    }

    @Test func durationFallbackAndConfirmedEndsOverrideAssumptions() throws {
        for supplied in [nil, 7] as [Int?] {
            var profile = LocalProfile(); profile.typicalPeriodDays = supplied
            var period = Period(start: start)
            let overview = CycleCalculator.overview(periods: [period], today: try start.adding(days: 10), profile: profile)
            let unknown = CycleForecast.calculate(overview: overview, profile: profile, periods: [period])
            #expect(unknown.currentBleeding?.end == (try start.adding(days: (supplied ?? 5) - 1)))
            #expect(unknown.cycles.first?.bleedingDuration?.usesDefault == (supplied == nil))
            for length in [3, 8] {
                period.end = try start.adding(days: length - 1)
                let known = CycleForecast.calculate(overview: overview, profile: profile, periods: [period])
                #expect(known.currentBleeding == nil)
                for offset in 0...9 { #expect(try known.bleeding(on: start.adding(days: offset)) == nil) }
                let timeline = try #require(CyclePhaseTimeline.make(overview: overview, forecast: known, periods: [period], profile: profile, today: try start.adding(days: length)))
                #expect(timeline.recordedBleeding == 1...length && !timeline.bleedingIsEstimated)
                #expect(timeline.currentPhase == .follicular)
                #expect(known.cycles.first?.bleedingDuration?.days == length)
                #expect(known.cycles.first?.period.center == overview.estimate?.center)
            }
        }
    }

    @Test func dailyAnswersOverrideEstimatedMarkersWithoutStartingCycles() throws {
        let period = Period(start: start)
        let day = try start.adding(days: 1)
        for state in DailyBleedingState.allCases {
            let answer = DailyBleedingObservation(day: day, state: state)
            let snapshot = TrackerSnapshot(periods: [period], dailyBleeding: [answer])
            let overview = CycleCalculator.overview(periods: snapshot.periods, today: day)
            let forecast = CycleForecast.calculate(overview: overview, profile: nil, periods: snapshot.periods, dailyBleeding: snapshot.dailyBleeding)
            #expect(forecast.bleeding(on: day) == nil)
            #expect(!forecast.additionalDayDescription(day).contains("Estimated period day"))
            let markers = DayActivityMarker.calendar(recorded: DayActivityIndex(snapshot: snapshot).markers(on: day), forecast: forecast, day: day)
            #expect(markers.contains { $0.id == "dailyBleeding" })
            #expect(!markers.contains { $0.id == "forecast.bleeding" })
            let phase = try #require(CyclePhaseTimeline.make(overview: overview, forecast: forecast, periods: [period], profile: nil, today: day))
            #expect(phase.currentPhase == nil)
            #expect(CycleCalculator.overview(periods: [], today: day).estimate == nil)
        }
    }

    @Test func defaultsDoNotEnterReplayStatisticsOrAI() throws {
        let period = Period(start: start)
        var profile = LocalProfile()
        profile.setUnknown(.cycleLength, true); profile.setUnknown(.periodLength, true)
        let snapshot = TrackerSnapshot(periods: [period], profile: profile)
        let before = try AIContextBuilder.recordInsights(snapshot: snapshot, today: start)
        _ = CycleForecast.calculate(overview: CycleCalculator.overview(periods: [period], today: start, profile: profile), profile: profile, periods: [period])
        #expect(try AIContextBuilder.recordInsights(snapshot: snapshot, today: start) == before)
        #expect(profile.typicalCycleDays == nil && profile.typicalPeriodDays == nil)
        #expect(try CycleStatistics.calculate(periods: [period], today: start).cycles == nil)
        let next = Period(start: try start.adding(days: 28))
        for engine in [BaselinePredictionEngine() as any CyclePredicting, EvidencePredictionEngine(), ComparisonPredictionEngine(candidate: .mean)] {
            let replay = try PredictionBacktester.evaluate(periods: [period, next], today: next.start, engine: engine)
            #expect(replay.warmUpCount == 1 && replay.scored.isEmpty)
        }
    }

    @Test func noStartOrUnsuitableMeasuredHistoryDoesNotGainDefaultForecast() throws {
        let empty = CycleCalculator.overview(periods: [], today: start)
        #expect(CycleForecast.calculate(overview: empty, profile: nil).cycles.isEmpty)
        let periods = try [20260601, 20260701, 20260915].map { Period(start: try LocalDay(key: $0)) }
        let overview = CycleCalculator.overview(periods: periods, today: start)
        #expect(overview.prediction == .wideVariation)
        #expect(CycleForecast.calculate(overview: overview, profile: nil, periods: periods).cycles.isEmpty)
    }

    @Test func measuredIntervalsReplaceDefaultAndLongRecordsSuppressOverlappingEstimates() throws {
        let next = try start.adding(days: 31)
        let periods = [Period(start: start), Period(start: next)]
        let overview = CycleCalculator.overview(periods: periods, today: next)
        #expect(overview.estimate?.basis == .recordedHistory && overview.estimate?.sourceLengths == [31])
        #expect(overview.estimate?.center == (try next.adding(days: 31)))
        let long = Period(start: start, end: try start.adding(days: 30))
        let longOverview = CycleCalculator.overview(periods: [long], today: long.end!)
        let forecast = CycleForecast.calculate(overview: longOverview, profile: nil, periods: [long])
        for offset in 0...30 {
            let day = try start.adding(days: offset)
            #expect(forecast.period(on: day) == nil && forecast.bleeding(on: day) == nil)
            #expect(forecast.ovulation(on: day) == nil && forecast.fertile(on: day) == nil)
        }
    }
}

@MainActor struct FirstCycleForecastSessionTests {
    @Test func startEndEditsAndDailyOverridesRecalculateImmediately() throws {
        let today = try LocalDay(key: 20261020)
        let start = try LocalDay(key: 20261007)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        #expect(session.overview?.estimate == nil)
        let answer = DailyBleedingObservation(day: start, state: .bleeding)
        #expect(session.saveDailyBleeding(answer, editing: false) == nil)
        #expect(session.overview?.estimate == nil && session.snapshot.periods.isEmpty)
        var period = Period(start: start)
        #expect(session.save([period]) == nil)
        #expect(session.overview?.estimate?.basis == .cecyDefault)
        #expect(try session.cycleForecast.bleeding(on: LocalDay(key: 20261011)) != nil)
        period.end = try LocalDay(key: 20261009)
        #expect(session.update(period) == nil)
        #expect(try session.cycleForecast.bleeding(on: LocalDay(key: 20261011)) == nil)
        period.end = try LocalDay(key: 20261014)
        #expect(session.update(period) == nil)
        #expect(session.cycleForecast.cycles.first?.bleedingDuration?.days == 8)
        #expect(try session.activityIndex.markers(on: LocalDay(key: 20261014)).contains { $0.id == "period" })
        let before = session.cycleForecast
        session.refresh()
        #expect(session.cycleForecast == before)
        #expect(session.snapshot.periods.count == 1 && session.snapshot.dailyBleeding.count == 1)
    }
}
