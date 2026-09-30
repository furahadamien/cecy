import Foundation

nonisolated enum SymptomKind: String, CaseIterable, Sendable {
    case cramps, headache, bloating, fatigue, moodChanges, acne, backPain, nausea
    case breastTenderness, sleepQuality, energyLevel, cravings

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
        }
    }

    var symbol: String {
        switch self {
        case .cramps: "waveform.path.ecg"
        case .headache: "head.profile"
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
        }
    }

    var ratingTitle: String { self == .sleepQuality || self == .energyLevel ? "Rating (optional)" : "Severity (optional)" }
    var ratingLabels: [String] {
        switch self {
        case .sleepQuality: ["Poor", "Fair", "Good"]
        case .energyLevel: ["Low", "Typical", "High"]
        default: ["Mild", "Moderate", "Severe"]
        }
    }
    var timingTitle: String {
        switch self {
        case .sleepQuality: "Poor sleep"
        case .energyLevel: "Low energy"
        default: title
        }
    }
    func qualifiesForTiming(value: Int?) -> Bool {
        self == .sleepQuality || self == .energyLevel ? value == 1 : true
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
