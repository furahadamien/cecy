import Foundation

nonisolated enum CycleFactorKind: String, Codable, CaseIterable, Sendable {
    case pregnancy, pregnancyLoss, postpartum, breastfeeding, perimenopause
    case hormonalContraception, nonHormonalContraception, stoppedContraception
    case illness, stress, travel, possibleMissedRecord

    var title: String {
        switch self {
        case .pregnancy: "Pregnancy"
        case .pregnancyLoss: "Pregnancy loss"
        case .postpartum: "Postpartum"
        case .breastfeeding: "Breastfeeding"
        case .perimenopause: "Perimenopause"
        case .hormonalContraception: "Hormonal contraception"
        case .nonHormonalContraception: "Non-hormonal contraception"
        case .stoppedContraception: "Stopped contraception"
        case .illness: "Illness"
        case .stress: "Stress"
        case .travel: "Travel"
        case .possibleMissedRecord: "Possible missed record"
        }
    }

    var defaultExcludesForecast: Bool {
        switch self {
        case .pregnancy, .pregnancyLoss, .postpartum, .breastfeeding,
             .hormonalContraception, .stoppedContraception, .possibleMissedRecord: true
        case .perimenopause, .nonHormonalContraception, .illness, .stress, .travel: false
        }
    }
}

nonisolated struct CycleFactor: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var kind: CycleFactorKind
    var start: LocalDay
    var end: LocalDay?
    var excludesFromForecast: Bool
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), kind: CycleFactorKind, start: LocalDay, end: LocalDay? = nil,
         excludesFromForecast: Bool? = nil, notes: String? = nil,
         createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.excludesFromForecast = excludesFromForecast ?? kind.defaultExcludesForecast
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    func overlaps(start intervalStart: LocalDay, end intervalEnd: LocalDay) -> Bool {
        start <= intervalEnd && (end ?? intervalEnd) >= intervalStart
    }
}

nonisolated enum TreatmentCategory: String, Codable, CaseIterable, Sendable {
    case contraception, medication, supplement
    var title: String { rawValue.capitalized }
}

nonisolated enum ContraceptionType: String, Codable, CaseIterable, Sendable {
    case pill, ring, patch, shot, implant, hormonalIUD, copperIUD, barrier, other
    var title: String {
        switch self {
        case .hormonalIUD: "Hormonal IUD"
        case .copperIUD: "Copper IUD"
        default: rawValue.capitalized
        }
    }
    var factorKind: CycleFactorKind {
        switch self {
        case .copperIUD, .barrier: .nonHormonalContraception
        default: .hormonalContraception
        }
    }
}

nonisolated enum TreatmentCadence: String, Codable, CaseIterable, Sendable {
    case daily, weekly, everyFourWeeks, everyTwelveWeeks, asNeeded
    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .everyFourWeeks: "Every 4 weeks"
        case .everyTwelveWeeks: "Every 12 weeks"
        case .asNeeded: "As needed"
        }
    }
    var dayInterval: Int? {
        switch self {
        case .daily: 1
        case .weekly: 7
        case .everyFourWeeks: 28
        case .everyTwelveWeeks: 84
        case .asNeeded: nil
        }
    }
}

nonisolated struct TreatmentRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var category: TreatmentCategory
    var name: String
    var dose: String?
    var contraceptionType: ContraceptionType?
    var start: LocalDay
    var end: LocalDay?
    var cadence: TreatmentCadence
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), category: TreatmentCategory, name: String, dose: String? = nil,
         contraceptionType: ContraceptionType? = nil, start: LocalDay, end: LocalDay? = nil,
         cadence: TreatmentCadence = .daily, reminderEnabled: Bool = false,
         reminderHour: Int = 20, reminderMinute: Int = 0,
         createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.category = category
        self.name = name
        self.dose = dose
        self.contraceptionType = contraceptionType
        self.start = start
        self.end = end
        self.cadence = cadence
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

nonisolated enum AdherenceState: String, Codable, CaseIterable, Sendable {
    case taken, late, missed, skipped
    var title: String { rawValue.capitalized }
}

nonisolated struct TreatmentAdherence: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let treatmentID: UUID
    var day: LocalDay
    var state: AdherenceState
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), treatmentID: UUID, day: LocalDay, state: AdherenceState,
         notes: String? = nil, createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.treatmentID = treatmentID
        self.day = day
        self.state = state
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

nonisolated enum P1RecordValidation {
    static func validate(factors: [CycleFactor], treatments: [TreatmentRecord],
                         adherence: [TreatmentAdherence], asOf today: LocalDay? = nil) throws {
        guard Set(factors.map(\.id)).count == factors.count,
              Set(treatments.map(\.id)).count == treatments.count,
              Set(adherence.map(\.id)).count == adherence.count else { throw TrackingError.invalidData }
        for value in factors {
            guard value.end.map({ $0 >= value.start }) ?? true,
                  (value.notes?.count ?? 0) <= PeriodValidation.maximumNoteLength,
                  value.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  value.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
            if let today, value.start > today || (value.end.map { $0 > today } ?? false) { throw TrackingError.futureDate }
        }
        for value in treatments {
            let name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 120, (value.dose?.count ?? 0) <= 120,
                  value.end.map({ $0 >= value.start }) ?? true,
                  (0...23).contains(value.reminderHour), (0...59).contains(value.reminderMinute),
                  value.category == .contraception ? value.contraceptionType != nil : value.contraceptionType == nil,
                  value.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  value.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
            if let today, value.start > today || (value.end.map { $0 > today } ?? false) { throw TrackingError.futureDate }
        }
        let treatmentIDs = Set(treatments.map(\.id))
        for value in adherence {
            guard treatmentIDs.contains(value.treatmentID),
                  (value.notes?.count ?? 0) <= PeriodValidation.maximumNoteLength,
                  value.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  value.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
            if let today, value.day > today { throw TrackingError.futureDate }
        }
        let uniqueDaily = Set(adherence.map { "\($0.treatmentID.uuidString):\($0.day.key)" })
        guard uniqueDaily.count == adherence.count else { throw TrackingError.invalidData }
    }

    static func sorted(_ factors: [CycleFactor]) -> [CycleFactor] {
        factors.sorted { ($0.start, $0.createdAt, $0.id.uuidString) < ($1.start, $1.createdAt, $1.id.uuidString) }
    }
    static func sorted(_ treatments: [TreatmentRecord]) -> [TreatmentRecord] {
        treatments.sorted { ($0.start, $0.createdAt, $0.id.uuidString) < ($1.start, $1.createdAt, $1.id.uuidString) }
    }
    static func sorted(_ adherence: [TreatmentAdherence]) -> [TreatmentAdherence] {
        adherence.sorted { ($0.day, $0.createdAt, $0.id.uuidString) < ($1.day, $1.createdAt, $1.id.uuidString) }
    }
}

nonisolated struct OnboardingProgress: Codable, Equatable, Sendable {
    var draft: OnboardingDraft
    var stepID: String
    var updatedAt: Date
}

nonisolated struct CheckInPreferences: Codable, Equatable, Sendable {
    var pinnedSymptoms: [SymptomKind] = []
    var hiddenSymptoms: Set<SymptomKind> = []
    var showSexualActivity = true
    var showTreatments = true

    mutating func normalize() {
        var seen = Set<SymptomKind>()
        pinnedSymptoms = pinnedSymptoms.filter { seen.insert($0).inserted && !hiddenSymptoms.contains($0) }
    }
}

extension LocalDay: Codable {
    private enum CodingKeys: String, CodingKey { case key }
    nonisolated init(from decoder: Decoder) throws {
        let value = try decoder.container(keyedBy: CodingKeys.self).decode(Int.self, forKey: .key)
        try self.init(key: value)
    }
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(key, forKey: .key)
    }
}
