#if DEBUG
import Foundation

/// Synthetic, in-process responses only. Never composed by release builds.
nonisolated struct FixtureAIService: AIService {
    let mode: String
    private func prepare() async throws {
        if mode == "slow" { try await Task.sleep(for: .seconds(20)) }
        else { try await Task.sleep(for: .milliseconds(100)) }
        guard mode == "success" || mode == "slow" || mode == "catalogV2" || mode == "showcase" else { throw AIServiceError.unavailable }
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
    /// Realistic copy for App Store screenshots, keyed by section title.
    private static let showcase: [String: [String]] = [
        "Self-care": ["A warm heat pack on your lower belly for 15–20 minutes can ease cramps.", "Plan a lighter evening and an earlier night."],
        "Food": ["Lentil soup with spinach for iron and fiber.", "Greek yogurt with berries and pumpkin seeds as a snack."],
        "Movement": ["A 20-minute easy walk outdoors.", "Gentle hip-opening stretches before bed."],
        "Hydration": ["Aim for 8 glasses of water; warm ginger tea counts and may help bloating."],
        "Recovery": ["Magnesium with dinner, as you’ve been taking it.", "Keep screens off 30 minutes before sleep."],
        "Skincare": ["Use a gentle cleanser; hormonal shifts can make skin more sensitive this week."],
    ]

    func getDailyInsights(context: DailyInsightsContext) async throws -> DailyInsightsResult {
        try await prepare()
        let food = context.preferences.dietaryPreference == nil || context.preferences.foodAllergies == nil
        let movement = context.preferences.activityLevel == nil || context.preferences.preferredExercises == nil
        let sections = context.requestedSections.map { kind -> DailyInsightSection in
            switch kind {
            case .food where food: DailyInsightSection(kind: kind, unavailable: .missingPreferences)
            case .movement where context.hasSevereSymptom: DailyInsightSection(kind: kind, unavailable: .safetyLimit)
            case .movement where movement: DailyInsightSection(kind: kind, unavailable: .missingPreferences)
            case _ where mode == "showcase": DailyInsightSection(kind: kind, suggestions: Self.showcase[kind.title] ?? ["Take it slow today and notice how you feel."])
            case .movement: DailyInsightSection(kind: kind, suggestions: ["Synthetic gentle movement"])
            default: DailyInsightSection(kind: kind, suggestions: ["Synthetic \(kind.title.lowercased()) suggestion"])
            }
        }
        if mode == "showcase" {
            return DailyInsightsResult(sections: sections,
                explanation: "You logged cramps, fatigue and bloating on day 5 of your period, so today leans toward warmth, iron-rich food and gentle movement.",
                safetyMessage: nil)
        }
        return DailyInsightsResult(sections: sections, explanation: "Synthetic wellness explanation based on supplied symptoms.",
                                   safetyMessage: context.hasSevereSymptom ? "Synthetic safety message" : nil)
    }
}
#endif
