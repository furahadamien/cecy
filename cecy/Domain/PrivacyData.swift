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
    // Existing installations retain discreet notification content until explicitly enabled.
    var reminderDetailsEnabled: Bool?
    // Missing in earlier preference files means follow the device, not a reset of privacy choices.
    var appearance: AppAppearance?
    // Missing in legacy files means no AI consent, never an implicit opt-in.
    var aiConsent: AIConsentRecord?
    // Nil in existing installations means automatic external requests are off.
    var dailyInsightsEnabled: Bool?
    // Attempt is reserved before sending, preventing repeat requests after relaunch/failure.
    var dailyInsightAttemptDay: Int?
    // Renew automatic consent when its payload expands from record facts to wellness preferences.
    var dailyInsightConsentVersion: Int?
    var dailyInsightPresentationDay: Int?
    // Local UI preferences only; never exported or treated as symptom observations.
    var checkInPreferences: CheckInPreferences?
    var periodFollowUpReminder: Bool?
    var symptomReminderKinds: [SymptomKind]?
    var missedLogReminder: Bool?
    var remindersSnoozedUntilDay: Int?
    var reminderDetailsByKind: [String: Bool]?

    func validate() throws {
        guard version == 1, (0...23).contains(reminderHour), (0...59).contains(reminderMinute) else { throw TrackingError.invalidData }
        if let dailyInsightAttemptDay { _ = try LocalDay(key: dailyInsightAttemptDay) }
        if let dailyInsightPresentationDay { _ = try LocalDay(key: dailyInsightPresentationDay) }
        if let checkInPreferences {
            guard Set(checkInPreferences.pinnedSymptoms).count == checkInPreferences.pinnedSymptoms.count,
                  Set(checkInPreferences.pinnedSymptoms).isDisjoint(with: checkInPreferences.hiddenSymptoms) else {
                throw TrackingError.invalidData
            }
        }
        if let remindersSnoozedUntilDay { _ = try LocalDay(key: remindersSnoozedUntilDay) }
        if let reminderDetailsByKind {
            guard reminderDetailsByKind.keys.allSatisfy({ ReminderRequest.Kind(rawValue: $0) != nil }) else { throw TrackingError.invalidData }
        }
    }
}

nonisolated struct ReminderRequest: Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case daily, window, periodStarted, periodEnded, symptom, missedLog, treatment

        var title: String {
            return switch self {
            case .daily: "Daily check-in"
            case .window: "Period window"
            case .periodStarted: "Period follow-up"
            case .periodEnded: "Period follow-up"
            case .symptom: "Symptom check-in"
            case .missedLog: "Recording check-in"
            case .treatment: "Treatment check-in"
            }
        }
        var scheduleDescription: String {
            switch self {
            case .daily: "Every day: log your period, symptoms or how you feel."
            case .window: "Once, 1 day before your earliest estimated period start."
            case .periodStarted, .periodEnded: "A follow-up after a recorded period starts or ends."
            case .symptom: "A user-selected symptom check-in."
            case .missedLog: "A neutral prompt when you may want to update Cecy."
            case .treatment: "A reminder on the schedule saved with a treatment."
            }
        }
        func notificationTitle(showDetails: Bool) -> String {
            showDetails ? title : "Cecy check-in"
        }
        func notificationBody(showDetails: Bool) -> String {
            guard showDetails else {
                return "Open Cecy for your scheduled check-in."
            }
            return switch self {
            case .daily: "Log your period, symptoms or how you feel today."
            case .window: "Check your estimated period start window in Cecy."
            case .periodStarted: "Review your recorded period start and add any daily details."
            case .periodEnded: "Review the recorded end and correct it if needed."
            case .symptom: "Open your symptom check-in."
            case .missedLog: "Update Cecy if you have something to record. No answer is assumed."
            case .treatment: "Review your medication or contraception check-in."
            }
        }
    }
    let kind: Kind
    let hour: Int
    let minute: Int
    let day: LocalDay?
    var showDetails = false
    var contextID: String?
    var id: String { "cecy.reminder.\(kind.rawValue)" + (contextID.map { ".\($0)" } ?? "") }
    var deepLink: String { kind == .window ? "cecy://forecast" : "cecy://check-in" }
    static let identifierPrefix = "cecy.reminder."
}

nonisolated enum ReminderPlanner {
    static func requests(preferences: PrivacyPreferences, prediction: CyclePrediction?, now: Date, timeZone: TimeZone,
                         periods: [Period] = [], treatments: [TreatmentRecord] = []) throws -> [ReminderRequest] {
        try preferences.validate()
        var requests: [ReminderRequest] = []
        let today = try LocalDay(date: now, timeZone: timeZone)
        let snoozedUntil = try preferences.remindersSnoozedUntilDay.map(LocalDay.init(key:))
        // The stored day is when delivery resumes, not the final suppressed day.
        let snoozed = snoozedUntil.map { today < $0 } ?? false
        func details(_ kind: ReminderRequest.Kind) -> Bool {
            preferences.reminderDetailsByKind?[kind.rawValue] ?? (preferences.reminderDetailsEnabled == true)
        }
        if preferences.dailyReminder && !snoozed {
            requests.append(ReminderRequest(kind: .daily, hour: preferences.reminderHour, minute: preferences.reminderMinute, day: nil,
                                            showDetails: details(.daily)))
        }
        if preferences.symptomReminderKinds?.isEmpty == false && !snoozed {
            requests.append(ReminderRequest(kind: .symptom, hour: preferences.reminderHour, minute: preferences.reminderMinute,
                                            day: nil, showDetails: details(.symptom)))
        }
        if preferences.missedLogReminder == true && !snoozed {
            requests.append(ReminderRequest(kind: .missedLog, hour: preferences.reminderHour, minute: preferences.reminderMinute,
                                            day: nil, showDetails: details(.missedLog)))
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
                requests.append(ReminderRequest(kind: .window, hour: components.hour!, minute: components.minute!, day: day,
                                                showDetails: details(.window)))
            }
        }
        if preferences.periodFollowUpReminder == true {
            for period in periods.suffix(2) {
                var events: [(ReminderRequest.Kind, LocalDay)] = [(.periodStarted, period.start)]
                if let end = period.end { events.append((.periodEnded, end)) }
                for (kind, event) in events {
                    let followUp = try event.adding(days: 1)
                    if followUp >= today {
                        requests.append(ReminderRequest(kind: kind, hour: preferences.reminderHour, minute: preferences.reminderMinute,
                            day: followUp, showDetails: details(kind), contextID: String(event.key)))
                    }
                }
            }
        }
        if !snoozed {
            for treatment in treatments where treatment.reminderEnabled && treatment.start <= today && (treatment.end.map { today <= $0 } ?? true) {
                requests.append(ReminderRequest(kind: .treatment, hour: treatment.reminderHour, minute: treatment.reminderMinute,
                    day: treatment.cadence == .daily ? nil : nextTreatmentDay(treatment, today: today),
                    showDetails: details(.treatment), contextID: treatment.id.uuidString))
            }
        }
        return requests
    }

    private static func nextTreatmentDay(_ treatment: TreatmentRecord, today: LocalDay) -> LocalDay? {
        guard let interval = treatment.cadence.dayInterval else { return nil }
        let elapsed = max(0, treatment.start.days(until: today))
        let remaining = (interval - elapsed % interval) % interval
        return try? today.adding(days: remaining)
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
        let dailyBleeding: [DailyBleedingRecord]?
        let cycleFactors: [CycleFactorRecord]?
        let treatments: [TreatmentRecordExport]?
        let treatmentAdherence: [TreatmentAdherenceRecord]?
        var lifeStages: [LifeStageRecord]? = nil
        var postpartumBleeding: [PostpartumBleedingRecord]? = nil
        var biomarkers: [BiomarkerRecord]? = nil
        var insightFeedback: [InsightFeedbackRecord]? = nil
    }
    struct LifeStageRecord: Codable {
        let id: UUID
        let kind: String
        let start: String
        let end: String?
        let feedingContext: String?
        let forecastExclusion: Bool?
        let notes: String?
        let createdAtReference: Double
        let updatedAtReference: Double
    }
    struct PostpartumBleedingRecord: Codable {
        let id: UUID
        let date: String
        let state: String
        let flow: String?
        let notes: String?
        let createdAtReference: Double
        let updatedAtReference: Double
    }
    struct BiomarkerRecord: Codable {
        let id: UUID
        let date: String
        let type: String
        let value: Double?
        let unit: String?
        let result: String?
        let provenance: String
        let sourceName: String?
        let notes: String?
        let createdAtReference: Double
        let updatedAtReference: Double
    }
    struct InsightFeedbackRecord: Codable {
        let insightID: String
        let helpful: Bool
        let reasons: [String]
        let updatedAtReference: Double
    }
    struct ProfileRecord: Codable {
        let preferredName: String
        let dateOfBirth: String?
        let measurementSystem: String
        let heightCentimeters: Double?
        let weightKilograms: Double?
        let cyclePredictability: String
        let typicalPeriodDays: Int?
        let typicalCycleDays: Int?
        let commonSymptoms: [String]
        let cycleContext: [String]
        let goals: [String]
        let wellnessPreferences: WellnessRecord?
        let genderIdentity: String?
        let sexualPartners: [String]?

        init(_ profile: LocalProfile, includeSexualInformation: Bool = false) throws {
            try profile.validate()
            preferredName = profile.preferredName
            dateOfBirth = try profile.birthDayKey.map { civilDate(try LocalDay(key: $0)) }
            measurementSystem = profile.measurementSystem.rawValue
            heightCentimeters = profile.heightCentimeters
            weightKilograms = profile.weightKilograms
            cyclePredictability = profile.predictability.rawValue
            typicalPeriodDays = profile.typicalPeriodDays
            typicalCycleDays = profile.typicalCycleDays
            commonSymptoms = profile.commonSymptoms.map(\.rawValue).sorted()
            cycleContext = profile.cycleContext.map(\.rawValue).sorted()
            goals = profile.goals.map(\.rawValue).sorted()
            wellnessPreferences = profile.wellnessPreferences.map(WellnessRecord.init)
            genderIdentity = profile.genderIdentity?.rawValue
            sexualPartners = includeSexualInformation ? profile.sexualPartners.map { $0.map(\.rawValue).sorted() } : nil
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
        let createdAtReference: Double?
        let updatedAtReference: Double?
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
        let createdAtReference: Double?
        let updatedAtReference: Double?
    }
    struct SexualActivityRecord: Codable {
        let id: UUID
        let date: String
        let activities: [String]
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
        let createdAtReference: Double?
        let updatedAtReference: Double?
    }
    struct DailyBleedingRecord: Codable {
        let id: UUID
        let date: String
        let state: String
        let flow: String?
        let periodID: UUID?
        let createdAt: Date
        let updatedAt: Date
        let createdAtReference: Double?
        let updatedAtReference: Double?
    }
    struct CycleFactorRecord: Codable {
        let id: UUID
        let kind: String
        let start: String
        let end: String?
        let excludesFromForecast: Bool
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
        let createdAtReference: Double?
        let updatedAtReference: Double?
    }
    struct TreatmentRecordExport: Codable {
        let id: UUID
        let category: String
        let name: String
        let dose: String?
        let contraceptionType: String?
        let start: String
        let end: String?
        let cadence: String
        let reminderEnabled: Bool
        let reminderHour: Int
        let reminderMinute: Int
        let createdAt: Date
        let updatedAt: Date
        let createdAtReference: Double?
        let updatedAtReference: Double?
    }
    struct TreatmentAdherenceRecord: Codable {
        let id: UUID
        let treatmentID: UUID
        let date: String
        let state: String
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
        let createdAtReference: Double?
        let updatedAtReference: Double?
    }
    static func civilDate(_ day: LocalDay) -> String {
        String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"), day.year, day.month, day.day)
    }
    static func encode(snapshot: TrackerSnapshot, includeNotes: Bool, generatedAt: Date, includeProfile: Bool = false,
                       includeSexualActivity: Bool = false) throws -> Data {
        try PeriodValidation.validate(snapshot.periods)
        try SymptomValidation.validate(snapshot.symptoms)
        try SexualActivityValidation.validate(snapshot.sexualActivities)
        try DailyBleedingValidation.validate(snapshot.dailyBleeding, periods: snapshot.periods)
        guard generatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
        let includesIdentity = includeProfile && (snapshot.profile?.genderIdentity != nil || (includeSexualActivity && snapshot.profile?.sexualPartners != nil))
        try P2RecordValidation.validate(snapshot.p2)
        let version = !snapshot.p2.isEmpty ? 9
            : !snapshot.cycleFactors.isEmpty || !snapshot.treatments.isEmpty || !snapshot.treatmentAdherence.isEmpty ? 8
            : !snapshot.dailyBleeding.isEmpty ? 7 : includeProfile && snapshot.profile?.typicalCycleDays != nil ? 6
            : includesIdentity ? 5 : (includeProfile && snapshot.profile?.wellnessPreferences != nil ? 4 : (includeSexualActivity ? 3 : (includeProfile ? 2 : 1)))
        var document = Document(formatVersion: version, generatedAt: generatedAt, includesPrivateNotes: includeNotes,
            periods: snapshot.periods.sorted { $0.start < $1.start }.map {
                PeriodRecord(id: $0.id, start: civilDate($0.start), end: $0.end.map(civilDate), flow: $0.flow?.rawValue,
                    notes: includeNotes ? $0.notes : nil, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }, observations: SymptomValidation.sorted(snapshot.symptoms).map {
                ObservationRecord(id: $0.id, date: civilDate($0.day), type: $0.kind.rawValue, rating: $0.value,
                    ratingLabel: $0.ratingLabel, notes: includeNotes ? $0.notes : nil,
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }, profile: includeProfile ? try snapshot.profile.map { try ProfileRecord($0, includeSexualInformation: includeSexualActivity) } : nil,
            sexualActivities: includeSexualActivity ? SexualActivityValidation.sorted(snapshot.sexualActivities).map {
                SexualActivityRecord(id: $0.id, date: civilDate($0.day), activities: $0.orderedActivities.map(\.rawValue),
                    notes: includeNotes ? $0.notes : nil, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            } : nil,
            dailyBleeding: snapshot.dailyBleeding.isEmpty ? nil : DailyBleedingValidation.sorted(snapshot.dailyBleeding).map {
                DailyBleedingRecord(id: $0.id, date: civilDate($0.day), state: $0.state.rawValue, flow: $0.flow?.rawValue,
                    periodID: $0.periodID, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }, cycleFactors: snapshot.cycleFactors.isEmpty ? nil : P1RecordValidation.sorted(snapshot.cycleFactors).map {
                CycleFactorRecord(id: $0.id, kind: $0.kind.rawValue, start: civilDate($0.start), end: $0.end.map(civilDate),
                    excludesFromForecast: $0.excludesFromForecast, notes: includeNotes ? $0.notes : nil,
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }, treatments: snapshot.treatments.isEmpty ? nil : P1RecordValidation.sorted(snapshot.treatments).map {
                TreatmentRecordExport(id: $0.id, category: $0.category.rawValue, name: $0.name,
                    dose: $0.dose, contraceptionType: $0.contraceptionType?.rawValue, start: civilDate($0.start),
                    end: $0.end.map(civilDate), cadence: $0.cadence.rawValue, reminderEnabled: $0.reminderEnabled,
                    reminderHour: $0.reminderHour, reminderMinute: $0.reminderMinute,
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }, treatmentAdherence: snapshot.treatmentAdherence.isEmpty ? nil : P1RecordValidation.sorted(snapshot.treatmentAdherence).map {
                TreatmentAdherenceRecord(id: $0.id, treatmentID: $0.treatmentID, date: civilDate($0.day),
                    state: $0.state.rawValue, notes: includeNotes ? $0.notes : nil,
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            })
        let p2 = P2RecordValidation.sorted(snapshot.p2)
        if !p2.lifeStages.isEmpty {
            document.lifeStages = p2.lifeStages.map {
                LifeStageRecord(id: $0.id, kind: $0.kind.rawValue, start: civilDate($0.start), end: $0.end.map(civilDate),
                    feedingContext: $0.feedingContext?.rawValue, forecastExclusion: $0.forecastExclusion,
                    notes: includeNotes ? $0.notes : nil,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }
        }
        if !p2.postpartumBleeding.isEmpty {
            document.postpartumBleeding = p2.postpartumBleeding.map {
                PostpartumBleedingRecord(id: $0.id, date: civilDate($0.day), state: $0.state.rawValue, flow: $0.flow?.rawValue,
                    notes: includeNotes ? $0.notes : nil,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }
        }
        if !p2.biomarkers.isEmpty {
            document.biomarkers = p2.biomarkers.map {
                BiomarkerRecord(id: $0.id, date: civilDate($0.day), type: $0.kind.rawValue, value: $0.numericValue,
                    unit: $0.numericValue == nil ? nil : $0.kind.unit, result: $0.result?.rawValue,
                    provenance: $0.provenance.rawValue, sourceName: $0.sourceName, notes: includeNotes ? $0.notes : nil,
                    createdAtReference: $0.createdAt.timeIntervalSinceReferenceDate,
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }
        }
        if !p2.insightFeedback.isEmpty {
            document.insightFeedback = p2.insightFeedback.map {
                InsightFeedbackRecord(insightID: $0.insightID, helpful: $0.helpful,
                    reasons: $0.reasons.map(\.rawValue).sorted(),
                    updatedAtReference: $0.updatedAt.timeIntervalSinceReferenceDate)
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(document)
    }
}
