import Foundation

/// Local preferences only. These values are not dated activity logs or prediction inputs.
nonisolated enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case beginner, moderatelyActive, veryActive
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .moderatelyActive: "Moderately active"
        case .veryActive: "Very active"
        }
    }
}

nonisolated enum PreferredExercise: String, Codable, CaseIterable, Sendable {
    case walking, running, strengthTraining, cycling, yoga, pilates, swimming, sports, homeWorkouts
    var title: String {
        switch self {
        case .strengthTraining: "Strength training"
        case .homeWorkouts: "Home workouts"
        default: rawValue.capitalized
        }
    }
}

nonisolated enum DietaryPreference: String, Codable, CaseIterable, Sendable {
    case noPreference, vegetarian, vegan, pescatarian
    var title: String { self == .noPreference ? "No preference" : rawValue.capitalized }
}

nonisolated enum FoodAllergyStatus: String, Codable, CaseIterable, Sendable {
    case notAnswered, noneKnown, listed
    var title: String {
        switch self {
        case .notAnswered: "Not answered"
        case .noneKnown: "No known food allergies"
        case .listed: "List food allergies"
        }
    }
}

nonisolated enum WellnessGoal: String, Codable, CaseIterable, Sendable {
    case manageSymptoms, stayActive
    var title: String { self == .manageSymptoms ? "Manage symptoms" : "Stay active" }
}

nonisolated struct WellnessPreferences: Codable, Equatable, Sendable {
    static let maximumAllergies = 20
    static let maximumAllergyLength = 80

    var activityLevel: ActivityLevel?
    // nil means unanswered; an empty set means explicitly no preferences.
    var preferredExercises: Set<PreferredExercise>?
    var dietaryPreference: DietaryPreference?
    var foodAllergyStatus: FoodAllergyStatus = .notAnswered
    var foodAllergies: [String] = []
    var goals: Set<WellnessGoal>?

    var isUnanswered: Bool {
        activityLevel == nil && preferredExercises == nil && dietaryPreference == nil
            && foodAllergyStatus == .notAnswered && foodAllergies.isEmpty && goals == nil
    }

    var isReadyForInsights: Bool {
        guard activityLevel != nil, preferredExercises != nil, dietaryPreference != nil,
              foodAllergyStatus != .notAnswered, goals != nil else { return false }
        do { try validate(); return true } catch { return false }
    }

    mutating func setAllergyStatus(_ status: FoodAllergyStatus) {
        foodAllergyStatus = status
        if status != .listed { foodAllergies = [] }
    }

    mutating func addAllergy(_ text: String) throws {
        var candidate = self
        candidate.foodAllergyStatus = .listed
        candidate.foodAllergies.append(text.trimmingCharacters(in: .whitespacesAndNewlines))
        try candidate.validate()
        self = candidate
    }

    func validate() throws {
        guard foodAllergies.count <= Self.maximumAllergies else { throw WellnessValidationError.tooManyAllergies }
        guard foodAllergyStatus == .listed ? !foodAllergies.isEmpty : foodAllergies.isEmpty else {
            throw WellnessValidationError.allergyStatus
        }
        var seen: Set<String> = []
        for name in foodAllergies {
            guard !name.isEmpty, name.count <= Self.maximumAllergyLength,
                  name == name.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw WellnessValidationError.allergyName
            }
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            guard seen.insert(key).inserted else { throw WellnessValidationError.duplicateAllergy }
        }
    }
}

nonisolated enum WellnessValidationError: Error, LocalizedError {
    case allergyStatus, allergyName, duplicateAllergy, tooManyAllergies
    var errorDescription: String? {
        switch self {
        case .allergyStatus: "Add at least one food allergy, or choose Not answered or No known food allergies."
        case .allergyName: "Enter a food allergy using 1–80 characters on one line."
        case .duplicateAllergy: "That food allergy is already listed."
        case .tooManyAllergies: "You can list up to 20 food allergies."
        }
    }
}
