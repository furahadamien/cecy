import Foundation
import Testing
@testable import cecy

nonisolated struct CycleForecastTests {
    let today = try! LocalDay(key: 20260929)
    private func profile(_ days: Int = 28) -> LocalProfile {
        var value = LocalProfile(); value.typicalCycleDays = days; value.typicalPeriodDays = 5
        return value
    }

    @Test func oneStartProvidesPairedUpcomingCycles() throws {
        let periods = [Period(start: try LocalDay(key: 20260902))]
        let overview = CycleCalculator.overview(periods: periods, today: today, profile: profile())
        let forecast = CycleForecast.calculate(overview: overview, profile: profile())
        #expect(forecast.cycles.count == 3)
        #expect(try forecast.cycles.map(\.period.center) == [20260930, 20261028, 20261125].map { try LocalDay(key: $0) })
        #expect(try forecast.cycles.compactMap { $0.ovulation?.center } == [20260916, 20261014, 20261111].map { try LocalDay(key: $0) })
        #expect(forecast.nextOvulation(onOrAfter: today)?.index == 1)
        #expect(forecast.cycles[1].isLaterProjection && !forecast.cycles[0].isLaterProjection)
        #expect(periods.count == 1 && periods[0].end == nil && overview.intervals.isEmpty)
        #expect(try overview.estimate?.center == LocalDay(key: 20260930))
    }

    @Test func measuredMedianDrivesBothForecastsRatherThanProfileDefault() throws {
        let periods = try [20260702, 20260801, 20260901].map { Period(start: try LocalDay(key: $0)) }
        let overview = CycleCalculator.overview(periods: periods, today: today, profile: profile(60))
        let forecast = CycleForecast.calculate(overview: overview, profile: profile(60))
        #expect(overview.estimate?.sourceLengths == [30, 31])
        #expect(try forecast.cycles[0].period.center == LocalDay(key: 20261002))
        #expect(forecast.cycles[0].period.center.days(until: forecast.cycles[1].period.center) == 31)
        #expect(forecast.cycles[1].ovulation?.center.days(until: forecast.cycles[1].period.center) == 14)
    }

    @Test func windowsCarryUncertaintyAndLaterWindowsWiden() throws {
        let overview = CycleCalculator.overview(periods: [Period(start: try LocalDay(key: 20260902))], today: today, profile: profile())
        let forecast = CycleForecast.calculate(overview: overview, profile: profile())
        #expect(forecast.cycles[0].period.earliest == overview.estimate?.earliest)
        #expect(forecast.cycles[0].period.latest == overview.estimate?.latest)
        for cycle in forecast.cycles {
            let ovulation = try #require(cycle.ovulation)
            #expect(ovulation.earliest.days(until: cycle.period.earliest) == 16)
            #expect(ovulation.latest.days(until: cycle.period.latest) == 10)
            #expect(cycle.period.earliest.days(until: cycle.period.latest) == 6 * (cycle.index + 1))
            #expect(forecast.ovulation(on: ovulation.center)?.index == cycle.index)
            #expect(forecast.ovulation(on: ovulation.earliest) == nil)
            #expect(forecast.ovulation(on: ovulation.latest) == nil)
            #expect(forecast.period(on: cycle.period.center)?.index == cycle.index)
        }
    }

    @Test func projectionsNeverRollIndefinitelyOrReplaceOverdueEstimate() throws {
        let start = try LocalDay(key: 20260101), later = try LocalDay(key: 20261201)
        let early = CycleCalculator.overview(periods: [Period(start: start)], today: today, profile: profile())
        let late = CycleCalculator.overview(periods: [Period(start: start)], today: later, profile: profile())
        let forecast = CycleForecast.calculate(overview: late, profile: profile())
        #expect(early.prediction == late.prediction)
        #expect(forecast.cycles.count == 3 && forecast.nextOvulation(onOrAfter: later) == nil)
        #expect(forecast == CycleForecast.calculate(overview: early, profile: profile()))
        #expect(try late.estimate?.center == LocalDay(key: 20260129))
    }

    @Test func contextWarnsWithoutHidingDatesOrChangingPeriodForecasts() throws {
        let periods = [Period(start: try LocalDay(key: 20260902))]
        for context in [CycleContext.hormonalBirthControl, .recentlyStoppedBirthControl, .postpartum, .breastfeeding, .perimenopause] {
            var value = profile(); value.cycleContext = [context]
            let overview = CycleCalculator.overview(periods: periods, today: today, profile: value)
            let forecast = CycleForecast.calculate(overview: overview, profile: value)
            #expect(forecast.cycles.count == 3 && forecast.cycles.allSatisfy { $0.ovulation != nil })
            #expect(forecast.ovulationUnavailableReason == nil)
            #expect(forecast.cycles.allSatisfy { $0.ovulationWarnings.count == 1 && $0.ovulationWarnings[0].hasPrefix(context.title) })
            #expect(overview.prediction == CycleCalculator.overview(periods: periods, today: today, profile: profile()).prediction)
        }
    }

    @Test func calendarMarksOnlyOneDayPerCycleAndUpcomingNeverShowsPastMarker() throws {
        let start = try LocalDay(key: 20260902)
        let forecast = CycleForecast.calculate(overview: CycleCalculator.overview(periods: [Period(start: start)], today: today, profile: profile()), profile: profile())
        let marked = try (0..<100).map { try start.adding(days: $0) }.filter { forecast.ovulation(on: $0) != nil }
        #expect(marked == forecast.cycles.compactMap { $0.ovulation?.center })
        #expect(marked.count == 3)
        for day in marked {
            #expect(try forecast.ovulation(on: day.adding(days: -1)) == nil)
            #expect(try forecast.ovulation(on: day.adding(days: 1)) == nil)
        }
        let first = try #require(forecast.cycles[0].ovulation)
        #expect(forecast.nextOvulation(onOrAfter: first.center)?.index == 0)
        #expect(try forecast.nextOvulation(onOrAfter: first.center.adding(days: 1))?.index == 1)
        #expect(try first.contains(first.center.adding(days: 1))) // uncertainty is not artificially narrowed
    }

    @Test func warningsRespectSelectionsAndDoNotClaimOvulationIsAbsent() {
        #expect(OvulationNotice.contextWarnings([]).isEmpty)
        #expect(OvulationNotice.contextWarnings([.none, .nonHormonalBirthControl, .tryingToConceive]).isEmpty)
        let warnings = OvulationNotice.contextWarnings([.postpartum, .breastfeeding])
        #expect(warnings.count == 2)
        #expect(warnings.joined().contains("can still occur"))
        #expect(OvulationNotice.contextWarnings([.hormonalBirthControl])[0].contains("does not know your method"))
    }

    @Test func missingWideAndVeryShortCyclesDoNotInventOvulation() throws {
        let missing = CycleForecast.calculate(overview: CycleCalculator.overview(periods: [], today: today), profile: nil)
        #expect(missing.cycles.isEmpty)
        let periods = try [20260601, 20260701, 20260901].map { Period(start: try LocalDay(key: $0)) }
        #expect(CycleForecast.calculate(overview: CycleCalculator.overview(periods: periods, today: today), profile: nil).cycles.isEmpty)
        let short = CycleForecast.calculate(overview: CycleCalculator.overview(periods: [Period(start: today)], today: today, profile: profile(10)), profile: profile(10))
        #expect(short.cycles.count == 3 && short.cycles.allSatisfy { $0.ovulation == nil })
    }

    @Test func forecastCrossesLeapDayUsingCivilDates() throws {
        let start = try LocalDay(key: 20240215)
        let forecast = CycleForecast.calculate(overview: CycleCalculator.overview(periods: [Period(start: start)], today: start, profile: profile()), profile: profile())
        #expect(try forecast.cycles[0].ovulation?.center == LocalDay(key: 20240229))
        #expect(forecast.cycles[0].period.center.days(until: forecast.cycles[1].period.center) == 28)
    }
}

@MainActor struct CycleForecastSessionTests {
    @Test func actualRecordedStartReanchorsBothForecastsAndDeletionRestoresThem() throws {
        let today = try LocalDay(key: 20261002)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        let periods = try [20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        #expect(session.save(periods) == nil)
        let original = session.cycleForecast
        let actual = Period(start: try LocalDay(key: 20261001))
        #expect(session.save([actual]) == nil)
        #expect(session.cycleForecast != original)
        #expect(try session.cycleForecast.cycles.first?.period.center == LocalDay(key: 20261030))
        #expect(try session.cycleForecast.cycles.first?.ovulation?.center == LocalDay(key: 20261016))
        #expect(session.snapshot.periods.count == 3)
        #expect(session.delete(id: actual.id) == nil)
        #expect(session.cycleForecast == original && session.snapshot.periods.count == 2)
    }
}
