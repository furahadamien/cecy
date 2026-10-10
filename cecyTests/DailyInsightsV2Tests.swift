import Foundation
import Testing
@testable import cecy

private final class DailyInsightsFixtureBundle: NSObject {}

extension DailyInsightsResult {
    static let synthetic = DailyInsightsResult(
        sections: DailyInsightSectionKind.allCases.map { DailyInsightSection(kind: $0, suggestions: ["Synthetic \($0.title)"]) },
        explanation: "Synthetic guidance", safetyMessage: nil)
}

nonisolated struct DailyInsightsV2Tests {
    let today = try! LocalDay(key: 20261002)

    private func fixture(_ name: String) throws -> [String: Any] {
        let bundle = Bundle(for: DailyInsightsFixtureBundle.self)
        let file = "daily-insights-v2-\(name)"
        let url = try #require(bundle.url(forResource: file, withExtension: "json")
            ?? bundle.url(forResource: file, withExtension: "json", subdirectory: "Fixtures/DailyInsightsV2")
            ?? bundle.url(forResource: file, withExtension: "json", subdirectory: "DailyInsightsV2"))
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }
    private func data(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
    private func json(_ context: DailyInsightsContext) throws -> NSDictionary {
        let body = try JSONEncoder().encode(AIRequestEnvelope(task: AITask.dailyInsightsV2, context: context))
        return try #require(JSONSerialization.jsonObject(with: body) as? NSDictionary)
    }

    private var successContext: DailyInsightsContext {
        DailyInsightsContext(cycleDay: 2, phase: DailyInsightPhase(value: .menstrual, basis: .recordedBleeding, limitations: []),
            symptoms: [AISymptom(type: .cramps, severity: .moderate), AISymptom(type: .fatigue, severity: nil)],
            dailyBleeding: DailyInsightBleeding(state: .bleeding, flow: .moderate),
            preferences: DailyInsightPreferences(WellnessPreferences(activityLevel: .moderatelyActive, preferredExercises: [.yoga, .walking],
                dietaryPreference: .vegetarian, foodAllergyStatus: .listed, foodAllergies: ["Peanuts"], goals: [.stayActive, .manageSymptoms])))
    }
    private var sparseContext: DailyInsightsContext {
        DailyInsightsContext(cycleDay: nil, phase: DailyInsightPhase(value: nil, basis: .unknown,
            limitations: [.insufficientCycleHistory, .cycleDayUnavailable]), symptoms: [], dailyBleeding: nil,
            preferences: DailyInsightPreferences(nil), requestedSections: [.selfCare, .hydration, .skincare])
    }
    private var missingPreferencesContext: DailyInsightsContext {
        DailyInsightsContext(cycleDay: nil, phase: DailyInsightPhase(value: nil, basis: .unknown, limitations: [.cycleDayUnavailable]),
            symptoms: [], dailyBleeding: nil, preferences: DailyInsightPreferences(WellnessPreferences()),
            requestedSections: [.food, .movement, .recovery])
    }
    private var safetyContext: DailyInsightsContext {
        DailyInsightsContext(cycleDay: 18, phase: DailyInsightPhase(value: .luteal, basis: .estimated, limitations: [.phaseBoundaryUncertain]),
            symptoms: [AISymptom(type: .vomiting, severity: .severe)], dailyBleeding: nil,
            preferences: DailyInsightPreferences(WellnessPreferences(activityLevel: .veryActive, preferredExercises: [.strengthTraining, .running],
                dietaryPreference: .vegan, foodAllergyStatus: .listed, foodAllergies: ["Tree nuts"], goals: [.stayActive])),
            requestedSections: [.movement, .hydration, .recovery])
    }

    @Test func requestsMatchBackendFixturesExactlyIncludingExplicitNulls() throws {
        for (name, context) in [("success", successContext), ("sparse-unknown", sparseContext),
                                ("missing-preferences", missingPreferencesContext), ("safety-refusal", safetyContext)] {
            try context.validateForAI()
            let expected = try #require(fixture(name)["request"] as? NSDictionary)
            #expect(try json(context) == expected, "request mismatch: \(name)")
        }
    }

    @Test func responsesFromBackendFixturesDecodeAndValidateAgainstTheirRequests() throws {
        for (name, context) in [("success", successContext), ("sparse-unknown", sparseContext),
                                ("missing-preferences", missingPreferencesContext), ("safety-refusal", safetyContext)] {
            let bytes = try data(#require(fixture(name)["response"]))
            let result: DailyInsightsResult = try RemoteAIService.decode(bytes, status: 200, task: .dailyInsightsV2)
            try result.validate(for: context)
            #expect(result.sections.map(\.kind) == context.requestedSections)
        }
        let missing: DailyInsightsResult = try RemoteAIService.decode(data(#require(fixture("missing-preferences")["response"])),
                                                                     status: 200, task: .dailyInsightsV2)
        #expect(missing.sections.prefix(2).allSatisfy { $0.unavailableReason == .missingPreferences && $0.suggestions.isEmpty })
        let safety: DailyInsightsResult = try RemoteAIService.decode(data(#require(fixture("safety-refusal")["response"])),
                                                                    status: 200, task: .dailyInsightsV2)
        #expect(safety.safetyMessage != nil && safety.sections[0].unavailableReason == .safetyLimit)
    }

    @Test func errorFixturesMapToControlledFailures() throws {
        let cases = try #require(fixture("errors")["cases"] as? [[String: Any]])
        #expect(cases.count == 5)
        for item in cases {
            let response = try #require(item["response"] as? [String: Any])
            let code = try #require((response["error"] as? [String: String])?["code"])
            let status = try #require(item["httpStatus"] as? Int)
            #expect(throws: AIServiceError.server(code)) {
                let _: DailyInsightsResult = try RemoteAIService.decode(data(response), status: status, task: .dailyInsightsV2)
            }
        }
        #expect(AIServiceError.server("AI_UNAVAILABLE") == .unavailable)
    }

    @Test func responseContractViolationsAreRejected() throws {
        func payload(_ sections: [[String: Any]], safety: Any? = NSNull(), dropSafety: Bool = false) throws -> Data {
            var body: [String: Any] = ["schemaVersion": 2, "sections": sections, "explanation": "Synthetic"]
            if !dropSafety { body["safetyMessage"] = safety }
            return try data(["success": true, "data": body])
        }
        func available(_ kind: String) -> [String: Any] {
            ["kind": kind, "status": "available", "suggestions": ["Synthetic"], "unavailableReason": NSNull()]
        }
        let context = DailyInsightsContext(cycleDay: nil, phase: DailyInsightPhase(value: nil, basis: .unknown, limitations: [.cycleDayUnavailable]),
            symptoms: [], dailyBleeding: nil, preferences: DailyInsightPreferences(nil), requestedSections: [.selfCare, .hydration])
        func check(_ bytes: Data, _ context: DailyInsightsContext) throws {
            let result: DailyInsightsResult = try RemoteAIService.decode(bytes, status: 200, task: .dailyInsightsV2)
            try result.validate(for: context)
        }
        try check(payload([available("self_care"), available("hydration")]), context)
        let invalid: [Data] = [
            try payload([available("hydration"), available("self_care")]), // Wrong order.
            try payload([available("self_care")]), // Missing section.
            try payload([available("self_care"), available("hydration"), available("food")]), // Extra section.
            try payload([available("self_care"), available("self_care")]), // Duplicate.
            try payload([available("self_care"), available("hydration")], dropSafety: true), // Required nullable field.
            try payload([available("self_care"), ["kind": "hydration", "status": "available", "suggestions": [String]()],
                         ]), // Missing unavailableReason key.
            try payload([available("self_care"), ["kind": "hydration", "status": "available", "suggestions": ["x"],
                                                   "unavailableReason": "safety_limit"]]),
            try payload([available("self_care"), ["kind": "hydration", "status": "unavailable", "suggestions": ["x"],
                                                   "unavailableReason": "safety_limit"]]),
            try payload([available("self_care"), ["kind": "hydration", "status": "unavailable", "suggestions": [String](),
                                                   "unavailableReason": NSNull()]]),
            try payload([available("self_care"), ["kind": "hydration", "status": "available",
                                                   "suggestions": [String(repeating: "a", count: 201)], "unavailableReason": NSNull()]]),
            try payload([available("self_care"), available("hydration")], safety: ""),
        ]
        for bytes in invalid { #expect(throws: (any Error).self) { try check(bytes, context) } }
        // Severe symptoms require a safety message and a safety-limited movement section.
        #expect(throws: (any Error).self) {
            try check(payload([available("movement"), available("hydration"), available("recovery")],
                              safety: "Synthetic"), safetyContext)
        }
        #expect(throws: (any Error).self) {
            try check(payload([["kind": "movement", "status": "unavailable", "suggestions": [String](), "unavailableReason": "safety_limit"],
                               available("hydration"), available("recovery")]), safetyContext)
        }
    }

    @Test func requestInvariantsFailClosedBeforeSending() {
        let prefs = DailyInsightPreferences(nil)
        let bad: [DailyInsightsContext] = [
            DailyInsightsContext(cycleDay: 0, phase: .init(value: nil, basis: .unknown, limitations: []), symptoms: [], dailyBleeding: nil, preferences: prefs),
            DailyInsightsContext(cycleDay: 3, phase: .init(value: .luteal, basis: .unknown, limitations: []), symptoms: [], dailyBleeding: nil, preferences: prefs),
            DailyInsightsContext(cycleDay: 3, phase: .init(value: nil, basis: .estimated, limitations: []), symptoms: [], dailyBleeding: nil, preferences: prefs),
            DailyInsightsContext(cycleDay: 3, phase: .init(value: .menstrual, basis: .recordedBleeding, limitations: []), symptoms: [],
                                 dailyBleeding: .init(state: .spotting, flow: nil), preferences: prefs),
            DailyInsightsContext(cycleDay: 20, phase: .init(value: .luteal, basis: .estimated, limitations: [.phaseBoundaryUncertain]), symptoms: [],
                                 dailyBleeding: .init(state: .bleeding, flow: .light), preferences: prefs),
            DailyInsightsContext(cycleDay: 3, phase: .init(value: nil, basis: .unknown, limitations: []),
                                 symptoms: [AISymptom(type: .libido, severity: .mild)], dailyBleeding: nil, preferences: prefs),
            DailyInsightsContext(cycleDay: 3, phase: .init(value: nil, basis: .unknown, limitations: []), symptoms: [], dailyBleeding: nil,
                                 preferences: prefs, requestedSections: []),
        ]
        for context in bad { #expect(throws: AIServiceError.invalidRequest) { try context.validateForAI() } }
        #expect(DailyInsightBleeding(state: .spotting, flow: .heavy).flow == nil)
    }

    @Test func builderUsesRecordedBleedingAndSendsNoPrivateFields() throws {
        var profile = LocalProfile()
        profile.preferredName = "PRIVATE NAME"
        profile.birthDayKey = 19950101
        let periods = [Period(start: try today.adding(days: -28), end: try today.adding(days: -24), notes: "PRIVATE"),
                       Period(start: today, notes: "PRIVATE")]
        let snapshot = TrackerSnapshot(periods: periods, symptoms: [SymptomEntry(day: today, kind: .cramps, value: 3, notes: "PRIVATE")],
            profile: profile, sexualActivities: [SexualActivityEntry(day: today, activities: [.other], notes: "PRIVATE")])
        let overview = CycleCalculator.overview(periods: periods, today: today, profile: profile)
        let request = try AIContextBuilder.dailyInsights(snapshot: snapshot, today: today, overview: overview, forecast: CycleForecast())
        guard case .dailyInsights(let context) = request else { Issue.record("wrong request"); return }
        #expect(request.task == .dailyInsightsV2)
        #expect(context.cycleDay == 1 && context.phase.basis == .recordedBleeding && context.phase.value == "menstrual")
        #expect(context.dailyBleeding == DailyInsightBleeding(state: .bleeding, flow: nil))
        #expect(context.symptoms == [AISymptom(type: .cramps, severity: .severe)])
        #expect(context.requestedSections == DailyInsightSectionKind.allCases)
        let text = String(decoding: try JSONEncoder().encode(context), as: UTF8.self)
        for forbidden in ["PRIVATE", "2026", "1995", "birth", "notes", "sexual", "id\""] { #expect(!text.contains(forbidden)) }
        for key in ["\"activityLevel\":null", "\"foodAllergies\":null", "\"userGoals\":null"] { #expect(text.contains(key)) }
    }

    @Test func builderWithoutHistoryReportsUnknownPhaseWithNulls() throws {
        let snapshot = TrackerSnapshot(periods: [], symptoms: [])
        let request = try AIContextBuilder.dailyInsights(snapshot: snapshot, today: today, overview: nil, forecast: CycleForecast())
        guard case .dailyInsights(let context) = request else { Issue.record("wrong request"); return }
        #expect(context.cycleDay == nil && context.phase.value == nil && context.phase.basis == .unknown)
        #expect(context.phase.limitations == [.cycleDayUnavailable, .insufficientCycleHistory])
        let text = String(decoding: try JSONEncoder().encode(context), as: UTF8.self)
        #expect(text.contains("\"cycleDay\":null") && text.contains("\"dailyBleeding\":null") && text.contains("\"value\":null"))
    }

    @Test func spottingAnswerIsSentWithoutFlowAndNeverClaimsRecordedBleeding() throws {
        let periods = [Period(start: try today.adding(days: -10), end: try today.adding(days: -6))]
        let answer = DailyBleedingObservation(day: today, state: .spotting)
        let snapshot = TrackerSnapshot(periods: periods, dailyBleeding: [answer])
        let overview = CycleCalculator.overview(periods: periods, today: today)
        let request = try AIContextBuilder.dailyInsights(snapshot: snapshot, today: today, overview: overview, forecast: CycleForecast())
        guard case .dailyInsights(let context) = request else { Issue.record("wrong request"); return }
        #expect(context.dailyBleeding == DailyInsightBleeding(state: .spotting, flow: nil))
        #expect(context.phase.basis != .recordedBleeding && context.cycleDay == 11)
    }
}

@MainActor struct DailyInsightsV2StorageTests {
    let today = try! LocalDay(key: 20261002)

    @Test func legacyV1StoredInsightIsDiscarded() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("daily-insight.json")
        let store = FileDailyInsightStore(url: url)
        try store.save(StoredDailyInsight(dayKey: today.key, insights: .synthetic))
        #expect(try store.load()?.insights == .synthetic)
        let legacy = #"{"version":1,"dayKey":20261002,"wellness":{"movementSuggestions":["Walk"],"foodSuggestions":["Meal"],"hydrationSuggestion":"Water","recoverySuggestions":["Rest"],"explanation":"Synthetic","safetyMessage":null}}"#
        try Data(legacy.utf8).write(to: url)
        #expect(throws: (any Error).self) { try store.load() }
        try store.clear()
    }

    @Test func priorAutomaticConsentVersionRequiresRenewal() {
        let storage = MemoryPrivacyPreferences()
        storage.value.aiConsent = AIConsentRecord(noticeVersion: AIConsentRecord.currentVersion, grantedAt: Date())
        storage.value.dailyInsightsEnabled = true
        storage.value.dailyInsightConsentVersion = 2
        let privacy = TrackerPrivacy(storage: storage, authentication: FixedDeviceAuthentication(),
            exports: ProtectedExportFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            delivery: MemoryReminderDelivery())
        privacy.start()
        #expect(privacy.aiEnabled && !privacy.dailyInsightsEnabled)
        #expect(privacy.setDailyInsightsEnabled(true) == nil && privacy.dailyInsightsEnabled)
        #expect(storage.value.dailyInsightConsentVersion == TrackerPrivacy.dailyConsentVersion)
        #expect(!AIConsentRecord(noticeVersion: 2, grantedAt: Date()).isCurrent)
    }
}
