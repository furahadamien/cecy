import Foundation

nonisolated enum ImportConflictStrategy: String, CaseIterable, Sendable {
    case keepExisting, useImported, newestUpdate
    var title: String {
        switch self {
        case .keepExisting: "Keep existing"
        case .useImported: "Use imported"
        case .newestUpdate: "Use newest update"
        }
    }
}

nonisolated struct TrackerImportPreview: Sendable {
    let snapshot: TrackerSnapshot
    let formatVersion: Int
    let added: Int
    let duplicates: Int
    let conflicts: Int
}

nonisolated enum TrackerImport {
    static func preview(data: Data, existing: TrackerSnapshot, today: LocalDay,
                        strategy: ImportConflictStrategy) throws -> TrackerImportPreview {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let dot = text.firstIndex(of: "."), text.hasSuffix("Z") {
                let wholeText = String(text[..<dot]) + "Z"
                let fractionText = text[text.index(after: dot)..<text.index(before: text.endIndex)]
                if let whole = standard.date(from: wholeText), let fraction = Double("0." + fractionText) {
                    return whole.addingTimeInterval(fraction)
                }
            }
            if let date = standard.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid ISO-8601 date"))
        }
        let document = try decoder.decode(TrackerExport.Document.self, from: data)
        guard (1...8).contains(document.formatVersion) else { throw TrackingError.invalidData }
        var added = 0, duplicates = 0, conflicts = 0

        let importedPeriods = try document.periods.map {
            Period(id: $0.id, start: try day($0.start), end: try $0.end.map(day),
                   flow: try optionalRaw($0.flow, PeriodFlow.init(rawValue:)), notes: $0.notes,
                   createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }
        let importedSymptoms = try document.observations.map {
            guard let kind = SymptomKind(rawValue: $0.type) else { throw TrackingError.invalidData }
            return try SymptomEntry(id: $0.id, day: day($0.date), kind: kind, value: $0.rating,
                                    notes: $0.notes, createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }
        let importedSexual = try (document.sexualActivities ?? []).map {
            let values = Set($0.activities.compactMap(SexualActivityKind.init(rawValue:)))
            guard values.count == $0.activities.count else { throw TrackingError.invalidData }
            return try SexualActivityEntry(id: $0.id, day: day($0.date), activities: values,
                                           notes: $0.notes, createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }
        let importedDaily = try (document.dailyBleeding ?? []).map {
            guard let state = DailyBleedingState(rawValue: $0.state) else { throw TrackingError.invalidData }
            return try DailyBleedingObservation(id: $0.id, day: day($0.date), state: state,
                flow: try optionalRaw($0.flow, PeriodFlow.init(rawValue:)), periodID: $0.periodID,
                createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }
        let importedFactors = try (document.cycleFactors ?? []).map {
            guard let kind = CycleFactorKind(rawValue: $0.kind) else { throw TrackingError.invalidData }
            return CycleFactor(id: $0.id, kind: kind, start: try day($0.start), end: try $0.end.map(day),
                excludesFromForecast: $0.excludesFromForecast, notes: $0.notes,
                createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }
        let importedTreatments = try (document.treatments ?? []).map {
            guard let category = TreatmentCategory(rawValue: $0.category),
                  let cadence = TreatmentCadence(rawValue: $0.cadence) else { throw TrackingError.invalidData }
            let method = try optionalRaw($0.contraceptionType, ContraceptionType.init(rawValue:))
            return TreatmentRecord(id: $0.id, category: category, name: $0.name, dose: $0.dose,
                contraceptionType: method, start: try day($0.start), end: try $0.end.map(day), cadence: cadence,
                reminderEnabled: $0.reminderEnabled, reminderHour: $0.reminderHour, reminderMinute: $0.reminderMinute,
                createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }
        let importedAdherence = try (document.treatmentAdherence ?? []).map {
            guard let state = AdherenceState(rawValue: $0.state) else { throw TrackingError.invalidData }
            return TreatmentAdherence(id: $0.id, treatmentID: $0.treatmentID, day: try day($0.date), state: state,
                notes: $0.notes, createdAt: exact($0.createdAt, $0.createdAtReference), updatedAt: exact($0.updatedAt, $0.updatedAtReference))
        }

        var result = existing
        result.periods = merge(existing.periods, importedPeriods, key: { $0.start.key }, updated: { $0.updatedAt },
                               strategy: strategy, added: &added, duplicates: &duplicates, conflicts: &conflicts)
        result.symptoms = merge(existing.symptoms, importedSymptoms, key: { "\($0.day.key):\($0.kind.rawValue)" }, updated: { $0.updatedAt },
                                strategy: strategy, added: &added, duplicates: &duplicates, conflicts: &conflicts)
        result.sexualActivities = merge(existing.sexualActivities, importedSexual, key: { $0.day.key }, updated: { $0.updatedAt },
                                        strategy: strategy, added: &added, duplicates: &duplicates, conflicts: &conflicts)
        result.dailyBleeding = merge(existing.dailyBleeding, importedDaily, key: { $0.day.key }, updated: { $0.updatedAt },
                                     strategy: strategy, added: &added, duplicates: &duplicates, conflicts: &conflicts)
        result.cycleFactors = merge(existing.cycleFactors, importedFactors, key: { $0.id }, updated: { $0.updatedAt },
                                    strategy: strategy, added: &added, duplicates: &duplicates, conflicts: &conflicts)
        result.treatments = merge(existing.treatments, importedTreatments, key: { $0.id }, updated: { $0.updatedAt },
                                  strategy: strategy, added: &added, duplicates: &duplicates, conflicts: &conflicts)
        result.treatmentAdherence = merge(existing.treatmentAdherence, importedAdherence,
            key: { "\($0.treatmentID):\($0.day.key)" }, updated: { $0.updatedAt }, strategy: strategy,
            added: &added, duplicates: &duplicates, conflicts: &conflicts)
        if let profileRecord = document.profile {
            let imported = try profile(profileRecord, id: existing.profile?.id ?? UUID())
            if let current = existing.profile {
                if current == imported { duplicates += 1 }
                else {
                    conflicts += 1
                    if strategy == .useImported { result.profile = imported }
                }
            } else { result.profile = imported; added += 1 }
        }
        result.onboardingProgress = nil
        try PeriodValidation.validate(result.periods, asOf: today)
        try SymptomValidation.validate(result.symptoms, asOf: today)
        try SexualActivityValidation.validate(result.sexualActivities, asOf: today)
        try DailyBleedingValidation.validate(result.dailyBleeding, periods: result.periods, asOf: today)
        try P1RecordValidation.validate(factors: result.cycleFactors, treatments: result.treatments,
                                        adherence: result.treatmentAdherence, asOf: today)
        return TrackerImportPreview(snapshot: result, formatVersion: document.formatVersion,
                                    added: added, duplicates: duplicates, conflicts: conflicts)
    }

    private static func merge<Value: Equatable, Key: Hashable>(_ existing: [Value], _ imported: [Value],
        key: (Value) -> Key, updated: (Value) -> Date, strategy: ImportConflictStrategy,
        added: inout Int, duplicates: inout Int, conflicts: inout Int) -> [Value] {
        var result = existing
        for value in imported {
            if let index = result.firstIndex(where: { key($0) == key(value) }) {
                if result[index] == value { duplicates += 1; continue }
                conflicts += 1
                if strategy == .useImported || (strategy == .newestUpdate && updated(value) > updated(result[index])) {
                    result[index] = value
                }
            } else { result.append(value); added += 1 }
        }
        return result
    }

    private static func exact(_ fallback: Date, _ reference: Double?) -> Date {
        guard let reference, reference.isFinite else { return fallback }
        return Date(timeIntervalSinceReferenceDate: reference)
    }

    private static func day(_ text: String) throws -> LocalDay {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw TrackingError.invalidData }
        return try LocalDay(year: parts[0], month: parts[1], day: parts[2])
    }

    private static func optionalRaw<T>(_ value: String?, _ convert: (String) -> T?) throws -> T? {
        guard let value else { return nil }
        guard let result = convert(value) else { throw TrackingError.invalidData }
        return result
    }

    private static func profile(_ record: TrackerExport.ProfileRecord, id: UUID) throws -> LocalProfile {
        guard let measurement = MeasurementSystem(rawValue: record.measurementSystem),
              let predictability = CyclePredictability(rawValue: record.cyclePredictability) else { throw TrackingError.invalidData }
        var value = LocalProfile(id: id, preferredName: record.preferredName,
            birthDayKey: try record.dateOfBirth.map(day)?.key, measurementSystem: measurement,
            heightCentimeters: record.heightCentimeters, weightKilograms: record.weightKilograms,
            predictability: predictability, typicalPeriodDays: record.typicalPeriodDays,
            typicalCycleDays: record.typicalCycleDays)
        value.commonSymptoms = Set(record.commonSymptoms.compactMap(CommonSymptom.init(rawValue:)))
        value.cycleContext = Set(record.cycleContext.compactMap(CycleContext.init(rawValue:)))
        value.goals = Set(record.goals.compactMap(TrackingGoal.init(rawValue:)))
        guard value.commonSymptoms.count == record.commonSymptoms.count,
              value.cycleContext.count == record.cycleContext.count,
              value.goals.count == record.goals.count else { throw TrackingError.invalidData }
        if let raw = record.genderIdentity {
            guard let gender = GenderIdentity(rawValue: raw) else { throw TrackingError.invalidData }
            value.genderIdentity = gender
        }
        if let raw = record.sexualPartners {
            let partners = Set(raw.compactMap(SexualPartnerPreference.init(rawValue:)))
            guard partners.count == raw.count else { throw TrackingError.invalidData }
            value.sexualPartners = partners
        }
        if let wellness = record.wellnessPreferences {
            guard let allergy = FoodAllergyStatus(rawValue: wellness.foodAllergyStatus) else { throw TrackingError.invalidData }
            let exercises = wellness.preferredExercises.map { Set($0.compactMap(PreferredExercise.init(rawValue:))) }
            let goals = wellness.goals.map { Set($0.compactMap(WellnessGoal.init(rawValue:))) }
            value.wellnessPreferences = WellnessPreferences(
                activityLevel: wellness.activityLevel.flatMap(ActivityLevel.init(rawValue:)),
                preferredExercises: exercises,
                dietaryPreference: wellness.dietaryPreference.flatMap(DietaryPreference.init(rawValue:)),
                foodAllergyStatus: allergy, foodAllergies: wellness.foodAllergies, goals: goals)
        }
        try value.validate()
        return value
    }
}
