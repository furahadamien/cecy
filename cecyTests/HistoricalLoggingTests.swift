import Foundation
import Testing
@testable import cecy

nonisolated struct UpcomingForecastTests {
    let today = try! LocalDay(key: 20261002)
    private func profile() -> LocalProfile {
        var p = LocalProfile(); p.typicalCycleDays = 28; p.typicalPeriodDays = 5
        return p
    }

    @Test func oldRecordProvidesUpcomingProjectionsWithoutInventingPastPeriods() throws {
        let records = [Period(start: try LocalDay(key: 20260101))]
        let overview = CycleCalculator.overview(periods: records, today: today, profile: profile())
        let forecast = CycleForecast.calculate(overview: overview, profile: profile(), periods: records, asOf: today)
        let next = try #require(forecast.nextPeriod(onOrAfter: today))
        #expect(try next.period.center == LocalDay(key: 20261008))
        #expect(next.isLaterProjection)
        #expect(forecast.cycles.filter { $0.period.center >= today }.count == 3)
        #expect(forecast.cycles.count <= 7)
        #expect(try overview.estimate?.center == LocalDay(key: 20260129))
        #expect(records.count == 1 && records[0].end == nil && overview.intervals.isEmpty)
        let later = try today.adding(days: 3650)
        let advanced = CycleForecast.calculate(overview: overview, profile: profile(), periods: records, asOf: later)
        #expect(advanced.cycles.count <= 7)
        #expect(try #require(advanced.nextPeriod(onOrAfter: later)).period.center >= later)
    }

    @Test func nextMeansTodayOrLaterEvenWhenPreviousWindowStillOverlapsToday() throws {
        let start = try LocalDay(key: 20260902)
        let overview = CycleCalculator.overview(periods: [Period(start: start)], today: today, profile: profile())
        let forecast = CycleForecast.calculate(overview: overview, profile: profile(), asOf: today)
        #expect(forecast.cycles[0].period.contains(today))
        #expect(try forecast.nextPeriod(onOrAfter: today)?.period.center == LocalDay(key: 20261028))
        let exact = try LocalDay(key: 20261028)
        #expect(forecast.nextPeriod(onOrAfter: exact)?.period.center == exact)
    }

    @Test func wideHistoricalGapsKeepExplicitTypicalCycleReference() throws {
        let records = try [20260101, 20260805, 20260902].map { Period(start: try LocalDay(key: $0)) }
        let overview = CycleCalculator.overview(periods: records, today: today, profile: profile())
        #expect(overview.prediction == .wideVariation)
        let forecast = CycleForecast.calculate(overview: overview, profile: profile(), periods: records, asOf: today)
        let next = try #require(forecast.nextPeriod(onOrAfter: today))
        #expect(next.referenceNotice != nil && next.ovulationBasis.contains("entered 28-day"))
        #expect(next.period.center >= today && records.count == 3)
        #expect(CycleForecast.calculate(overview: overview, profile: nil, asOf: today).cycles.isEmpty)
    }

    @Test func adjacentStartsDoNotBecomeOneDayFutureCycles() throws {
        let records = try [20260902, 20260903].map { Period(start: try LocalDay(key: $0)) }
        let overview = CycleCalculator.overview(periods: records, today: today, profile: profile())
        #expect(overview.estimate?.sourceLengths == [1]) // facts are retained, not deleted or merged
        let forecast = CycleForecast.calculate(overview: overview, profile: profile(), asOf: today)
        let next = try #require(forecast.nextPeriod(onOrAfter: today))
        #expect(next.referenceNotice != nil)
        #expect(try next.period.center == LocalDay(key: 20261029))
    }

    @Test func selectionOffersContinuationWithoutAutomaticallyMerging() throws {
        let period = Period(start: try LocalDay(key: 20260902), end: try LocalDay(key: 20260904))
        #expect(try PeriodLogSelection.existing(on: LocalDay(key: 20260903), periods: [period]) == period)
        #expect(try PeriodLogSelection.continuation(on: LocalDay(key: 20260903), periods: [period]) == nil)
        #expect(try PeriodLogSelection.continuation(on: LocalDay(key: 20260905), periods: [period]) == period)
        #expect(try PeriodLogSelection.continuation(on: LocalDay(key: 20261002), periods: [period]) == nil)
        #expect(try PeriodLogSelection.continuation(on: LocalDay(key: 20260901), periods: [period]) == nil)
        #expect(try period.end == LocalDay(key: 20260904))
    }
}

@MainActor struct HistoricalLoggingSessionTests {
    let today = try! LocalDay(key: 20261002)
    private func session() throws -> TrackerSession {
        let repo = try SwiftDataPeriodRepository.inMemory()
        var p = LocalProfile(); p.preferredName = "Synthetic"; p.birthDayKey = 19950512
        p.typicalCycleDays = 28; p.typicalPeriodDays = 5
        _ = try repo.saveProfile(p, today: today)
        let session = TrackerSession(repository: { repo }, clock: { self.today.formattingDate }, timeZone: { .gmt })
        session.load()
        return session
    }

    @Test func addingPastPeriodAndSymptomsPreservesRecordsAndUpcomingForecast() throws {
        let s = try session()
        let recent = try [20260805, 20260902].map { Period(start: try LocalDay(key: $0)) }
        #expect(s.save(recent) == nil)
        let older = Period(start: try LocalDay(key: 20260101), end: try LocalDay(key: 20260105))
        #expect(s.save([older]) == nil)
        #expect(s.snapshot.periods.count == 3 && Set(s.snapshot.periods.map(\.id)).isSuperset(of: Set(recent.map(\.id))))
        #expect(s.overview?.latestStart == recent.last?.start)
        #expect(try #require(s.cycleForecast.nextPeriod(onOrAfter: today)).period.center >= today)
        let forecast = s.cycleForecast
        #expect(s.saveSymptom(SymptomEntry(day: try LocalDay(key: 20260103), kind: .cramps)) == nil)
        #expect(s.cycleForecast == forecast && s.snapshot.periods.count == 3)
        s.refresh()
        #expect(s.cycleForecast == forecast)
        #expect(s.delete(id: older.id) == nil)
        #expect(s.snapshot.periods.count == 2 && s.cycleForecast.nextPeriod(onOrAfter: today)?.referenceNotice == nil)
    }

    @Test func confirmingBleedingRefinesDurationNotCycleCountAndRejectsFutureDays() throws {
        let s = try session()
        let period = Period(start: try LocalDay(key: 20260902), notes: "Keep this note")
        #expect(s.save([period]) == nil)
        let primary = s.overview?.prediction
        var updated = period; updated.end = try LocalDay(key: 20260905)
        #expect(s.update(updated) == nil)
        #expect(s.snapshot.periods.count == 1 && s.snapshot.periods[0].duration == 4)
        #expect(s.snapshot.periods[0].notes == period.notes && s.overview?.prediction == primary)
        #expect(s.cycleForecast.cycles.first?.bleedingDuration?.days == 4)
        let saved = s.snapshot, forecast = s.cycleForecast
        updated.end = try today.adding(days: 1)
        #expect(s.update(updated) != nil)
        #expect(s.save([Period(start: try today.adding(days: 1))]) != nil)
        #expect(s.saveSymptom(SymptomEntry(day: try today.adding(days: 1), kind: .cramps)) != nil)
        #expect(s.snapshot == saved && s.cycleForecast == forecast)
    }
}
