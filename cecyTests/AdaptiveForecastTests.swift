import Foundation
import Testing
@testable import cecy

nonisolated struct AdaptiveForecastTests {
    private let start = try! LocalDay(key: 20261001)
    private func profile(cycle: Int = 28, bleeding: Int? = 5) -> LocalProfile {
        var result = LocalProfile()
        result.typicalCycleDays = cycle
        result.typicalPeriodDays = bleeding
        return result
    }
    private func forecast(_ periods: [Period], profile: LocalProfile?) -> CycleForecast {
        let today = try! start.adding(days: 100)
        return CycleForecast.calculate(
            overview: CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine(), profile: profile),
            profile: profile, periods: periods)
    }

    @Test func oneStartProducesDistinctStartBleedingOvulationAndFertileWindows() throws {
        let records = [Period(start: start)]
        let result = forecast(records, profile: profile())
        let cycle = try #require(result.cycles.first)
        #expect(try cycle.period.center == LocalDay(key: 20261029))
        #expect(try cycle.period.earliest == LocalDay(key: 20261026))
        #expect(try cycle.period.latest == LocalDay(key: 20261101))
        #expect(try cycle.bleeding == ForecastInterval(start: LocalDay(key: 20261029), end: LocalDay(key: 20261102)))
        #expect(try cycle.ovulation?.center == LocalDay(key: 20261015))
        #expect(try cycle.fertileWindow == ForecastInterval(start: LocalDay(key: 20261010), end: LocalDay(key: 20261015)))
        #expect(try cycle.fertileEnvelope == ForecastInterval(start: LocalDay(key: 20261005), end: LocalDay(key: 20261022)))
        #expect(try cycle.bleedingEnvelope == ForecastInterval(start: LocalDay(key: 20261026), end: LocalDay(key: 20261105)))
        #expect(cycle.bleedingDuration?.measuredCount == 0)
        #expect(records.count == 1 && records[0].end == nil)
        #expect(try result.bleeding(on: LocalDay(key: 20261102)) != nil)
        #expect(try result.period(on: LocalDay(key: 20261102)) == nil)
        #expect(try result.additionalDayDescription(LocalDay(key: 20261010)).contains("not safe days"))
    }

    @Test func sixFertileDatesButExactlyOneOvulationMarkerPerCycle() throws {
        let result = forecast([Period(start: start)], profile: profile())
        for cycle in result.cycles {
            let window = try #require(cycle.fertileWindow)
            #expect(window.start.days(until: window.end) + 1 == 6)
            let dates = try (0..<6).map { try window.start.adding(days: $0) }
            #expect(dates.allSatisfy { result.fertile(on: $0)?.index == cycle.index })
            #expect(dates.filter { result.ovulation(on: $0) != nil }.count == 1)
            #expect(try result.fertile(on: window.start.adding(days: -1)) == nil)
            #expect(try result.fertile(on: window.end.adding(days: 1)) == nil)
            #expect(cycle.contains(window.start))
        }
    }

    @Test func confirmedDurationsReplaceEnteredAssumptionIndependentlyOfCycleLengths() throws {
        let records = try [0, 28, 58].enumerated().map { index, offset in
            let day = try start.adding(days: offset)
            return Period(start: day, end: index == 2 ? nil : try day.adding(days: index == 0 ? 3 : 5))
        }
        let cycle = try #require(forecast(records, profile: profile(bleeding: 9)).cycles.first)
        #expect(cycle.bleedingDuration == BleedingDurationEstimate(days: 5, minimum: 4, maximum: 6, measuredCount: 2))
        #expect(records.last!.start.days(until: cycle.period.center) == 29)
        #expect(cycle.bleeding?.start.days(until: cycle.bleeding!.end) == 4)
        #expect(cycle.period.latest.days(until: cycle.bleedingEnvelope!.end) == 5)
    }

    @Test func usesOnlySixLatestConfirmedDurationsAndKeepsUnknownEndsUnknown() throws {
        let records = try (0..<8).map { index -> Period in
            let day = try start.adding(days: -28 * (7 - index))
            return Period(start: day, end: index == 7 ? nil : try day.adding(days: index == 0 ? 19 : 3))
        }
        let duration = BleedingDurationEstimate.calculate(periods: records.reversed(), profile: profile(), latestStart: start)
        #expect(duration == BleedingDurationEstimate(days: 4, minimum: 4, maximum: 4, measuredCount: 6))
        #expect(records.last?.end == nil)
    }

    @Test func moreDataRefinesButDoesNotGuaranteeNarrowerWindowsOrOvulationConfidence() throws {
        let one = forecast([Period(start: start)], profile: profile())
        let stable = try [0, 28, 56, 84].map { Period(start: try start.adding(days: $0)) }
        let learned = try #require(forecast(stable, profile: profile()).cycles.first)
        #expect(learned.period.earliest.days(until: learned.period.latest) == 4)
        #expect(one.cycles[0].period.earliest.days(until: one.cycles[0].period.latest) == 6)
        let varying = try [0, 28, 61, 89].map { Period(start: try start.adding(days: $0)) }
        let wider = try #require(forecast(varying, profile: profile()).cycles.first)
        #expect(wider.period.earliest.days(until: wider.period.latest) == 9)
        #expect(wider.ovulation?.center.days(until: wider.period.center) == 14)
        #expect(wider.ovulationBasis.contains("cannot reliably identify ovulation"))
    }

    @Test func unknownAndIncompatibleDurationsDoNotInventBleeding() throws {
        let unknown = forecast([Period(start: start)], profile: profile(bleeding: nil))
        #expect(unknown.cycles.allSatisfy { $0.bleeding == nil && $0.fertileWindow != nil })
        let equal = forecast([Period(start: start)], profile: profile(cycle: 28, bleeding: 28))
        #expect(equal.cycles.allSatisfy { $0.bleeding == nil })
        let short = forecast([Period(start: start)], profile: profile(cycle: 10))
        #expect(short.cycles.count == 3)
        #expect(short.cycles.allSatisfy { $0.fertileWindow == nil && $0.ovulation == nil && $0.bleeding != nil })
    }

    @Test func cumulativeUncertaintyDoesNotNarrowOnLaterProjections() throws {
        let result = forecast([Period(start: start)], profile: profile())
        for (index, cycle) in result.cycles.enumerated() {
            #expect(cycle.period.earliest.days(until: cycle.period.center) == 3 * (index + 1))
            #expect(cycle.period.center.days(until: cycle.period.latest) == 3 * (index + 1))
            #expect(cycle.fertileEnvelope!.start <= cycle.fertileWindow!.start)
            #expect(cycle.fertileEnvelope!.end >= cycle.fertileWindow!.end)
            #expect(cycle.bleedingEnvelope!.start <= cycle.bleeding!.start)
            #expect(cycle.bleedingEnvelope!.end >= cycle.bleeding!.end)
        }
    }

    @Test func bleedingAcrossLeapDayIsInclusiveAndCivilDateBased() throws {
        let day = try LocalDay(key: 20240131)
        let result = forecast([Period(start: day)], profile: profile())
        #expect(try result.cycles[0].bleeding == ForecastInterval(start: LocalDay(key: 20240228), end: LocalDay(key: 20240303)))
    }
}

@MainActor struct AdaptiveForecastSessionTests {
    @Test func endDateEditsAndDeletionRelearnDurationWithoutInventingRecords() throws {
        let day = try LocalDay(key: 20261002)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { day.formattingDate }, timeZone: { .gmt })
        session.load()
        let first = Period(start: try day.adding(days: -56), end: try day.adding(days: -51))
        let second = Period(start: try day.adding(days: -28))
        #expect(session.save([first, second]) == nil)
        #expect(session.cycleForecast.cycles.first?.bleedingDuration?.days == 6)
        var edited = second
        edited.end = try second.start.adding(days: 3)
        #expect(session.update(edited) == nil)
        #expect(session.cycleForecast.cycles.first?.bleedingDuration?.days == 5)
        #expect(session.cycleForecast.cycles.first?.bleedingDuration?.measuredCount == 2)
        edited.end = nil
        #expect(session.update(edited) == nil)
        #expect(session.cycleForecast.cycles.first?.bleedingDuration?.days == 6)
        #expect(session.snapshot.periods.count == 2 && session.snapshot.periods.last?.end == nil)
        #expect(session.delete(id: first.id) == nil)
        #expect(session.cycleForecast.cycles.isEmpty) // no measured cycle or entered length remains
    }
}
