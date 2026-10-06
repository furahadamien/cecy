import Foundation

nonisolated protocol AIRequestContext: Encodable, Sendable {
    func validateForAI() throws
}

/// Matches the deployed v2 request contract. Never truncates facts or allergy lists.
nonisolated enum AIRequestValidation {
    static func require(_ condition: Bool) throws {
        if !condition { throw AIServiceError.invalidRequest }
    }

    static func text(_ value: String, maximum: Int, allowEmpty: Bool = false) throws {
        try require((allowEmpty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    && value.unicodeScalars.count <= maximum)
    }

    static func strings(_ values: [String], count: Int, length: Int) throws {
        try require(values.count <= count)
        for value in values { try text(value, maximum: length) }
    }

    static func facts<T: Encodable>(_ value: T) throws {
        do {
            let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
            guard let fields = object as? [String: Any] else { throw AIServiceError.invalidRequest }
            try require(!fields.isEmpty && fields.count <= 40)
            for (key, value) in fields {
                try text(key, maximum: 80)
                if let objects = value as? [[String: Any]] {
                    try require(objects.count <= 39)
                    for object in objects { try nestedFacts(object) }
                } else if let array = value as? [Any] {
                    try require(array.count <= 20)
                    for item in array { try scalar(item) }
                } else if let object = value as? [String: Any] {
                    try nestedFacts(object)
                } else { try scalar(value) }
            }
        } catch { throw AIServiceError.invalidRequest }
    }

    private static func nestedFacts(_ fields: [String: Any]) throws {
        try require(fields.count <= 20)
        for (key, value) in fields {
            try text(key, maximum: 80)
            try scalar(value)
        }
    }

    private static func scalar(_ value: Any) throws {
        if let string = value as? String { try text(string, maximum: 500, allowEmpty: true) }
        else if let number = value as? NSNumber { try require(number.doubleValue.isFinite) }
        else { try require(value is NSNull) }
    }
}

extension SymptomNormalizationContext: AIRequestContext {
    func validateForAI() throws { try AIRequestValidation.text(text, maximum: 2_000) }
}

extension InsightExplanationContext: AIRequestContext {
    func validateForAI() throws {
        try AIRequestValidation.text(insightType, maximum: 100)
        try AIRequestValidation.facts(facts)
    }
}

extension WellnessRecommendationContext: AIRequestContext {
    func validateForAI() throws {
        if let cycleDay { try AIRequestValidation.require((1...100).contains(cycleDay)) }
        try AIRequestValidation.require(symptoms.count <= 39)
        try AIRequestValidation.require(symptoms.allSatisfy { $0.type.kind.usesSeverity || $0.severity == nil })
        try AIRequestValidation.text(activityLevel, maximum: 80)
        try AIRequestValidation.text(dietaryPreference, maximum: 100)
        try AIRequestValidation.strings(preferredExercises, count: 20, length: 200)
        try AIRequestValidation.strings(foodAllergies, count: 20, length: 200)
        try AIRequestValidation.strings(userGoals, count: 20, length: 200)
    }
}

extension CycleSummaryContext: AIRequestContext {
    func validateForAI() throws {
        try AIRequestValidation.text(periodLabel, maximum: 100)
        try AIRequestValidation.require((1...100).contains(cycleLength) && (1...30).contains(periodLength))
        try AIRequestValidation.require(averageCycleLength.isFinite && (1...100).contains(averageCycleLength))
        try AIRequestValidation.require(commonSymptoms.count <= 39)
        try AIRequestValidation.strings(observations, count: 30, length: 500)
    }
}

extension CycleQuestionContext: AIRequestContext {
    func validateForAI() throws {
        try AIRequestValidation.require(question.count <= AIContextBuilder.maximumQuestionLength)
        try AIRequestValidation.text(question, maximum: 1_000)
        try AIRequestValidation.facts(facts)
    }
}