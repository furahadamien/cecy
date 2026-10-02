import Foundation
import Testing
import UIKit
@testable import cecy

nonisolated struct MultiSymptomQuestionTests {
    private func snapshot(today: LocalDay) throws -> TrackerSnapshot {
        let starts = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        return TrackerSnapshot(periods: starts, onboardingCompletedAt: nil,
            symptoms: [SymptomEntry(day: today, kind: .headache, notes: "PRIVATE NOTE"),
                       SymptomEntry(day: try today.adding(days: -1), kind: .cramps),
                       SymptomEntry(day: try today.adding(days: -90), kind: .headache)])
    }

    @Test func multipleSymptomsHaveSeparateCountsAndStableEncoding() throws {
        let today = try LocalDay(key: 20260929)
        let scope = CycleQuestionScope.symptomFrequency
        guard case .question(let context) = try AIContextBuilder.question(scope.selectedSymptomsQuestion,
            scope: scope, kinds: [.headache, .cramps], snapshot: snapshot(today: today), today: today) else { Issue.record(); return }
        #expect(context.facts.symptom == nil && context.facts.recordedDays == nil)
        #expect(context.facts.symptoms?.map(\.symptom) == [.cramps, .headache])
        #expect(context.facts.symptoms?.map(\.recordedDays) == [1, 1])
        #expect(context.facts.symptoms?.allSatisfy { $0.daysAnalyzed == 90 } == true)
        let data = try JSONEncoder().encode(context)
        let text = String(decoding: data, as: UTF8.self)
        for forbidden in ["PRIVATE", "2026", "notes", "sourceIDs", "sexual", "profile"] { #expect(!text.contains(forbidden)) }
        #expect(try JSONDecoder().decode(CycleQuestionContext.self, from: data) == context)
    }

    @Test func singleSymptomWireShapeRemainsCompatible() throws {
        let today = try LocalDay(key: 20260929), scope = CycleQuestionScope.symptomFrequency
        let snapshot = try snapshot(today: today)
        let question = scope.suggestedQuestion(kind: .headache)
        #expect(try AIContextBuilder.question(question, scope: scope, kinds: [.headache], snapshot: snapshot, today: today)
            == AIContextBuilder.question(question, scope: scope, kind: .headache, snapshot: snapshot, today: today))
    }

    @Test func allSelectionsRemainBoundedAndRespectTimingEligibility() throws {
        let today = try LocalDay(key: 20260929), snapshot = try snapshot(today: today)
        for scope in CycleQuestionScope.allCases where scope != .cycleLengths {
            let request = try AIContextBuilder.question(scope.selectedSymptomsQuestion, scope: scope,
                kinds: Set(SymptomKind.allCases), snapshot: snapshot, today: today)
            guard case .question(let context) = request else { Issue.record(); return }
            #expect(context.facts.symptoms?.count == SymptomKind.allCases.count)
            #expect(try JSONEncoder().encode(context).count < 8_000)
            #expect(context.question.count <= 100)
            if scope != .symptomFrequency {
                #expect(context.facts.symptoms?.allSatisfy { $0.cyclesAnalyzed == 4 && $0.matchingStarts == 0 } == true)
            }
        }
    }

    @Test func unrelatedOrMedicalQuestionsAreRejectedBeforeDispatch() throws {
        let today = try LocalDay(key: 20260929), snapshot = try snapshot(today: today)
        for question in ["Why do I have headaches and cramps?", "Am I pregnant?", "Did I log fatigue?", "Did I log headaches before and after my period?"] {
            #expect(throws: AIContextError.self) {
                try AIContextBuilder.question(question, scope: .beforePeriod, kinds: [.headache, .cramps], snapshot: snapshot, today: today)
            }
        }
        #expect(!AIContextBuilder.supports("How many days did I log headaches?", scope: .symptomFrequency, kinds: [.headache, .cramps]))
        #expect(AIContextBuilder.supports("How many days did I log headaches and cramps?", scope: .symptomFrequency, kinds: [.headache, .cramps]))
        #expect(throws: AIContextError.selectSymptoms) {
            try AIContextBuilder.question("How many days did I log these symptoms?", scope: .symptomFrequency, kinds: [], snapshot: snapshot, today: today)
        }
    }

    @Test func genericQuestionsAndEmptySelectionNeverChangeCycleScope() throws {
        let today = try LocalDay(key: 20260929), snapshot = try snapshot(today: today)
        let text = CycleQuestionScope.cycleLengths.selectedSymptomsQuestion
        #expect(try AIContextBuilder.question(text, scope: .cycleLengths, kinds: [], snapshot: snapshot, today: today)
            == AIContextBuilder.question(text, scope: .cycleLengths, kinds: [.headache, .cramps], snapshot: snapshot, today: today))
    }
}

nonisolated struct RoundThreeProfileTests {
    @Test func healthAndWellnessGoalRoundTripsAndOldGoalsRemainUnchanged() throws {
        var profile = LocalProfile()
        profile.goals = [.trackSymptoms]
        let legacy = try JSONEncoder().encode(profile)
        profile.goals.insert(.healthAndWellness)
        #expect(try JSONDecoder().decode(LocalProfile.self, from: JSONEncoder().encode(profile)).goals == [.trackSymptoms, .healthAndWellness])
        #expect(try JSONDecoder().decode(LocalProfile.self, from: legacy).goals == [.trackSymptoms])
        #expect(TrackingGoal.healthAndWellness.title == "Health and wellness")
    }

    @Test func trackingGoalDoesNotChangeExternalWellnessContext() throws {
        var profile = LocalProfile()
        profile.wellnessPreferences = .init(activityLevel: .beginner, preferredExercises: [], dietaryPreference: .noPreference,
            foodAllergyStatus: .noneKnown, goals: [])
        var snapshot = TrackerSnapshot(periods: [], onboardingCompletedAt: nil, profile: profile)
        let today = try LocalDay(key: 20260929)
        let baseline = try AIContextBuilder.wellness(snapshot: snapshot, today: today)
        snapshot.profile?.goals.insert(.healthAndWellness)
        #expect(try AIContextBuilder.wellness(snapshot: snapshot, today: today) == baseline)
    }

    @MainActor @Test func flowSymbolsExistAndOptionalDraftCanBeCleared() throws {
        for flow in PeriodFlow.allCases { #expect(UIImage(systemName: flow.symbol) != nil) }
        let draft = PeriodDraft(period: Period(start: try LocalDay(key: 20260929)))
        draft.flow = .heavy
        #expect(draft.period.flow == .heavy)
        draft.flow = nil
        #expect(draft.period.flow == nil && !draft.hasChanges)
    }
}
