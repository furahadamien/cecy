import Foundation
import Testing
@testable import cecy

nonisolated struct DeviceFeedbackRoundFourTests {
    private let today = try! LocalDay(key: 20260929)
    private func profile(_ days: Int = 28) -> LocalProfile {
        var value = LocalProfile()
        value.typicalCycleDays = days
        value.typicalPeriodDays = 5
        value.preferredName = "PRIVATE NAME"
        return value
    }

    @Test func sameEngineUsesOneThroughFourStartsWithoutThreshold() throws {
        let dates = try [20260607, 20260705, 20260804, 20260902].map { try LocalDay(key: $0) }
        for count in 1...4 {
            let periods = dates.prefix(count).map { Period(start: $0) }
            let result = CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine(), profile: profile())
            let estimate = try #require(result.estimate)
            let direct = try EvidencePredictionEngine().predict(intervals: result.intervals, latestStart: dates[count - 1], profile: profile())
            #expect(result.prediction == direct)
            #expect(estimate.sourceLengths.count == count - 1)
            #expect(estimate.confidence == .low)
            #expect(estimate.basis == (count == 1 ? .usualCycle : .recordedHistory))
            #expect(periods.allSatisfy { $0.end == nil })
        }
    }

    @Test func firstMeasuredIntervalIsUsedRatherThanUsualLength() throws {
        let periods = try [20260801, 20260902].map { Period(start: try LocalDay(key: $0)) }
        let result = CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine(), profile: profile(60))
        let estimate = try #require(result.estimate)
        #expect(estimate.sourceLengths == [32])
        #expect(try estimate.center == LocalDay(key: 20261004))
        #expect(estimate.reportedCycleDays == nil && estimate.confidence == .low)
        let varying = try [20260601, 20260701, 20260901].map { Period(start: try LocalDay(key: $0)) }
        #expect(CycleCalculator.overview(periods: varying, today: today, profile: profile()).prediction == .wideVariation)
    }

    @Test func sparsePredictionStillRejectsInvalidInputAndDoesNotAdvance() throws {
        let start = try LocalDay(key: 20260101)
        let result = CycleCalculator.overview(periods: [Period(start: start)], today: today, profile: profile())
        #expect(try result.estimate?.center == LocalDay(key: 20260129))
        #expect(result.intervals.isEmpty)
        #expect(CycleCalculator.overview(periods: [Period(start: start)], today: today, profile: profile(0)).prediction == .unavailable(.invalidData))
        let invalid = CycleInterval(id: UUID(), start: start, nextStart: start)
        #expect(throws: TrackingError.invalidData) {
            try EvidencePredictionEngine().predict(intervals: [invalid], latestStart: start, profile: profile())
        }
    }

    @Test func indexedMarkersMatchRecordedActivitiesAndDoNotInventEnds() throws {
        let start = try LocalDay(key: 20260902)
        let snapshot = TrackerSnapshot(periods: [Period(start: start), Period(start: try LocalDay(key: 20260920), end: try LocalDay(key: 20260923))],
            symptoms: [SymptomEntry(day: start, kind: .headache), SymptomEntry(day: today, kind: .cramps)])
        let index = DayActivityIndex(snapshot: snapshot)
        for offset in -40...40 {
            let day = try today.adding(days: offset)
            #expect(index.markers(on: day) == DayActivityMarker.recorded(on: day, in: snapshot))
        }
        #expect(try index.markers(on: start.adding(days: 1)).isEmpty)
        #expect(index.markers(on: start).map(\.id) == ["period", "symptom.headache"])
    }

    @Test func oneStartSupportsDescriptiveAIWithoutFabricatedMetricsOrPrivateData() throws {
        let start = try LocalDay(key: 20260902)
        let snapshot = TrackerSnapshot(periods: [Period(start: start, notes: "PRIVATE NOTE")],
            symptoms: [SymptomEntry(day: today, kind: .cramps, value: 2, notes: "PRIVATE SYMPTOM")], profile: profile())
        guard case .question(let context) = try AIContextBuilder.recordInsights(snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(context.facts.cyclesAnalyzed == 0)
        #expect(context.facts.averageCycleLength == nil && context.facts.populationStandardDeviationDays == nil)
        #expect(context.facts.recordedStarts == 1)
        #expect(context.facts.symptoms?.first?.symptom == .cramps && context.facts.symptoms?.first?.recordedDays == 1)
        #expect(context.facts.confirmedBleedingDurations == [] && context.facts.unknownBleedingEnds == 1)
        let json = String(decoding: try JSONEncoder().encode(context), as: UTF8.self)
        for secret in ["PRIVATE", "20260902", "2026-09-02", snapshot.periods[0].id.uuidString, "typicalCycleDays"] {
            #expect(!json.contains(secret))
        }
    }

    @Test func oneStartCycleQuestionGeneratesButDoesNotClaimLength() throws {
        let snapshot = TrackerSnapshot(periods: [Period(start: try LocalDay(key: 20260902))])
        guard case .question(let context) = try AIContextBuilder.question(CycleQuestionScope.cycleLengths.selectedSymptomsQuestion,
            scope: .cycleLengths, kinds: [], snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(context.facts.cyclesAnalyzed == 0 && context.facts.averageCycleLength == nil)
        #expect(context.facts.caveat.contains("unknown"))
    }

    @Test func singleSymptomIsUsableButEmptyAndInvalidRecordsAreNot() throws {
        let snapshot = TrackerSnapshot(symptoms: [SymptomEntry(day: today, kind: .energyLevel, value: 3)])
        guard case .question(let context) = try AIContextBuilder.recordInsights(snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(context.facts.caveat.contains("ratings"))
        #expect(context.facts.energyRatingDays == ["high": 1])
        #expect(context.facts.symptoms?.isEmpty == true)
        try context.validateForAI()
        #expect(throws: AIContextError.self) { try AIContextBuilder.recordInsights(snapshot: TrackerSnapshot(), today: today) }
        #expect(throws: TrackingError.futureDate) {
            try AIContextBuilder.recordInsights(snapshot: TrackerSnapshot(periods: [Period(start: today.adding(days: 1))]), today: today)
        }
    }

    @Test func chartsKeepSingleRecordedPointsAndExcludeFutureStarts() throws {
        let start = Period(start: try LocalDay(key: 20260902))
        let future = Period(start: try today.adding(days: 1))
        #expect(InsightChartData.recordedStarts([future, start], today: today) == [start])
        #expect(InsightChartData.recentIntervals([], today: today).isEmpty)
        let interval = CycleInterval(id: start.id, start: try LocalDay(key: 20260804), nextStart: start.start)
        #expect(InsightChartData.recentIntervals([interval], today: today) == [interval])
        let counts = InsightChartData.observationCounts([SymptomEntry(day: today, kind: .cramps)], today: today)
        #expect(counts.count == 1 && counts[0].days == 1)
    }
}

@MainActor struct CalendarIndexStateTests {
    @Test func indexRefreshesOnSaveEditAndDelete() throws {
        let today = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        let period = Period(start: try today.adding(days: -4))
        #expect(session.save([period]) == nil)
        #expect(session.activityIndex.markers(on: period.start).first?.id == "period")
        #expect(session.activityIndex.markers(on: today).isEmpty)
        var edited = period; edited.end = today
        #expect(session.update(edited) == nil)
        #expect(session.activityIndex.markers(on: today).first?.id == "period")
        #expect(session.delete(id: period.id) == nil)
        #expect(session.activityIndex.markers(on: today).isEmpty)
    }
}
