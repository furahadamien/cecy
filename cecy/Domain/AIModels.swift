import Foundation

nonisolated enum AITask: String, Codable, Sendable, CaseIterable {
    case normalizeSymptoms = "normalize_symptoms"
    case explainInsight = "explain_insight"
    case dailyWellnessRecommendation = "daily_wellness_recommendation"
    case cycleSummary = "cycle_summary"
    case answerCycleQuestion = "answer_cycle_question"
}

nonisolated struct AIConsentRecord: Codable, Equatable, Sendable {
    static let currentVersion = 1
    let noticeVersion: Int
    let grantedAt: Date
    var isCurrent: Bool { noticeVersion == Self.currentVersion && grantedAt.timeIntervalSinceReferenceDate.isFinite }
}

nonisolated enum AIServiceError: Error, LocalizedError, Equatable {
    case invalidRequest, unsupportedTask, unavailable, invalidResponse, serverError, networkError, cancelled, consentRequired
    var errorDescription: String? {
        switch self {
        case .consentRequired: "Enable optional insights before sending. Manual tracking still works."
        case .cancelled: "Request cancelled. Your records have not been changed."
        default: "Cecy couldn’t process that right now. Your records haven’t changed. Try again or continue manually."
        }
    }
    static func server(_ code: String) -> Self {
        switch code {
        case "INVALID_REQUEST": .invalidRequest
        case "UNSUPPORTED_TASK": .unsupportedTask
        case "AI_UNAVAILABLE": .unavailable
        case "AI_RESPONSE_INVALID": .invalidResponse
        case "INTERNAL_ERROR": .serverError
        default: .serverError
        }
    }
}

nonisolated enum AISymptomType: String, Codable, CaseIterable, Sendable {
    case cramps, headache, bloating, fatigue, acne, nausea, cravings
    case moodChange = "mood_change", backPain = "back_pain", breastTenderness = "breast_tenderness"
    case sleepChange = "sleep_change", lowEnergy = "low_energy", digestiveChange = "digestive_change"
    var kind: SymptomKind {
        switch self {
        case .cramps: .cramps
        case .headache: .headache
        case .bloating: .bloating
        case .fatigue: .fatigue
        case .acne: .acne
        case .nausea: .nausea
        case .cravings: .cravings
        case .moodChange: .moodChanges
        case .backPain: .backPain
        case .breastTenderness: .breastTenderness
        case .sleepChange: .sleepQuality
        case .lowEnergy: .energyLevel
        case .digestiveChange: .digestiveChanges
        }
    }
    init?(kind: SymptomKind) {
        guard let value = Self.allCases.first(where: { $0.kind == kind }) else { return nil }
        self = value
    }
}

nonisolated enum AISeverity: String, Codable, Sendable {
    case mild, moderate, severe
    var rating: Int { switch self { case .mild: 1; case .moderate: 2; case .severe: 3 } }
}

nonisolated struct AISymptom: Codable, Equatable, Sendable {
    let type: AISymptomType
    let severity: AISeverity?
    init(type: AISymptomType, severity: AISeverity?) { self.type = type; self.severity = severity }
    enum CodingKeys: String, CodingKey { case type, severity }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(AISymptomType.self, forKey: .type)
        severity = try values.decode(AISeverity?.self, forKey: .severity)
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(type, forKey: .type)
        try values.encode(severity, forKey: .severity) // Explicit null, not omitted.
    }
    var suggestedRating: Int? {
        type == .sleepChange || type == .lowEnergy ? nil : severity?.rating
    }
}

nonisolated struct SymptomNormalizationContext: Codable, Equatable, Sendable { let text: String }
nonisolated struct InsightExplanationContext: Codable, Equatable, Sendable {
    let insightType: String
    let facts: AIInsightFacts
}
nonisolated struct AIInsightFacts: Codable, Equatable, Sendable {
    let metric: String
    let units: String
    let evidence: String
    let caveat: String
    var previousMetric: Double?
    var recentMetric: Double?
    var previousRecordCount: Int?
    var recentRecordCount: Int?
    var symptom: AISymptomType?
    var startsAnalyzed: Int?
    var matchingStarts: Int?
    var timingWindow: String?
}
nonisolated struct WellnessRecommendationContext: Codable, Equatable, Sendable {
    let cycleDay: Int?
    // estimatedPhase deliberately omitted: no supported local phase policy.
    let symptoms: [AISymptom]
    let activityLevel: String
    let preferredExercises: [String]
    let dietaryPreference: String
    let foodAllergies: [String]
    let userGoals: [String]
}
nonisolated struct CycleSummaryContext: Codable, Equatable, Sendable {
    let periodLabel: String
    let cycleLength: Int
    let averageCycleLength: Double
    let periodLength: Int
    let commonSymptoms: [AISymptomType]
    let observations: [String]
}
nonisolated struct CycleQuestionContext: Codable, Equatable, Sendable {
    let question: String
    let facts: AIQuestionFacts
}
nonisolated struct AIQuestionFacts: Codable, Equatable, Sendable {
    let scope: String
    let caveat: String
    var cyclesAnalyzed: Int?
    var averageCycleLength: Double?
    var minimumCycleLength: Int?
    var maximumCycleLength: Int?
    var populationStandardDeviationDays: Double?
    var symptom: AISymptomType?
    var daysAnalyzed: Int?
    var recordedDays: Int?
    var matchingStarts: Int?
    var timingWindow: String?
    var minimumRecordedOffsetDays: Int?
    var maximumRecordedOffsetDays: Int?
    var symptoms: [AIQuestionSymptomFacts]?
}

nonisolated struct AIQuestionSymptomFacts: Codable, Equatable, Sendable {
    let symptom: AISymptomType
    let cyclesAnalyzed: Int?
    let daysAnalyzed: Int?
    let recordedDays: Int?
    let matchingStarts: Int?
    let timingWindow: String?
    let minimumRecordedOffsetDays: Int?
    let maximumRecordedOffsetDays: Int?
}

nonisolated protocol AIValidatedResponse: Codable, Sendable { func validate() throws }
nonisolated enum AIResponseValidation {
    static func text(_ value: String, maximum: Int = 4_000) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, value.count <= maximum else {
            throw AIServiceError.invalidResponse
        }
    }
    static func list(_ values: [String], maximum: Int) throws {
        guard values.count <= maximum else { throw AIServiceError.invalidResponse }
        for value in values { try text(value) }
    }
    static func safety(_ value: String?) throws { if let value { try text(value) } }
}
nonisolated struct SymptomNormalizationResult: AIValidatedResponse, Equatable {
    let symptoms: [AISymptom]
    func validate() throws {
        guard symptoms.count <= 20, Set(symptoms.map(\.type)).count == symptoms.count else {
            throw AIServiceError.invalidResponse
        }
    }
}
nonisolated struct InsightExplanationResult: AIValidatedResponse, Equatable {
    let title: String
    let explanation: String
    let supportingObservation: String
    let safetyMessage: String?
    func validate() throws {
        try AIResponseValidation.text(title, maximum: 300)
        try AIResponseValidation.text(explanation)
        try AIResponseValidation.text(supportingObservation)
        try AIResponseValidation.safety(safetyMessage)
    }
}
nonisolated struct WellnessRecommendation: AIValidatedResponse, Equatable {
    let movementSuggestions: [String]
    let foodSuggestions: [String]
    let hydrationSuggestion: String
    let recoverySuggestions: [String]
    let explanation: String
    let safetyMessage: String?
    func validate() throws {
        try AIResponseValidation.list(movementSuggestions, maximum: 6)
        try AIResponseValidation.list(foodSuggestions, maximum: 6)
        try AIResponseValidation.text(hydrationSuggestion)
        try AIResponseValidation.list(recoverySuggestions, maximum: 6)
        try AIResponseValidation.text(explanation)
        try AIResponseValidation.safety(safetyMessage)
    }
}
nonisolated struct CycleSummaryResult: AIValidatedResponse, Equatable {
    let summary: String
    let highlights: [String]
    let safetyMessage: String?
    func validate() throws {
        try AIResponseValidation.text(summary)
        try AIResponseValidation.list(highlights, maximum: 20)
        try AIResponseValidation.safety(safetyMessage)
    }
}
nonisolated struct CycleQuestionResult: AIValidatedResponse, Equatable {
    let answer: String
    let supportingFacts: [String]
    let safetyMessage: String?
    func validate() throws {
        try AIResponseValidation.text(answer)
        try AIResponseValidation.list(supportingFacts, maximum: 20)
        try AIResponseValidation.safety(safetyMessage)
    }
}

nonisolated enum AIRequest: Equatable, Sendable {
    case symptoms(SymptomNormalizationContext)
    case insight(InsightExplanationContext)
    case wellness(WellnessRecommendationContext)
    case summary(CycleSummaryContext)
    case question(CycleQuestionContext)
    var task: AITask {
        switch self {
        case .symptoms: .normalizeSymptoms
        case .insight: .explainInsight
        case .wellness: .dailyWellnessRecommendation
        case .summary: .cycleSummary
        case .question: .answerCycleQuestion
        }
    }
}
nonisolated enum AIOutput: Equatable, Sendable {
    case symptoms(SymptomNormalizationResult)
    case insight(InsightExplanationResult)
    case wellness(WellnessRecommendation)
    case summary(CycleSummaryResult)
    case question(CycleQuestionResult)
}
