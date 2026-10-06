import Foundation
import Testing
@testable import cecy

private final class AICatalogFixtureBundle: NSObject {}

nonisolated struct AICatalogV2Tests {
    private func fixture(_ name: String) throws -> [String: Any] {
        let bundle = Bundle(for: AICatalogFixtureBundle.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/AICatalog")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "AICatalog"))
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func data(_ value: Any) throws -> Data { try JSONSerialization.data(withJSONObject: value) }

    @Test func exactBackendMappingCoversEveryLocalKind() throws {
        let rows = try #require(fixture("catalog-v2")["entries"] as? [[String: String]])
        #expect(rows.count == 39 && Set(rows.compactMap { $0["apiValue"] }).count == 39)
        #expect(Set(rows.compactMap { $0["iosStorageIdentifier"] }) == Set(SymptomKind.allCases.map(\.rawValue)))
        for row in rows {
            let storage = try #require(row["iosStorageIdentifier"])
            let wire = try #require(row["apiValue"])
            let kind = try #require(SymptomKind(rawValue: storage))
            let type = try #require(AISymptomType(rawValue: wire))
            #expect(type.kind == kind && AISymptomType(kind: kind) == type)
        }
    }

    @Test func decodesAllTenBackendResponseFixtures() throws {
        let cases = try #require(fixture("responses")["cases"] as? [[String: Any]])
        #expect(cases.count == 10)
        for item in cases {
            let rawTask = try #require(item["task"] as? String)
            let task = try #require(AITask(rawValue: rawTask))
            let bytes = try data(#require(item["response"]))
            switch task {
            case .normalizeSymptoms:
                let _: SymptomNormalizationResult = try RemoteAIService.decode(bytes, status: 200, task: task)
            case .explainInsight:
                let _: InsightExplanationResult = try RemoteAIService.decode(bytes, status: 200, task: task)
            case .dailyWellnessRecommendation:
                let _: WellnessRecommendation = try RemoteAIService.decode(bytes, status: 200, task: task)
            case .cycleSummary:
                let _: CycleSummaryResult = try RemoteAIService.decode(bytes, status: 200, task: task)
            case .answerCycleQuestion:
                let _: CycleQuestionResult = try RemoteAIService.decode(bytes, status: 200, task: task)
            }
        }
    }

    @Test func backendErrorFixturesRemainControlledFailures() throws {
        let cases = try #require(fixture("errors")["errors"] as? [[String: Any]])
        #expect(cases.count == 7)
        for item in cases {
            let response = try #require(item["response"] as? [String: Any])
            let error = try #require(response["error"] as? [String: String])
            let expected = AIServiceError.server(try #require(error["code"]))
            let bytes = try data(response)
            let status = try #require(item["httpStatus"] as? Int)
            #expect(throws: expected) {
                let _: SymptomNormalizationResult = try RemoteAIService.decode(bytes, status: status, task: .normalizeSymptoms)
            }
        }
    }

    @Test func handlesExpectedEvaluationOutputsWithoutClaimingModelEvaluation() throws {
        let cases = try #require(fixture("evaluation-cases")["cases"] as? [[String: Any]])
        var covered = Set<AISymptomType>()
        #expect(cases.count == 11)
        for item in cases {
            let types = try #require(item["expectedTypes"] as? [String])
            let symptoms = types.map { ["type": $0, "severity": NSNull()] as [String: Any] }
            let bytes = try data(["success": true, "data": ["symptoms": symptoms]])
            let result: SymptomNormalizationResult = try RemoteAIService.decode(bytes, status: 200, task: .normalizeSymptoms)
            #expect(result.symptoms.map { $0.type.rawValue } == types)
            #expect(result.symptoms.allSatisfy { $0.suggestedRating == nil })
            covered.formUnion(result.symptoms.map(\.type))
        }
        #expect(covered == Set(AISymptomType.allCases))
    }

    @Test func all39SuggestionsAreValidButInvalidRatingsDuplicatesAndUnknownsFail() throws {
        let all = AISymptomType.allCases.map { AISymptom(type: $0, severity: $0.kind.usesSeverity ? .mild : nil) }
        try SymptomNormalizationResult(symptoms: all).validate()
        #expect(throws: AIServiceError.invalidResponse) { try SymptomNormalizationResult(symptoms: all + [all[0]]).validate() }
        for type in [AISymptomType.sleepChange, .lowEnergy, .libido] {
            let item = AISymptom(type: type, severity: .severe)
            #expect(item.suggestedRating == nil)
            #expect(throws: AIServiceError.invalidResponse) { try SymptomNormalizationResult(symptoms: [item]).validate() }
        }
        for value in [#"{"type":"libido"}"#, #"{"type":"invented","severity":null}"#] {
            let bytes = Data("{\"success\":true,\"data\":{\"symptoms\":[\(value)]}}".utf8)
            #expect(throws: AIServiceError.invalidResponse) {
                let _: SymptomNormalizationResult = try RemoteAIService.decode(bytes, status: 200, task: .normalizeSymptoms)
            }
        }
    }

    private func snapshot(today: LocalDay) throws -> TrackerSnapshot {
        var profile = LocalProfile()
        profile.preferredName = "PRIVATE NAME"
        profile.wellnessPreferences = WellnessPreferences(activityLevel: .beginner, preferredExercises: [.walking],
            dietaryPreference: .vegetarian, foodAllergyStatus: .noneKnown, foodAllergies: [], goals: [.manageSymptoms])
        let periods = try stride(from: -168, through: -28, by: 28).map {
            Period(start: try today.adding(days: $0), end: try today.adding(days: $0 + 4), notes: "PRIVATE PERIOD NOTE")
        }
        let days = try periods.map { try $0.start.adding(days: -1) } + [today]
        let symptoms = days.flatMap { day in
            SymptomKind.allCases.map { SymptomEntry(day: day, kind: $0, value: 1, notes: "PRIVATE SYMPTOM NOTE") }
        }
        return TrackerSnapshot(periods: periods, symptoms: symptoms, profile: profile,
            sexualActivities: [SexualActivityEntry(day: today, activities: [.other], notes: "PRIVATE ACTIVITY")])
    }

    private func checkedData(_ request: AIRequest) throws -> Data {
        func encode<C: AIRequestContext>(_ context: C) throws -> Data {
            try context.validateForAI()
            return try JSONEncoder().encode(AIRequestEnvelope(task: request.task, context: context))
        }
        let result: Data
        switch request {
        case .symptoms(let context): result = try encode(context)
        case .insight(let context): result = try encode(context)
        case .wellness(let context): result = try encode(context)
        case .summary(let context): result = try encode(context)
        case .question(let context): result = try encode(context)
        }
        #expect(result.count <= RemoteAIService.maximumRequestBytes)
        let text = String(decoding: result, as: UTF8.self)
        for forbidden in ["PRIVATE", "birthDay", "sourceIDs", "dayKey", "notes", "sexualActivities"] {
            #expect(!text.contains(forbidden))
        }
        return result
    }

    @Test func denseCatalogBuildsBoundedFactsForEveryOperation() throws {
        let today = try LocalDay(key: 20260929)
        let snapshot = try snapshot(today: today)
        let wellness = try AIContextBuilder.wellness(snapshot: snapshot, today: today)
        let records = try AIContextBuilder.recordInsights(snapshot: snapshot, today: today)
        let summary = try AIContextBuilder.summary(snapshot: snapshot, start: snapshot.periods[4].start, today: today)
        guard case .wellness(let w) = wellness, case .question(let r) = records, case .summary(let s) = summary else {
            Issue.record("Expected bounded wellness, record facts and completed summary"); return
        }
        #expect(w.symptoms.count == 39 && r.facts.symptoms?.count == 39)
        #expect(r.facts.confirmedBleedingDurations == Array(repeating: 5, count: 6))
        #expect(s.observations.count <= 30)
        for kind in SymptomKind.allCases { #expect(s.observations.joined().contains(kind.timingTitle)) }
        var requests = [try checkedData(wellness), try checkedData(records), try checkedData(summary),
                        try checkedData(AIContextBuilder.normalization("Synthetic dizziness and low sex drive"))]
        for kind in SymptomKind.allCases {
            for scope in [CycleQuestionScope.symptomFrequency, .beforePeriod, .nearStart] {
                requests.append(try checkedData(AIContextBuilder.question(scope.suggestedQuestion(kind: kind),
                    scope: scope, kind: kind, snapshot: snapshot, today: today)))
            }
            let facts = AIInsightFacts(metric: "recorded symptom timing", units: "days", evidence: "limited",
                caveat: AIContextBuilder.caveat, symptom: AISymptomType(kind: kind), startsAnalyzed: 6, matchingStarts: 6)
            requests.append(try checkedData(.insight(InsightExplanationContext(insightType: "symptom_timing", facts: facts))))
        }
        requests.append(try checkedData(AIContextBuilder.question(CycleQuestionScope.symptomFrequency.selectedSymptomsQuestion,
            scope: .symptomFrequency, kinds: Set(SymptomKind.allCases), snapshot: snapshot, today: today)))
        // Synthetic-only artifact for offline validation against the backend's real schemas.
        let objects = try requests.map { try JSONSerialization.jsonObject(with: $0) }
        try data(objects).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("AIContractGeneratedRequests.json"), options: .atomic)
    }

    @Test func ratingObservationsNeverBecomeSevereOrMislabelHighEnergy() throws {
        let today = try LocalDay(key: 20260929)
        var snapshot = try snapshot(today: today)
        for rating: Int? in [nil, 1, 2, 3] {
            snapshot.symptoms = [SymptomKind.sleepQuality, .energyLevel, .libido].map { SymptomEntry(day: today, kind: $0, value: rating) }
            guard case .wellness(let value) = try AIContextBuilder.wellness(snapshot: snapshot, today: today) else { Issue.record(); return }
            #expect(value.symptoms.count == (rating == 1 ? 3 : 0))
            #expect(value.symptoms.allSatisfy { $0.severity == nil })
            guard case .question(let facts) = try AIContextBuilder.question(CycleQuestionScope.symptomFrequency.suggestedQuestion(kind: .energyLevel),
                scope: .symptomFrequency, kind: .energyLevel, snapshot: snapshot, today: today) else { Issue.record(); return }
            #expect(facts.facts.recordedDays == (rating == 1 ? 1 : 0))
        }
        #expect(!SymptomKind.libido.usesSeverity && SymptomKind.vomiting.usesSeverity)
    }

    @Test func libidoQuestionExceptionDoesNotOpenSexualHistoryOrDiagnosisRouting() {
        for scope in [CycleQuestionScope.symptomFrequency, .beforePeriod, .nearStart] {
            #expect(AIContextBuilder.supports(scope.suggestedQuestion(kind: .libido), scope: scope, kind: .libido))
        }
        for text in ["Why is my sex drive low?", "Show all sexual activity", "Is sex drive a pregnancy sign?",
                     "Did I log sex drive after sex?", "Do I have a diagnosis for low sex drive?", "Show all records of sex drive"] {
            #expect(!AIContextBuilder.supports(text, scope: .symptomFrequency, kind: .libido))
        }
        #expect(!AIContextBuilder.supports("How many days did I log sex drive in the last 90 days?", scope: .symptomFrequency, kind: .headache))
    }

    @Test func longCyclesAndMissingEndsUseExactBoundedFactsWithoutClamping() throws {
        let today = try LocalDay(key: 20260929)
        var snapshot = try snapshot(today: today)
        let start = try today.adding(days: -200), next = try today.adding(days: -20)
        snapshot.periods = [Period(start: start, end: try start.adding(days: 34)), Period(start: next)]
        let request = try AIContextBuilder.summary(snapshot: snapshot, start: start, today: today)
        _ = try checkedData(request)
        guard case .question(let context) = request else { Issue.record(); return }
        #expect(context.facts.averageCycleLength == 180 && context.facts.confirmedBleedingDurations == [35])
        snapshot.periods[0].end = nil
        _ = try checkedData(AIContextBuilder.summary(snapshot: snapshot, start: start, today: today))
        snapshot.periods = [Period(start: start)]
        guard case .wellness(let wellness) = try AIContextBuilder.wellness(snapshot: snapshot, today: today) else { Issue.record(); return }
        #expect(wellness.cycleDay == nil)
    }

    @Test func backendResponseAndUnicodeBoundsAreEnforced() throws {
        #expect(throws: AIContextError.self) { try AIContextBuilder.normalization(String(repeating: "e\u{301}", count: 1_001)) }
        _ = try AIContextBuilder.normalization(String(repeating: "😀", count: 2_000))
        #expect(throws: AIServiceError.invalidResponse) {
            try CycleSummaryResult(summary: "Synthetic", highlights: Array(repeating: "Fact", count: 9), safetyMessage: nil).validate()
        }
        #expect(throws: AIServiceError.invalidResponse) {
            try InsightExplanationResult(title: String(repeating: "a", count: 161), explanation: "Synthetic",
                supportingObservation: "Fact", safetyMessage: nil).validate()
        }
        #expect(throws: AIServiceError.invalidResponse) {
            try CycleQuestionResult(answer: String(repeating: "a", count: 1_201), supportingFacts: [], safetyMessage: nil).validate()
        }
    }
}
