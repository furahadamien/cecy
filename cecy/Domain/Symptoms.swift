import Foundation

nonisolated enum SymptomCategory: String, CaseIterable, Sendable {
    case pain = "Pain and discomfort", mood = "Mood and focus", energy = "Energy and sleep"
    case digestion = "Digestion and appetite", skin = "Skin and hair", body = "Other body changes"
    var symbol: String {
        switch self {
        case .pain: "waveform.path.ecg"
        case .mood: "brain.head.profile"
        case .energy: "moon.zzz"
        case .digestion: "fork.knife"
        case .skin: "sparkles"
        case .body: "figure.stand"
        }
    }
    var kinds: [SymptomKind] { SymptomKind.allCases.filter { $0.category == self } }
}

nonisolated enum SymptomKind: String, CaseIterable, Sendable {
    case cramps, headache, bloating, fatigue, moodChanges, acne, backPain, nausea
    case breastTenderness, sleepQuality, energyLevel, cravings, digestiveChanges
    case pelvicPain, jointPain, muscleAches, breastSwelling
    case anxiety, irritability, lowMood, moodSwings, difficultyConcentrating
    case insomnia, dizziness, brainFog
    case constipation, diarrhea, appetiteChanges, vomiting
    case oilySkin, drySkin, hairChanges
    case hotFlashes, nightSweats, dischargeChanges, vaginalDryness, vaginalItching, urinaryDiscomfort, libido

    var category: SymptomCategory {
        switch self {
        case .cramps, .headache, .backPain, .breastTenderness, .pelvicPain, .jointPain, .muscleAches, .breastSwelling: .pain
        case .moodChanges, .anxiety, .irritability, .lowMood, .moodSwings, .difficultyConcentrating, .brainFog: .mood
        case .fatigue, .sleepQuality, .energyLevel, .insomnia, .dizziness: .energy
        case .bloating, .nausea, .cravings, .digestiveChanges, .constipation, .diarrhea, .appetiteChanges, .vomiting: .digestion
        case .acne, .oilySkin, .drySkin, .hairChanges: .skin
        case .hotFlashes, .nightSweats, .dischargeChanges, .vaginalDryness, .vaginalItching, .urinaryDiscomfort, .libido: .body
        }
    }

    var title: String {
        switch self {
        case .cramps: "Cramps"
        case .headache: "Headache"
        case .bloating: "Bloating"
        case .fatigue: "Fatigue"
        case .moodChanges: "Mood changes"
        case .acne: "Acne"
        case .backPain: "Back pain"
        case .nausea: "Nausea"
        case .breastTenderness: "Breast tenderness"
        case .sleepQuality: "Sleep quality"
        case .energyLevel: "Energy level"
        case .cravings: "Cravings"
        case .digestiveChanges: "Digestive changes"
        case .pelvicPain: "Pelvic pain"
        case .jointPain: "Joint pain"
        case .muscleAches: "Muscle aches"
        case .breastSwelling: "Breast swelling"
        case .anxiety: "Anxiety"
        case .irritability: "Irritability"
        case .lowMood: "Low mood"
        case .moodSwings: "Mood swings"
        case .difficultyConcentrating: "Difficulty concentrating"
        case .insomnia: "Difficulty sleeping"
        case .dizziness: "Dizziness"
        case .brainFog: "Brain fog"
        case .constipation: "Constipation"
        case .diarrhea: "Diarrhea"
        case .appetiteChanges: "Appetite changes"
        case .vomiting: "Vomiting"
        case .oilySkin: "Oily skin"
        case .drySkin: "Dry skin"
        case .hairChanges: "Hair changes"
        case .hotFlashes: "Hot flashes"
        case .nightSweats: "Night sweats"
        case .dischargeChanges: "Discharge changes"
        case .vaginalDryness: "Vaginal dryness"
        case .vaginalItching: "Vaginal itching"
        case .urinaryDiscomfort: "Urinary discomfort"
        case .libido: "Sex drive"
        }
    }

    var symbol: String {
        switch self {
        case .cramps: "waveform.path.ecg"
        case .headache: "brain.head.profile"
        case .bloating: "arrow.left.and.right"
        case .fatigue: "battery.25percent"
        case .moodChanges: "theatermasks"
        case .acne: "circle.dotted"
        case .backPain: "figure.stand"
        case .nausea: "water.waves"
        case .breastTenderness: "heart"
        case .sleepQuality: "moon.zzz"
        case .energyLevel: "bolt"
        case .cravings: "fork.knife"
        case .digestiveChanges: "waveform.path"
        default: category.symbol
        }
    }

    var usesSeverity: Bool { self != .sleepQuality && self != .energyLevel && self != .libido }
    var ratingTitle: String { usesSeverity ? "Severity (optional)" : "Rating (optional)" }
    var ratingLabels: [String] {
        switch self {
        case .sleepQuality: ["Poor", "Fair", "Good"]
        case .energyLevel, .libido: ["Low", "Typical", "High"]
        default: ["Mild", "Moderate", "Severe"]
        }
    }
    var timingTitle: String {
        switch self {
        case .sleepQuality: "Poor sleep"
        case .energyLevel: "Low energy"
        case .libido: "Low sex drive"
        default: title
        }
    }
    func qualifiesForTiming(value: Int?) -> Bool {
        self == .sleepQuality || self == .energyLevel || self == .libido ? value == 1 : true
    }
}

nonisolated struct SymptomEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    var day: LocalDay
    var kind: SymptomKind
    var value: Int?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), day: LocalDay, kind: SymptomKind, value: Int? = nil,
         notes: String? = nil, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.kind = kind
        self.value = value
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var ratingLabel: String? {
        guard let value, (1...3).contains(value) else { return nil }
        return kind.ratingLabels[value - 1]
    }
}

nonisolated enum SymptomValidation {
    static func validate(_ entries: [SymptomEntry], asOf today: LocalDay? = nil) throws {
        guard Set(entries.map(\.id)).count == entries.count else { throw TrackingError.invalidData }
        var daysByKind: [SymptomKind: Set<LocalDay>] = [:]
        for entry in entries {
            guard entry.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt >= entry.createdAt else { throw TrackingError.invalidData }
            if let value = entry.value, !(1...3).contains(value) { throw TrackingError.invalidRating }
            if (entry.notes?.count ?? 0) > PeriodValidation.maximumNoteLength { throw TrackingError.noteTooLong }
            if let today, entry.day > today { throw TrackingError.futureDate }
            guard daysByKind[entry.kind, default: []].insert(entry.day).inserted else { throw TrackingError.duplicateSymptom }
        }
    }

    static func sorted(_ entries: [SymptomEntry]) -> [SymptomEntry] {
        entries.sorted { $0.day == $1.day ? $0.kind.rawValue < $1.kind.rawValue : $0.day < $1.day }
    }
}
