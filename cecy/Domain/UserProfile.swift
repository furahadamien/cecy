import Foundation

nonisolated enum MeasurementSystem: String, Codable, CaseIterable, Sendable {
    case imperial, metric
    var title: String { rawValue.capitalized }
    func heightForDisplay(_ cm: Double) -> Double { self == .metric ? cm : cm / 2.54 }
    func weightForDisplay(_ kg: Double) -> Double { self == .metric ? kg : kg / 0.45359237 }
    func heightInCentimeters(_ value: Double) -> Double { self == .metric ? value : value * 2.54 }
    func weightInKilograms(_ value: Double) -> Double { self == .metric ? value : value * 0.45359237 }
}

nonisolated enum CyclePredictability: String, Codable, CaseIterable, Sendable {
    case usually, sometimes, rarely, notSure
    var title: String { self == .notSure ? "Not sure" : rawValue.capitalized }
}

/// Preferences, never dated observations or prediction inputs.
nonisolated enum CommonSymptom: String, Codable, CaseIterable, Sendable {
    case cramps, headaches, bloating, fatigue, moodChanges, acne, backPain
    case breastTenderness, nausea, cravings, sleepChanges, lowEnergy, none
    var title: String {
        switch self {
        case .moodChanges: "Mood changes"
        case .backPain: "Back pain"
        case .breastTenderness: "Breast tenderness"
        case .sleepChanges: "Sleep changes"
        case .lowEnergy: "Low energy"
        default: rawValue.capitalized
        }
    }

    var symbol: String {
        switch self {
        case .cramps: SymptomKind.cramps.symbol
        case .headaches: SymptomKind.headache.symbol
        case .bloating: SymptomKind.bloating.symbol
        case .fatigue: SymptomKind.fatigue.symbol
        case .moodChanges: SymptomKind.moodChanges.symbol
        case .acne: SymptomKind.acne.symbol
        case .backPain: SymptomKind.backPain.symbol
        case .breastTenderness: SymptomKind.breastTenderness.symbol
        case .nausea: SymptomKind.nausea.symbol
        case .cravings: SymptomKind.cravings.symbol
        case .sleepChanges: SymptomKind.sleepQuality.symbol
        case .lowEnergy: SymptomKind.energyLevel.symbol
        case .none: "circle.slash"
        }
    }
}

nonisolated enum CycleContext: String, Codable, CaseIterable, Sendable {
    case hormonalBirthControl, nonHormonalBirthControl, recentlyStoppedBirthControl
    case postpartum, breastfeeding, tryingToConceive, perimenopause, none, preferNotToSay
    var title: String {
        switch self {
        case .hormonalBirthControl: "Hormonal birth control"
        case .nonHormonalBirthControl: "Non-hormonal birth control"
        case .recentlyStoppedBirthControl: "Recently stopped birth control"
        case .tryingToConceive: "Trying to conceive"
        case .preferNotToSay: "Prefer not to say"
        default: rawValue.capitalized
        }
    }
}

nonisolated enum TrackingGoal: String, Codable, CaseIterable, Sendable {
    case predictPeriod, understandCycle, trackSymptoms, understandChanges, moodAndEnergy, doctorVisits, learnPatterns
    var title: String {
        switch self {
        case .predictPeriod: "Predict my next period"
        case .understandCycle: "Understand my cycle"
        case .trackSymptoms: "Track symptoms"
        case .understandChanges: "Understand changes"
        case .moodAndEnergy: "Track mood and energy"
        case .doctorVisits: "Prepare for doctor visits"
        case .learnPatterns: "Learn my patterns"
        }
    }
}

nonisolated struct LocalProfile: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    var preferredName = ""
    var birthDayKey: Int?
    var measurementSystem: MeasurementSystem = .metric
    // Canonical units prevent rounding drift when the preferred system changes.
    var heightCentimeters: Double?
    var weightKilograms: Double?
    var predictability: CyclePredictability = .notSure
    var typicalPeriodDays: Int?
    var commonSymptoms: Set<CommonSymptom> = []
    var cycleContext: Set<CycleContext> = []
    var goals: Set<TrackingGoal> = []

    mutating func toggle(_ symptom: CommonSymptom) {
        if commonSymptoms.remove(symptom) != nil { return }
        if symptom == .none { commonSymptoms = [.none] }
        else { commonSymptoms.remove(.none); commonSymptoms.insert(symptom) }
    }

    mutating func toggle(_ context: CycleContext) {
        if cycleContext.remove(context) != nil { return }
        if context == .none || context == .preferNotToSay { cycleContext = [context] }
        else { cycleContext.subtract([.none, .preferNotToSay]); cycleContext.insert(context) }
    }

    func validate(today: LocalDay? = nil, requireBasics: Bool = true) throws {
        let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count <= 80, !requireBasics || !name.isEmpty else { throw ProfileError.name }
        if let birthDayKey {
            let birthday = try LocalDay(key: birthDayKey)
            if let today, birthday > today { throw ProfileError.birthday }
        } else if requireBasics { throw ProfileError.birthday }
        if let heightCentimeters, !heightCentimeters.isFinite || !(1...300).contains(heightCentimeters) { throw ProfileError.measurement }
        if let weightKilograms, !weightKilograms.isFinite || !(1...1000).contains(weightKilograms) { throw ProfileError.measurement }
        if let typicalPeriodDays, !(1...30).contains(typicalPeriodDays) { throw ProfileError.duration }
        if commonSymptoms.contains(.none), commonSymptoms.count > 1 { throw ProfileError.selection }
        if cycleContext.contains(.none) || cycleContext.contains(.preferNotToSay), cycleContext.count > 1 { throw ProfileError.selection }
    }
}

nonisolated enum ProfileError: Error, LocalizedError {
    case name, birthday, measurement, duration, selection, fourPeriods, notReady, identity, alreadyCompleted
    var errorDescription: String? {
        switch self {
        case .name: "Enter a preferred name of up to 80 characters."
        case .birthday: "Choose your date of birth, no later than today."
        case .measurement: "Enter a valid positive height or weight, or leave it blank."
        case .duration: "Choose a period length between 1 and 30 days."
        case .selection: "Choose None or Prefer not to say on its own."
        case .fourPeriods: "Add at least four period starts. Estimates are okay."
        case .notReady: "Unlock Cecy and try again. Your setup has not finished."
        case .identity: "Sign in with the Apple Account linked to this local profile. To change accounts, first delete the local profile and records in Settings."
        case .alreadyCompleted: "Setup is already complete. Edit your profile in Settings."
        }
    }
}

nonisolated struct OnboardingDraft: Equatable, Sendable {
    var profile = LocalProfile()
    var periods: [Period] = []
    var dailyReminder = false
    var windowReminder = false
    var reminderHour = 20
    var reminderMinute = 0

    func validate(today: LocalDay) throws {
        try profile.validate(today: today)
        guard profile.typicalPeriodDays != nil else { throw ProfileError.duration }
        guard periods.count >= 4 else { throw ProfileError.fourPeriods }
        try PeriodValidation.validate(periods, asOf: today)
        guard (0...23).contains(reminderHour), (0...59).contains(reminderMinute) else { throw TrackingError.invalidData }
    }

    func overview(today: LocalDay) -> CycleOverview {
        CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine())
    }
    func statistics(today: LocalDay) -> CycleStatistics? {
        try? CycleStatistics.calculate(periods: periods, today: today)
    }
}
