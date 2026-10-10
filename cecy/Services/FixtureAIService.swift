#if DEBUG
import Foundation

/// Synthetic, in-process responses only. Never composed by release builds.
nonisolated struct FixtureAIService: AIService {
    let mode: String
    private func prepare() async throws {
        if mode == "slow" { try await Task.sleep(for: .seconds(20)) }
        else { try await Task.sleep(for: .milliseconds(100)) }
        guard mode == "success" || mode == "slow" || mode == "catalogV2" else { throw AIServiceError.unavailable }
    }
    func normalizeSymptoms(text: String) async throws -> SymptomNormalizationResult {
        try await prepare()
        if mode == "catalogV2" {
            return SymptomNormalizationResult(symptoms: [AISymptom(type: .dizziness, severity: nil),
                AISymptom(type: .vaginalItching, severity: nil), AISymptom(type: .libido, severity: nil)])
        }
        return SymptomNormalizationResult(symptoms: [AISymptom(type: .fatigue, severity: .moderate), AISymptom(type: .digestiveChange, severity: nil)])
    }
    func explainInsight(context: InsightExplanationContext) async throws -> InsightExplanationResult {
        try await prepare()
        return InsightExplanationResult(title: "Synthetic insight explanation", explanation: "This describes only the supplied recorded pattern.",
            supportingObservation: "Matching logs are not evidence of a cause.", safetyMessage: nil)
    }
    func getWellnessRecommendation(context: WellnessRecommendationContext) async throws -> WellnessRecommendation {
        try await prepare()
        return WellnessRecommendation(movementSuggestions: ["Synthetic gentle movement"], foodSuggestions: ["Synthetic food suggestion"],
            hydrationSuggestion: "Synthetic hydration suggestion", recoverySuggestions: ["Synthetic recovery suggestion"],
            explanation: "Synthetic wellness explanation based on supplied symptoms.", safetyMessage: "Synthetic safety message")
    }
    func generateCycleSummary(context: CycleSummaryContext) async throws -> CycleSummaryResult {
        try await prepare()
        return CycleSummaryResult(summary: "Synthetic completed cycle summary", highlights: ["Based on confirmed records"], safetyMessage: nil)
    }
    func answerCycleQuestion(context: CycleQuestionContext) async throws -> CycleQuestionResult {
        try await prepare()
        return CycleQuestionResult(answer: "Synthetic answer from selected facts", supportingFacts: ["Missing logs are not absence"], safetyMessage: nil)
    }
    func getDailyInsights(context: DailyInsightsContext) async throws -> DailyInsightsResult {
        try await prepare()
        let food = context.preferences.dietaryPreference == nil || context.preferences.foodAllergies == nil
        let movement = context.preferences.activityLevel == nil || context.preferences.preferredExercises == nil
        let sections = context.requestedSections.map { kind -> DailyInsightSection in
            switch kind {
            case .food where food: DailyInsightSection(kind: kind, unavailable: .missingPreferences)
            case .movement where context.hasSevereSymptom: DailyInsightSection(kind: kind, unavailable: .safetyLimit)
            case .movement where movement: DailyInsightSection(kind: kind, unavailable: .missingPreferences)
            case .movement: DailyInsightSection(kind: kind, suggestions: ["Synthetic gentle movement"])
            default: DailyInsightSection(kind: kind, suggestions: ["Synthetic \(kind.title.lowercased()) suggestion"])
            }
        }
        return DailyInsightsResult(sections: sections, explanation: "Synthetic wellness explanation based on supplied symptoms.",
                                   safetyMessage: context.hasSevereSymptom ? "Synthetic safety message" : nil)
    }
}
#endif
