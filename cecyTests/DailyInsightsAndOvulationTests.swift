import Foundation
import Testing
@testable import cecy

nonisolated struct OvulationAndPreparedAnswerTests {
    let today = try! LocalDay(key: 20261002)

    @Test func ovulationUsesExistingPredictionWithoutCreatingRecordsOrRollingForward() throws {
        var profile = LocalProfile()
        profile.typicalCycleDays = 28
        let start = try LocalDay(key: 20260902)
        let periods = [Period(start: start)]
        let overview = CycleCalculator.overview(periods: periods, today: today, profile: profile)
        #expect(try overview.possibleOvulation == LocalDay(key: 20260916))
        #expect(try overview.estimate?.center == LocalDay(key: 20260930))
        #expect(overview.intervals.isEmpty && periods[0].end == nil)
        let later = CycleCalculator.overview(periods: periods, today: try today.adding(days: 50), profile: profile)
        #expect(later.possibleOvulation == overview.possibleOvulation)
    }

    @Test func measuredCyclesCrossMonthAndLeapDay() throws {
        let periods = try [20240118, 20240215].map { Period(start: try LocalDay(key: $0)) }
        let overview = CycleCalculator.overview(periods: periods, today: try LocalDay(key: 20240301))
        #expect(try overview.possibleOvulation == LocalDay(key: 20240229))
        #expect(overview.estimate?.sourceLengths == [28])
    }

    @Test func unavailableAndImpossibleOvulationDatesAreWithheld() throws {
        #expect(CycleCalculator.overview(periods: [], today: today).possibleOvulation == nil)
        let periods = try [20260601, 20260701, 20260901].map { Period(start: try LocalDay(key: $0)) }
        #expect(CycleCalculator.overview(periods: periods, today: today).possibleOvulation == nil)
        var profile = LocalProfile(); profile.typicalCycleDays = 10
        #expect(CycleCalculator.overview(periods: [Period(start: today)], today: today, profile: profile).possibleOvulation == nil)
    }

    @Test func preparedAnswersWorkWithoutHistoryAndNeverInventMissingEnds() {
        let empty = PreparedRecordAnswers.build(snapshot: TrackerSnapshot(), today: today)
        #expect(empty.count == 3 && empty[0].answer.contains("0 recorded"))
        #expect(empty[1].answer.contains("no completed"))
        #expect(empty[2].answer.contains("does not mean symptoms were absent"))
        let one = PreparedRecordAnswers.build(snapshot: TrackerSnapshot(periods: [Period(start: today, notes: "SECRET")]), today: today)
        #expect(one[0].answer.contains("1 recorded") && one[0].answer.contains("0 have a confirmed end"))
        #expect(!one.map(\.answer).joined().contains("SECRET"))
    }

    @Test func preparedAnswersUseOneDecimalAndBoundedLoggedDays() throws {
        let starts = try [0, 28, 57].map { Period(start: try today.adding(days: $0 - 60)) }
        let snapshot = TrackerSnapshot(periods: starts, symptoms: [
            SymptomEntry(day: today, kind: .cramps, notes: "PRIVATE"),
            SymptomEntry(day: try today.adding(days: -89), kind: .cramps),
            SymptomEntry(day: try today.adding(days: -90), kind: .headache),
            SymptomEntry(day: try today.adding(days: 1), kind: .headache)
        ])
        let answers = PreparedRecordAnswers.build(snapshot: snapshot, today: today)
        #expect(answers[1].answer.contains("28.5"))
        #expect(answers[2].answer.contains("Cramps: 2"))
        #expect(!answers[2].answer.contains("Headache") && !answers[2].answer.contains("PRIVATE"))
    }

    @Test func legacyPreferencesDoNotEnableAutomaticRequests() throws {
        let data = Data(#"{"version":1,"lockEnabled":false,"dailyReminder":false,"windowReminder":false,"reminderHour":20,"reminderMinute":0}"#.utf8)
        let preferences = try JSONDecoder().decode(PrivacyPreferences.self, from: data)
        #expect(preferences.dailyInsightsEnabled == nil && preferences.dailyInsightAttemptDay == nil)
        try preferences.validate()
    }
}

@MainActor private final class DailyTestPreferences: PrivacyPreferenceStoring {
    var value = PrivacyPreferences()
    var fail = false
    func load() -> PrivacyPreferences { value }
    func save(_ value: PrivacyPreferences) throws {
        if fail { throw TrackingError.invalidData }
        self.value = value
    }
}

private actor DailyTestService: AIService {
    private(set) var calls = 0
    let delayed: Bool
    let fails: Bool
    var continuation: CheckedContinuation<CycleQuestionResult, Never>?
    init(delayed: Bool = false, fails: Bool = false) { self.delayed = delayed; self.fails = fails }
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult {
        calls += 1
        if fails { throw AIServiceError.unavailable }
        if delayed { return await withCheckedContinuation { continuation = $0 } }
        return CycleQuestionResult(answer: "Synthetic explanation", supportingFacts: ["One recorded start"], safetyMessage: nil)
    }
    func complete() {
        continuation?.resume(returning: CycleQuestionResult(answer: "Late synthetic answer", supportingFacts: [], safetyMessage: nil))
        continuation = nil
    }
    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult { throw AIServiceError.unavailable }
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult { throw AIServiceError.unavailable }
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation { throw AIServiceError.unavailable }
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult { throw AIServiceError.unavailable }
}

@MainActor @Suite(.serialized) struct DailyInsightsLifecycleTests {
    let today = try! LocalDay(key: 20261002)

    private func privacy(_ storage: any PrivacyPreferenceStoring) -> TrackerPrivacy {
        let privacy = TrackerPrivacy(storage: storage, authentication: FixedDeviceAuthentication(),
            exports: ProtectedExportFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            delivery: MemoryReminderDelivery())
        privacy.start()
        return privacy
    }

    private func repository() throws -> SwiftDataPeriodRepository {
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add([Period(start: today.adding(days: -20))], completingOnboarding: true,
                               today: today, now: today.formattingDate)
        return repository
    }

    private func waitFor(_ predicate: () async -> Bool) async {
        for _ in 0..<100 {
            if await predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test func consentIsSeparateAndLimitPersistsAcrossReopening() throws {
        let storage = DailyTestPreferences(), value = privacy(DailyTestPreferences())
        #expect(value.setDailyInsightsEnabled(true) != nil)
        let first = privacy(storage)
        #expect(first.setAIEnabled(true) == nil && !first.dailyInsightsEnabled)
        #expect(first.setDailyInsightsEnabled(true) == nil)
        #expect(first.reserveDailyInsightAttempt(on: today))
        #expect(!first.reserveDailyInsightAttempt(on: today))
        let reopened = privacy(storage)
        #expect(reopened.dailyInsightsEnabled && !reopened.reserveDailyInsightAttempt(on: today))
        #expect(try reopened.reserveDailyInsightAttempt(on: today.adding(days: 1)))
        try reopened.prepareForReset()
        #expect(!reopened.dailyInsightsEnabled && storage.value.dailyInsightAttemptDay == nil)
    }

    @Test func failedSavesNeverEnableOrSpendAndRevocationFailsClosed() {
        let storage = DailyTestPreferences(), p = privacy(DailyTestPreferences())
        #expect(!p.reserveDailyInsightAttempt(on: today))
        let value = privacy(storage)
        #expect(value.setAIEnabled(true) == nil)
        storage.fail = true
        #expect(value.setDailyInsightsEnabled(true) != nil && !value.dailyInsightsEnabled)
        storage.fail = false
        #expect(value.setDailyInsightsEnabled(true) == nil)
        storage.fail = true
        #expect(!value.reserveDailyInsightAttempt(on: today))
        #expect(value.setDailyInsightsEnabled(false) != nil && !value.dailyInsightsEnabled)
    }

    @Test func dailySummaryRunsOnceAndSurvivesUnchangedRefresh() async throws {
        let store = DailyTestPreferences(), service = DailyTestService(), repo = try repository()
        let p = privacy(store)
        let session = TrackerSession(repository: { repo }, clock: { self.today.formattingDate }, timeZone: { .gmt }, privacy: p, aiService: service)
        session.load()
        session.preloadDailyInsights()
        #expect(await service.calls == 0)
        #expect(session.setAIEnabled(true) == nil)
        session.preloadDailyInsights()
        #expect(await service.calls == 0)
        #expect(p.setDailyInsightsEnabled(true) == nil)
        session.preloadDailyInsights(); session.preloadDailyInsights()
        await waitFor { !session.dailyAI.isLoading }
        #expect(await service.calls == 1)
        #expect(session.dailyInsightOutput != nil)
        session.refresh(); session.preloadDailyInsights()
        #expect(await service.calls == 1 && session.dailyInsightOutput != nil)
        let reopened = TrackerSession(repository: { repo }, clock: { self.today.formattingDate }, timeZone: { .gmt }, privacy: privacy(store), aiService: service)
        reopened.load(); reopened.preloadDailyInsights()
        await Task.yield()
        #expect(await service.calls == 1)
        #expect(reopened.dailyInsightOutput == nil) // generated text is intentionally not stored
    }

    @Test func changedRecordsCancelLateDailyAnswerWithoutRetrying() async throws {
        let service = DailyTestService(delayed: true), repo = try repository()
        let session = TrackerSession(repository: { repo }, clock: { self.today.formattingDate }, timeZone: { .gmt }, aiService: service)
        session.load()
        #expect(session.setAIEnabled(true) == nil)
        #expect(session.privacy.setDailyInsightsEnabled(true) == nil)
        session.preloadDailyInsights()
        await waitFor { await service.calls == 1 }
        #expect(session.saveSymptom(SymptomEntry(day: today, kind: .headache)) == nil)
        await service.complete()
        await waitFor { !session.dailyAI.isLoading }
        session.preloadDailyInsights()
        #expect(await service.calls == 1 && session.dailyInsightOutput == nil)
    }

    @Test func cancellationConsumesOnlyTodayAndNextDayCanPrepare() async throws {
        let service = DailyTestService(delayed: true), repo = try repository()
        let clock = DailyTestClock(day: today)
        let session = TrackerSession(repository: { repo }, clock: { clock.day.formattingDate }, timeZone: { .gmt }, aiService: service)
        session.load()
        #expect(session.setAIEnabled(true) == nil)
        #expect(session.privacy.setDailyInsightsEnabled(true) == nil)
        session.preloadDailyInsights()
        await waitFor { await service.calls == 1 }
        session.dailyAI.cancel() // Same cancellation used when leaving the foreground.
        await service.complete()
        session.refresh(); session.preloadDailyInsights()
        #expect(await service.calls == 1 && session.dailyInsightOutput == nil)
        clock.day = try today.adding(days: 1)
        session.refresh(); session.preloadDailyInsights()
        await waitFor { await service.calls == 2 }
        await service.complete()
        await waitFor { !session.dailyAI.isLoading }
        #expect(await service.calls == 2 && session.dailyInsightOutput != nil)
    }

    @Test func failedRequestDoesNotRetryAutomatically() async throws {
        let service = DailyTestService(fails: true), repo = try repository()
        let session = TrackerSession(repository: { repo }, clock: { self.today.formattingDate }, timeZone: { .gmt }, aiService: service)
        session.load()
        #expect(session.setAIEnabled(true) == nil)
        #expect(session.privacy.setDailyInsightsEnabled(true) == nil)
        session.preloadDailyInsights()
        await waitFor { !session.dailyAI.isLoading }
        #expect(session.dailyAI.message != nil && session.dailyInsightOutput == nil)
        session.preloadDailyInsights()
        #expect(await service.calls == 1)
    }

    @Test func lostConsentRejectsLateResultsAndDoesNotTouchRecords() async throws {
        let service = DailyTestService(delayed: true), repo = try repository()
        let session = TrackerSession(repository: { repo }, clock: { self.today.formattingDate }, timeZone: { .gmt }, aiService: service)
        session.load()
        let original = session.snapshot
        #expect(session.setAIEnabled(true) == nil)
        #expect(session.privacy.setDailyInsightsEnabled(true) == nil)
        session.preloadDailyInsights()
        await waitFor { await service.calls == 1 }
        #expect(session.setAIEnabled(false) == nil)
        await service.complete()
        await Task.yield()
        #expect(session.dailyInsightOutput == nil && !session.dailyAI.isLoading)
        #expect(session.snapshot == original)
    }
}

@MainActor private final class DailyTestClock {
    var day: LocalDay
    init(day: LocalDay) { self.day = day }
}
