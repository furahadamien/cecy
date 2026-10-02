import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated private func aiDay(_ key: Int) throws -> LocalDay { try LocalDay(key: key) }
nonisolated private func aiSnapshot() throws -> TrackerSnapshot {
    var profile = LocalProfile()
    profile.preferredName = "PRIVATE NAME MUST NOT LEAVE"
    profile.birthDayKey = 19950512
    profile.typicalPeriodDays = 5
    profile.wellnessPreferences = WellnessPreferences(activityLevel: .moderatelyActive, preferredExercises: [.walking, .strengthTraining],
        dietaryPreference: .vegetarian, foodAllergyStatus: .listed, foodAllergies: ["Peanuts"], goals: [.manageSymptoms])
    let periods = try [20260410, 20260509, 20260607, 20260705, 20260804, 20260902].map { key in
        let start = try aiDay(key)
        return Period(start: start, end: try start.adding(days: 4), notes: "PRIVATE PERIOD NOTE")
    }
    let symptoms = try periods.map { period in
        SymptomEntry(day: try period.start.adding(days: -1), kind: .headache, value: 2, notes: "PRIVATE SYMPTOM NOTE")
    }
    return TrackerSnapshot(periods: periods, onboardingCompletedAt: Date(), symptoms: symptoms, profile: profile)
}

nonisolated struct AIModelTests {
    @Test func allTaxonomyMappingsAndSpecialRatings() throws {
        #expect(AISymptomType.allCases.count == SymptomKind.allCases.count)
        for type in AISymptomType.allCases {
            #expect(AISymptomType(kind: type.kind) == type)
            for severity in [AISeverity.mild, .moderate, .severe] {
                let item = AISymptom(type: type, severity: severity)
                let special = type == .sleepChange || type == .lowEnergy
                #expect(item.suggestedRating == (special ? nil : severity.rating))
                #expect(try JSONDecoder().decode(AISymptom.self, from: JSONEncoder().encode(item)) == item)
            }
        }
    }
    @Test func symptomSeverityIsExplicitNull() throws {
        let data = try JSONEncoder().encode(AISymptom(type: .digestiveChange, severity: nil))
        let string = String(decoding: data, as: UTF8.self)
        #expect(string.contains("\"severity\":null"))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(AISymptom.self, from: Data("{\"type\":\"cramps\"}".utf8)) }
    }
    @Test func duplicateUnknownAndOversizedSuggestionsFail() throws {
        let item = AISymptom(type: .cramps, severity: nil)
        #expect(throws: AIServiceError.invalidResponse) { try SymptomNormalizationResult(symptoms: [item, item]).validate() }
        #expect(throws: AIServiceError.invalidResponse) { try SymptomNormalizationResult(symptoms: Array(repeating: item, count: 21)).validate() }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SymptomNormalizationResult.self, from: Data("{\"symptoms\":[{\"type\":\"invented\",\"severity\":null}]}".utf8))
        }
        try SymptomNormalizationResult(symptoms: []).validate()
    }
    @Test func textAndListBoundsAreEnforced() throws {
        #expect(throws: AIContextError.self) { try AIContextBuilder.normalization(" \n ") }
        #expect(throws: AIContextError.self) { try AIContextBuilder.normalization(String(repeating: "a", count: 2_001)) }
        _ = try AIContextBuilder.normalization(String(repeating: "é", count: 2_000))
        let wellness = WellnessRecommendation(movementSuggestions: Array(repeating: "Walk", count: 7), foodSuggestions: [],
            hydrationSuggestion: "Water", recoverySuggestions: [], explanation: "Rest", safetyMessage: nil)
        #expect(throws: AIServiceError.invalidResponse) { try wellness.validate() }
        #expect(throws: AIServiceError.invalidResponse) { try CycleSummaryResult(summary: " ", highlights: [], safetyMessage: nil).validate() }
    }
    @Test func serverErrorsAreAllowlisted() {
        #expect(AIServiceError.server("INVALID_REQUEST") == .invalidRequest)
        #expect(AIServiceError.server("UNSUPPORTED_TASK") == .unsupportedTask)
        #expect(AIServiceError.server("AI_UNAVAILABLE") == .unavailable)
        #expect(AIServiceError.server("AI_RESPONSE_INVALID") == .invalidResponse)
        #expect(AIServiceError.server("INTERNAL_ERROR") == .serverError)
        #expect(AIServiceError.server("private backend details") == .serverError)
    }
    @Test func legacyConsentDecodesOffAndOldNoticeNeedsRenewal() throws {
        let old = Data("{\"version\":1,\"lockEnabled\":true,\"dailyReminder\":true,\"windowReminder\":false,\"reminderHour\":19,\"reminderMinute\":30}".utf8)
        let preferences = try JSONDecoder().decode(PrivacyPreferences.self, from: old)
        #expect(preferences.aiConsent == nil && preferences.lockEnabled && preferences.dailyReminder)
        #expect(!AIConsentRecord(noticeVersion: 0, grantedAt: Date()).isCurrent)
    }
}

nonisolated struct AIContextTests {
    @Test func wellnessUsesOnlyTodayAndExplicitAdverseRatings() throws {
        var snapshot = try aiSnapshot()
        let today = try aiDay(20260929)
        snapshot.symptoms += [SymptomEntry(day: today, kind: .sleepQuality, value: 3),
                              SymptomEntry(day: today, kind: .energyLevel, value: 1),
                              SymptomEntry(day: today, kind: .cramps, value: 3)]
        guard case .wellness(let value) = try AIContextBuilder.wellness(snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(value.symptoms == [AISymptom(type: .cramps, severity: .severe), AISymptom(type: .lowEnergy, severity: nil)])
        #expect(value.activityLevel == "moderately_active")
        #expect(value.preferredExercises == ["strength_training", "walking"])
        #expect(value.foodAllergies == ["Peanuts"])
        #expect(value.cycleDay == 28)
        let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        for forbidden in ["PRIVATE", "birth", "2026", "estimatedPhase", "notes", "id", "sexual"] { #expect(!text.contains(forbidden)) }
    }
    @Test func unansweredPreferencesNeverBecomeNoAllergies() throws {
        var snapshot = try aiSnapshot()
        snapshot.profile?.wellnessPreferences?.foodAllergyStatus = .notAnswered
        snapshot.profile?.wellnessPreferences?.foodAllergies = []
        #expect(throws: AIContextError.self) { try AIContextBuilder.wellness(snapshot: snapshot, today: aiDay(20260929)) }
        snapshot.profile?.wellnessPreferences?.foodAllergyStatus = .noneKnown
        snapshot.profile?.wellnessPreferences?.goals = []
        _ = try AIContextBuilder.wellness(snapshot: snapshot, today: aiDay(20260929))
        snapshot.profile?.wellnessPreferences?.preferredExercises = nil
        #expect(throws: AIContextError.self) { try AIContextBuilder.wellness(snapshot: snapshot, today: aiDay(20260929)) }
    }
    @Test func summaryUsesAvailableFactsWithoutInventingMissingMeasurements() throws {
        var snapshot = try aiSnapshot()
        let today = try aiDay(20260929)
        guard case .question(let open) = try AIContextBuilder.summary(snapshot: snapshot, start: aiDay(20260902), today: today) else { Issue.record(); return }
        #expect(open.facts.cyclesAnalyzed == 0 && open.facts.averageCycleLength == nil)
        #expect(open.facts.caveat.contains("Confirmed bleeding durations (days): 5"))
        guard case .summary(let value) = try AIContextBuilder.summary(snapshot: snapshot, start: aiDay(20260804), today: today) else { Issue.record(); return }
        #expect(value.cycleLength == 29 && value.periodLength == 5)
        #expect(value.commonSymptoms == [.headache])
        #expect(value.observations.contains { $0.contains("1 recorded days") })
        snapshot.periods[4].end = nil
        guard case .question(let partial) = try AIContextBuilder.summary(snapshot: snapshot, start: aiDay(20260804), today: today) else { Issue.record(); return }
        #expect(partial.facts.averageCycleLength == 29 && partial.facts.cyclesAnalyzed == 1)
        #expect(partial.facts.caveat.contains("bleeding duration unknown"))
    }
    @Test func summariesDoNotLeakLaterCyclesOrPrivateFields() throws {
        let snapshot = try aiSnapshot()
        guard case .summary(let value) = try AIContextBuilder.summary(snapshot: snapshot, start: aiDay(20260410), today: aiDay(20260929)) else { Issue.record(); return }
        #expect(value.averageCycleLength == 29)
        let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        for forbidden in ["PRIVATE", "birth", "2026", "notes", "Peanuts"] { #expect(!text.contains(forbidden)) }
    }
    @Test func questionsReuseTimingEvidenceIncludingZeroMatches() throws {
        let snapshot = try aiSnapshot()
        let today = try aiDay(20260929)
        guard case .question(let value) = try AIContextBuilder.question("Do I usually get headaches before my period?", scope: .beforePeriod,
            kind: .headache, snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(value.facts.cyclesAnalyzed == 6 && value.facts.matchingStarts == 6)
        #expect(value.facts.minimumRecordedOffsetDays == -1 && value.facts.maximumRecordedOffsetDays == -1)
        guard case .question(let zero) = try AIContextBuilder.question(CycleQuestionScope.beforePeriod.suggestedQuestion(kind: .cramps),
            scope: .beforePeriod, kind: .cramps, snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(zero.facts.cyclesAnalyzed == 6 && zero.facts.matchingStarts == 0)
        #expect(zero.facts.minimumRecordedOffsetDays == nil)
        #expect(zero.facts.caveat.contains("do not mean"))
        let insight = try #require(CycleInsightEngine.generate(periods: snapshot.periods, symptoms: snapshot.symptoms, today: today).first)
        #expect(insight.matchedStarts == value.facts.matchingStarts)
    }
    @Test func questionsRejectUnsupportedAndAmbiguousScopesLocally() throws {
        let snapshot = try aiSnapshot()
        for question in ["Am I pregnant?", "Why do I have headaches?", "Do I have PCOS?", "Upload all my records", "Do I log cramps before my period?"] {
            #expect(throws: AIContextError.self) {
                try AIContextBuilder.question(question, scope: .beforePeriod, kind: .headache, snapshot: snapshot, today: aiDay(20260929))
            }
        }
        #expect(!AIContextBuilder.supports("Did I log headaches before and after my period?", scope: .beforePeriod, kind: .headache))
        #expect(!AIContextBuilder.supports("Did I log headaches 90 days before my period?", scope: .beforePeriod, kind: .headache))
        #expect(!AIContextBuilder.supports("Did I log headaches before my last period?", scope: .beforePeriod, kind: .headache))
        #expect(!AIContextBuilder.supports("How long was my last cycle?", scope: .cycleLengths, kind: .headache))
        #expect(!AIContextBuilder.supports("How many days did I log headache in the last 900 days?", scope: .symptomFrequency, kind: .headache))
    }
    @Test func everyGuidedQuestionBuildsTypedBoundedFacts() throws {
        let snapshot = try aiSnapshot()
        for scope in CycleQuestionScope.allCases {
            guard case .question(let value) = try AIContextBuilder.question(scope.suggestedQuestion(kind: .headache), scope: scope,
                kind: .headache, snapshot: snapshot, today: aiDay(20260929)) else { Issue.record(); return }
            let data = try JSONEncoder().encode(value)
            let text = String(decoding: data, as: UTF8.self)
            #expect(data.count < 2_000)
            for forbidden in ["PRIVATE", "2026", "Peanuts", "birth", "sourceIDs"] { #expect(!text.contains(forbidden)) }
        }
    }
    @Test func explanationsContainAggregatesNotSourceRecords() throws {
        let snapshot = try aiSnapshot(), today = try aiDay(20260929)
        let insight = try #require(CycleInsightEngine.generate(periods: snapshot.periods, symptoms: snapshot.symptoms, today: today).first)
        guard case .insight(let value) = try AIContextBuilder.insight(insight) else { Issue.record(); return }
        #expect(value.facts.startsAnalyzed == 6 && value.facts.matchingStarts == 6)
        let text = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        for forbidden in ["sourceIDs", "PRIVATE", "2026", "logDays"] { #expect(!text.contains(forbidden)) }
    }
}

@MainActor private final class AIThrowingPreferences: PrivacyPreferenceStoring {
    var value = PrivacyPreferences()
    var fail = false
    func load() -> PrivacyPreferences { value }
    func save(_ value: PrivacyPreferences) throws { if fail { throw TrackingError.invalidData }; self.value = value }
}

@MainActor @Suite(.serialized) struct AIConsentAndLifecycleTests {
    private func privacy(_ storage: any PrivacyPreferenceStoring) -> TrackerPrivacy {
        let result = TrackerPrivacy(storage: storage, authentication: FixedDeviceAuthentication(),
            exports: ProtectedExportFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            delivery: MemoryReminderDelivery())
        result.start()
        return result
    }
    @Test func grantMustPersistAndRevocationFailsClosed() throws {
        let storage = AIThrowingPreferences(), p = privacy(AIThrowingPreferences())
        #expect(!p.aiEnabled)
        let value = privacy(storage)
        storage.fail = true
        #expect(value.setAIEnabled(true) != nil && !value.aiEnabled)
        storage.fail = false
        #expect(value.setAIEnabled(true) == nil && value.aiEnabled)
        storage.fail = true
        #expect(value.setAIEnabled(false) != nil && !value.aiEnabled)
        #expect(storage.value.aiConsent != nil)
        storage.fail = false
        #expect(value.setAIEnabled(false) == nil && storage.value.aiConsent == nil)
    }
    @Test func consentPersistsReopensAndResetRevokes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = FilePrivacyPreferences(url: root.appendingPathComponent("preferences.json"))
        let p = privacy(storage)
        #expect(p.setAIEnabled(true) == nil)
        let reopened = privacy(storage)
        #expect(reopened.aiEnabled)
        try reopened.prepareForReset()
        #expect(!privacy(storage).aiEnabled)
    }
    @Test func noConsentMakesZeroServiceCalls() async {
        let service = AIControlledService()
        let state = AIRequestCoordinator(service: service)
        state.begin(.symptoms(SymptomNormalizationContext(text: "Cramps"))) { false }
        await Task.yield()
        #expect(await service.calls == 0)
        #expect(!state.isLoading && state.output == nil)
    }
    @Test func cancellationAndLateResponsesNeverPublish() async {
        let service = AIControlledService()
        let state = AIRequestCoordinator(service: service)
        let request = AIRequest.symptoms(SymptomNormalizationContext(text: "Cramps"))
        state.begin(request) { true }
        for _ in 0..<100 { if await service.calls > 0 { break }; await Task.yield() }
        #expect(state.isLoading)
        state.begin(request) { true }
        #expect(await service.calls == 1)
        state.invalidate()
        await service.complete()
        for _ in 0..<10 { await Task.yield() }
        #expect(state.output == nil && !state.isLoading && state.revision == 1)
    }
    @Test func sessionResponseNeverWritesAndConfirmedBatchIsAtomic() async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let today = try aiDay(20260929), now = today.formattingDate
        _ = try repository.add([Period(start: aiDay(20260902))], completingOnboarding: true, today: today, now: now)
        let service = AIControlledService()
        let session = TrackerSession(repository: { repository }, clock: { now }, timeZone: { .gmt }, aiService: service)
        session.load()
        #expect(session.setAIEnabled(true) == nil)
        session.performAI(.symptoms(SymptomNormalizationContext(text: "Cramps")))
        for _ in 0..<100 { if await service.calls > 0 { break }; await Task.yield() }
        await service.complete()
        for _ in 0..<100 { if !session.ai.isLoading { break }; await Task.yield() }
        #expect(session.ai.output != nil && session.snapshot.symptoms.isEmpty)
        let entry = SymptomEntry(day: today, kind: .cramps, value: 2)
        #expect(session.addSymptoms([entry, SymptomEntry(day: today, kind: .cramps)]) != nil)
        #expect(try repository.load().symptoms.isEmpty)
        #expect(session.addSymptoms([entry]) == nil)
        #expect(try repository.load().symptoms.count == 1)
        #expect(session.ai.output == nil)
        #expect(session.setAIEnabled(false) == nil && !session.canUseAI)
    }

    @Test func watchdogEndsLoadingAndRejectsLateResult() async throws {
        let service = AIControlledService()
        let state = AIRequestCoordinator(service: service, timeout: .milliseconds(30))
        state.begin(.symptoms(SymptomNormalizationContext(text: "Synthetic"))) { true }
        for _ in 0..<100 { if await service.calls > 0 { break }; await Task.yield() }
        try await Task.sleep(for: .milliseconds(100))
        #expect(!state.isLoading && state.message != nil && state.output == nil)
        await service.complete()
        for _ in 0..<10 { await Task.yield() }
        #expect(state.output == nil)
    }

    @Test func lostAccessClearsEvenWithoutLifecycleNotification() async {
        let service = AIControlledService()
        let state = AIRequestCoordinator(service: service)
        let access = AITestAccess()
        state.begin(.symptoms(SymptomNormalizationContext(text: "Synthetic"))) { access.allowed }
        for _ in 0..<100 { if await service.calls > 0 { break }; await Task.yield() }
        access.allowed = false
        await service.complete()
        for _ in 0..<100 { if !state.isLoading { break }; await Task.yield() }
        #expect(!state.isLoading && state.output == nil && state.revision == 1)
    }

    @Test func accessRevokedBeforeDispatchMakesNoServiceCall() async {
        let service = AIControlledService()
        let state = AIRequestCoordinator(service: service)
        let access = AITestAccess()
        state.begin(.symptoms(SymptomNormalizationContext(text: "Synthetic"))) { access.allowed }
        access.allowed = false
        for _ in 0..<20 { await Task.yield() }
        #expect(await service.calls == 0)
        #expect(!state.isLoading && state.output == nil)
    }
}

@MainActor private final class AITestAccess { var allowed = true }

private actor AIControlledService: AIService {
    var calls = 0
    var continuation: CheckedContinuation<SymptomNormalizationResult, Never>?
    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func complete() {
        continuation?.resume(returning: SymptomNormalizationResult(symptoms: [AISymptom(type: .cramps, severity: .moderate)]))
        continuation = nil
    }
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult { throw AIServiceError.unavailable }
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation { throw AIServiceError.unavailable }
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult { throw AIServiceError.unavailable }
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult { throw AIServiceError.unavailable }
}
