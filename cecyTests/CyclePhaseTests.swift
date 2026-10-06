import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct CyclePhaseTests {
    private func fixture(length: Int, offset: Int = 0, confirmed: Bool = false,
                         context: Set<CycleContext> = []) throws -> CyclePhaseTimeline? {
        let start = try LocalDay(key: 20260201)
        let today = try start.adding(days: offset)
        var profile = LocalProfile()
        profile.typicalCycleDays = length
        profile.typicalPeriodDays = 5
        profile.cycleContext = context
        let periods = [Period(start: start, end: confirmed ? try start.adding(days: 4) : nil)]
        let overview = CycleCalculator.overview(periods: periods, today: today, profile: profile)
        let forecast = CycleForecast.calculate(overview: overview, profile: profile, periods: periods, asOf: today)
        return CyclePhaseTimeline.make(overview: overview, forecast: forecast, periods: periods, profile: profile, today: today)
    }

    @Test(arguments: [21, 24, 28, 32, 40, 60, 120])
    func rangesCoverActualEstimatedLengthWithoutOverlaps(length: Int) throws {
        let timeline = try #require(try fixture(length: length))
        #expect(timeline.length == length)
        #expect(timeline.segments.flatMap { Array($0.days) } == Array(1...length))
        #expect(timeline.segments.first?.count == 5)
        #expect(timeline.segments.first(where: { $0.phase == .ovulation })?.count == 1)
        #expect(timeline.segments.first(where: { $0.phase == .ovulation })?.days.lowerBound == length - 14 + 1)
        #expect(timeline.fertileDays.map { $0.upperBound - $0.lowerBound + 1 } == 6)
        #expect(timeline.recordedBleeding == 1...1)
    }

    @Test(arguments: [21, 28, 35]) func detectsEveryBoundaryAndUsesInclusiveCivilDays(length: Int) throws {
        let model = try #require(try fixture(length: length))
        for segment in model.segments {
            for day in Set([segment.days.lowerBound, segment.days.upperBound]) {
                let current = try #require(try fixture(length: length, offset: day - 1))
                #expect(current.currentPhase == segment.phase)
                #expect(current.markerDay == day)
                let range = try #require(current.dateRange(for: segment.phase))
                #expect(range.start.days(until: range.end) + 1 == segment.count)
            }
        }
    }

    @Test func overdueCycleDoesNotWrapOrInventAnotherPeriod() throws {
        for offset in [28, 31, 365] {
            let model = try #require(try fixture(length: 28, offset: offset))
            #expect(model.cycleDay == offset + 1)
            #expect(model.markerDay == nil && model.currentPhase == nil)
            #expect(model.start == (try LocalDay(key: 20260201)))
        }
    }

    @Test func recordedBleedingAndEstimatedBleedingRemainDistinct() throws {
        let unknown = try #require(try fixture(length: 28, offset: 3))
        #expect(unknown.currentPhase == .menstrual && !unknown.currentIsRecorded && unknown.bleedingIsEstimated)
        let known = try #require(try fixture(length: 28, offset: 4, confirmed: true))
        #expect(known.currentIsRecorded && !known.bleedingIsEstimated && known.recordedBleeding == 1...5)
    }

    @Test func cycleContextSuppressesUnconfirmedCurrentPhase() throws {
        let model = try #require(try fixture(length: 28, offset: 10, context: [.hormonalBirthControl]))
        #expect(!model.warnings.isEmpty && model.currentPhase == nil)
        #expect(model.markerDay == 11)
    }

    @Test func missingInputsAndConflictingBoundariesNeverFabricatePhases() throws {
        let start = try LocalDay(key: 20260201)
        let periods = [Period(start: start)]
        let empty = CycleCalculator.overview(periods: periods, today: start)
        #expect(CyclePhaseTimeline.make(overview: empty, forecast: CycleForecast(), periods: periods, profile: nil, today: start) == nil)
        var profile = LocalProfile()
        profile.typicalCycleDays = 21
        profile.typicalPeriodDays = 10
        let overview = CycleCalculator.overview(periods: periods, today: start, profile: profile)
        let forecast = CycleForecast.calculate(overview: overview, profile: profile, periods: periods)
        #expect(CyclePhaseTimeline.make(overview: overview, forecast: forecast, periods: periods, profile: profile, today: start) == nil)
    }

    @Test func personalPatternsReuseRecordedStartEvidenceNotOvulationClaims() throws {
        let starts = try [20260301, 20260329, 20260426, 20260524].map { try LocalDay(key: $0) }
        let periods = starts.map { Period(start: $0) }
        let logs = try starts.flatMap { start in
            [SymptomEntry(day: start, kind: .cramps), SymptomEntry(day: try start.adding(days: -1), kind: .headache)]
        }
        let insights = try CycleInsightEngine.generate(periods: periods, symptoms: logs, today: LocalDay(key: 20260601))
        #expect(CyclePhaseTimeline.patterns(for: .menstrual, insights: insights).contains { $0.id.hasSuffix("cramps") })
        #expect(CyclePhaseTimeline.patterns(for: .luteal, insights: insights).contains { $0.id.hasSuffix("headache") })
        #expect(CyclePhaseTimeline.patterns(for: .ovulation, insights: insights).isEmpty)
        #expect(CyclePhaseTimeline.patterns(for: .follicular, insights: insights).isEmpty)
    }
}

@MainActor struct ExpandedSymptomTests {
    @Test func categoriesAreCompleteAndExistingIdentifiersRemainStable() {
        let original = ["cramps", "headache", "bloating", "fatigue", "moodChanges", "acne", "backPain", "nausea",
                        "breastTenderness", "sleepQuality", "energyLevel", "cravings", "digestiveChanges"]
        #expect(original.allSatisfy { SymptomKind(rawValue: $0) != nil })
        #expect(SymptomKind.allCases.count == 39)
        let grouped = SymptomCategory.allCases.flatMap(\.kinds)
        #expect(Set(grouped) == Set(SymptomKind.allCases) && grouped.count == SymptomKind.allCases.count)
        #expect(SymptomKind.libido.ratingLabels == ["Low", "Typical", "High"])
        #expect(!SymptomKind.libido.qualifiesForTiming(value: 3))
    }

    @Test func expandedSymptomsRoundTripOnDiskWithoutSchemaMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("symptoms.store")
        let today = try LocalDay(key: 20261006)
        let entries = SymptomKind.allCases.map { SymptomEntry(day: today, kind: $0, value: 2, notes: "Private synthetic note") }
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            _ = try repository.addSymptoms(entries, today: today, now: Date())
        }
        let loaded = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(Set(loaded.symptoms.map(\.kind)) == Set(SymptomKind.allCases))
        #expect(loaded.symptoms.allSatisfy { $0.value == 2 && $0.notes == "Private synthetic note" })
    }

    @Test func expandedTypesHaveBoundedV2AggregateContexts() throws {
        let today = try LocalDay(key: 20261006)
        let snapshot = TrackerSnapshot(periods: [Period(start: today)], symptoms: [
            SymptomEntry(day: today, kind: .vaginalDryness), SymptomEntry(day: today, kind: .libido),
            SymptomEntry(day: today, kind: .cramps)])
        guard case .question(let context) = try AIContextBuilder.recordInsights(snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(Set(context.facts.symptoms?.map(\.symptom) ?? []) == [.cramps, .vaginalDryness, .libido])
        try context.validateForAI()
        guard case .question(let question) = try AIContextBuilder.question(CycleQuestionScope.symptomFrequency.suggestedQuestion(kind: .vaginalDryness),
            scope: .symptomFrequency, kind: .vaginalDryness, snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(question.facts.symptom == .vaginalDryness && question.facts.recordedDays == 1)
    }
}
