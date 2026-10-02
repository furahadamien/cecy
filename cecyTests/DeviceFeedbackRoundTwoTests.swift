import Foundation
import Testing
@testable import cecy

nonisolated struct InsightChartDataTests {
    @Test func countsUniqueLoggedDaysWithinInclusiveNinetyDayWindow() throws {
        let today = try LocalDay(key: 20260929)
        let entries = [
            SymptomEntry(day: today, kind: .cramps), SymptomEntry(day: today, kind: .cramps),
            SymptomEntry(day: try today.adding(days: -89), kind: .cramps),
            SymptomEntry(day: try today.adding(days: -90), kind: .cramps),
            SymptomEntry(day: try today.adding(days: 1), kind: .cramps),
            SymptomEntry(day: today, kind: .sleepQuality, value: 3)
        ]
        let counts = InsightChartData.observationCounts(entries, today: today)
        #expect(counts == [.init(kind: .cramps, days: 2), .init(kind: .sleepQuality, days: 1)])
        #expect(InsightChartData.observationCounts([], today: today).isEmpty)
    }

    @Test func intervalsAreChronologicalBoundedAndExcludeFuture() throws {
        let start = try LocalDay(key: 20250101)
        let intervals = try (0..<15).map { index in
            try CycleInterval(id: UUID(), start: start.adding(days: index * 28), nextStart: start.adding(days: (index + 1) * 28))
        }
        let today = try start.adding(days: 14 * 28)
        let result = InsightChartData.recentIntervals(intervals.reversed(), today: today)
        #expect(result == Array(intervals[2..<14]))
        #expect(InsightChartData.recentIntervals([], today: today).isEmpty)
    }

    @Test func tiedCountsAreStableAndDoNotInferUnloggedSymptoms() throws {
        let today = try LocalDay(key: 20260929)
        let entries = [SymptomEntry(day: today, kind: .fatigue), SymptomEntry(day: today, kind: .cramps)]
        #expect(InsightChartData.observationCounts(entries, today: today).map(\.kind) == [.cramps, .fatigue])
    }

    @Test func measurementFormattingDoesNotChangeCanonicalPrecision() {
        let value = 65.123456
        let displayed = MeasurementPickerKind.weight.formatted(value, system: .metric)
        #expect(displayed == "\(65.1.formatted(.number.precision(.fractionLength(0...1)))) kg")
        #expect(value == 65.123456)
    }
}

@MainActor struct WellnessPresentationTests {
    private var context: WellnessRecommendationContext {
        .init(cycleDay: 10, symptoms: [], activityLevel: "beginner", preferredExercises: [],
              dietaryPreference: "none", foodAllergies: [], userGoals: [])
    }
    private func waitFor(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Synthetic request did not settle within the bounded wait")
    }

    @Test func onlyExplicitMatchingSuccessfulRequestSurvivesNavigation() async throws {
        let service = WellnessServiceStub()
        let state = AIRequestCoordinator(service: service)
        let request = AIRequest.wellness(context)
        #expect(state.wellness(for: request) == nil)
        #expect(await service.calls == 0)
        state.begin(request) { true }
        try await waitFor { await service.calls == 1 }
        await service.complete()
        try await waitFor { !state.isLoading }
        #expect(state.wellness(for: request)?.movementSuggestions == ["Synthetic walk"])
        state.cancel() // Navigation clears the request/output, not the matching Today presentation.
        #expect(state.output == nil)
        #expect(state.wellness(for: request) != nil)
        let changed = WellnessRecommendationContext(cycleDay: 11, symptoms: [], activityLevel: "beginner",
            preferredExercises: [], dietaryPreference: "none", foodAllergies: [], userGoals: [])
        #expect(state.wellness(for: .wellness(changed)) == nil)
        #expect(state.wellness(for: .symptoms(.init(text: "Synthetic"))) == nil)
        state.invalidate() // Shared path for background, lock, reset, consent and record changes.
        #expect(state.wellness(for: request) == nil)
        #expect(state.revision == 1)
    }

    @Test func refreshFailureAndLateResponseDoNotRestoreCachedSuggestions() async throws {
        let service = WellnessServiceStub()
        let state = AIRequestCoordinator(service: service)
        let request = AIRequest.wellness(context)
        state.begin(request) { true }
        try await waitFor { await service.calls == 1 }
        await service.complete()
        try await waitFor { !state.isLoading }
        #expect(state.wellness(for: request) != nil)
        state.begin(request) { true }
        #expect(state.wellness(for: request) == nil)
        try await waitFor { await service.calls == 2 }
        await service.complete(fail: true)
        try await waitFor { !state.isLoading }
        #expect(state.wellness(for: request) == nil && state.message != nil)
        state.begin(request) { true }
        try await waitFor { await service.calls == 3 }
        state.invalidate()
        await service.complete()
        for _ in 0..<10 { await Task.yield() }
        #expect(state.output == nil && state.wellness(for: request) == nil)
    }

    @Test func lostAccessPreventsPublishingWellness() async throws {
        let service = WellnessServiceStub()
        let state = AIRequestCoordinator(service: service)
        var access = true
        let request = AIRequest.wellness(context)
        state.begin(request) { access }
        try await waitFor { await service.calls == 1 }
        access = false
        await service.complete()
        try await waitFor { !state.isLoading }
        #expect(state.output == nil && state.wellness(for: request) == nil)
    }
}

private actor WellnessServiceStub: AIService {
    private(set) var calls = 0
    private var pending: CheckedContinuation<WellnessRecommendation, Error>?
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation {
        calls += 1
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func complete(fail: Bool = false) {
        let continuation = pending
        pending = nil
        if fail { continuation?.resume(throwing: AIServiceError.unavailable) }
        else {
            continuation?.resume(returning: WellnessRecommendation(movementSuggestions: ["Synthetic walk"], foodSuggestions: [],
                hydrationSuggestion: "Synthetic hydration", recoverySuggestions: [], explanation: "Synthetic explanation", safetyMessage: nil))
        }
    }
    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult { throw AIServiceError.unavailable }
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult { throw AIServiceError.unavailable }
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult { throw AIServiceError.unavailable }
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult { throw AIServiceError.unavailable }
}
