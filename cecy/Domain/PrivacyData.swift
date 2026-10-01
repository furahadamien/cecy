import Foundation

nonisolated enum AppAppearance: String, Codable, Sendable {
    case light, dark
}

nonisolated struct PrivacyPreferences: Codable, Equatable, Sendable {
    var version = 1
    var lockEnabled = false
    var dailyReminder = false
    var windowReminder = false
    var reminderHour = 20
    var reminderMinute = 0
    // Missing in earlier preference files means follow the device, not a reset of privacy choices.
    var appearance: AppAppearance?
    // Missing in legacy files means no AI consent, never an implicit opt-in.
    var aiConsent: AIConsentRecord?

    func validate() throws {
        guard version == 1, (0...23).contains(reminderHour), (0...59).contains(reminderMinute) else { throw TrackingError.invalidData }
    }
}

nonisolated struct ReminderRequest: Equatable, Sendable {
    enum Kind: String, Sendable { case daily, window }
    let kind: Kind
    let hour: Int
    let minute: Int
    let day: LocalDay?
    var id: String { "cecy.reminder.\(kind.rawValue)" }
    static let identifiers = ["cecy.reminder.daily", "cecy.reminder.window"]
}

nonisolated enum ReminderPlanner {
    static func requests(preferences: PrivacyPreferences, prediction: CyclePrediction?, now: Date, timeZone: TimeZone) throws -> [ReminderRequest] {
        try preferences.validate()
        var requests: [ReminderRequest] = []
        if preferences.dailyReminder {
            requests.append(ReminderRequest(kind: .daily, hour: preferences.reminderHour, minute: preferences.reminderMinute, day: nil))
        }
        if preferences.windowReminder, let prediction {
            let day = try prediction.earliest.adding(days: -1)
            var calendar = LocalDay.calendar
            calendar.timeZone = timeZone
            // nextDate resolves a missing spring-forward time using the next valid time.
            let midnight = try day.pickerDate(in: timeZone)
            let start = calendar.startOfDay(for: midnight)
            let matching = DateComponents(hour: preferences.reminderHour, minute: preferences.reminderMinute)
            if let fire = calendar.nextDate(after: start.addingTimeInterval(-1), matching: matching,
                                            matchingPolicy: .nextTime, repeatedTimePolicy: .first),
               try LocalDay(date: fire, timeZone: timeZone) == day, fire > now {
                let components = calendar.dateComponents([.hour, .minute], from: fire)
                requests.append(ReminderRequest(kind: .window, hour: components.hour!, minute: components.minute!, day: day))
            }
        }
        return requests
    }
}

nonisolated enum TrackerExport {
    struct Document: Codable {
        let formatVersion: Int
        let generatedAt: Date
        let includesPrivateNotes: Bool
        let periods: [PeriodRecord]
        let observations: [ObservationRecord]
        let profile: ProfileRecord?
        let sexualActivities: [SexualActivityRecord]?
    }
    struct ProfileRecord: Codable {
        let preferredName: String
        let dateOfBirth: String?
        let measurementSystem: String
        let heightCentimeters: Double?
        let weightKilograms: Double?
        let cyclePredictability: String
        let typicalPeriodDays: Int?
        let commonSymptoms: [String]
        let cycleContext: [String]
        let goals: [String]
        let wellnessPreferences: WellnessRecord?

        init(_ profile: LocalProfile) throws {
            try profile.validate()
            preferredName = profile.preferredName
            dateOfBirth = try profile.birthDayKey.map { civilDate(try LocalDay(key: $0)) }
            measurementSystem = profile.measurementSystem.rawValue
            heightCentimeters = profile.heightCentimeters
            weightKilograms = profile.weightKilograms
            cyclePredictability = profile.predictability.rawValue
            typicalPeriodDays = profile.typicalPeriodDays
            commonSymptoms = profile.commonSymptoms.map(\.rawValue).sorted()
            cycleContext = profile.cycleContext.map(\.rawValue).sorted()
            goals = profile.goals.map(\.rawValue).sorted()
            wellnessPreferences = profile.wellnessPreferences.map(WellnessRecord.init)
        }
    }
    struct WellnessRecord: Codable {
        let activityLevel: String?
        let preferredExercises: [String]?
        let dietaryPreference: String?
        let foodAllergyStatus: String
        let foodAllergies: [String]
        let goals: [String]?

        init(_ preferences: WellnessPreferences) {
            activityLevel = preferences.activityLevel?.rawValue
            preferredExercises = preferences.preferredExercises.map { $0.map(\.rawValue).sorted() }
            dietaryPreference = preferences.dietaryPreference?.rawValue
            foodAllergyStatus = preferences.foodAllergyStatus.rawValue
            foodAllergies = preferences.foodAllergies.sorted()
            goals = preferences.goals.map { $0.map(\.rawValue).sorted() }
        }
    }
    struct PeriodRecord: Codable {
        let id: UUID
        let start: String
        let end: String?
        let flow: String?
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
    }
    struct ObservationRecord: Codable {
        let id: UUID
        let date: String
        let type: String
        let rating: Int?
        let ratingLabel: String?
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
    }
    struct SexualActivityRecord: Codable {
        let id: UUID
        let date: String
        let activities: [String]
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
    }
    static func civilDate(_ day: LocalDay) -> String {
        String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"), day.year, day.month, day.day)
    }
    static func encode(snapshot: TrackerSnapshot, includeNotes: Bool, generatedAt: Date, includeProfile: Bool = false,
                       includeSexualActivity: Bool = false) throws -> Data {
        try PeriodValidation.validate(snapshot.periods)
        try SymptomValidation.validate(snapshot.symptoms)
        try SexualActivityValidation.validate(snapshot.sexualActivities)
        guard generatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
        let version = includeProfile && snapshot.profile?.wellnessPreferences != nil ? 4 : (includeSexualActivity ? 3 : (includeProfile ? 2 : 1))
        let document = Document(formatVersion: version, generatedAt: generatedAt, includesPrivateNotes: includeNotes,
            periods: snapshot.periods.sorted { $0.start < $1.start }.map {
                PeriodRecord(id: $0.id, start: civilDate($0.start), end: $0.end.map(civilDate), flow: $0.flow?.rawValue,
                             notes: includeNotes ? $0.notes : nil, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            }, observations: SymptomValidation.sorted(snapshot.symptoms).map {
                ObservationRecord(id: $0.id, date: civilDate($0.day), type: $0.kind.rawValue, rating: $0.value,
                                  ratingLabel: $0.ratingLabel, notes: includeNotes ? $0.notes : nil,
                                  createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            }, profile: includeProfile ? try snapshot.profile.map(ProfileRecord.init) : nil,
            sexualActivities: includeSexualActivity ? SexualActivityValidation.sorted(snapshot.sexualActivities).map {
                SexualActivityRecord(id: $0.id, date: civilDate($0.day), activities: $0.orderedActivities.map(\.rawValue),
                                     notes: includeNotes ? $0.notes : nil, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            } : nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }
}
