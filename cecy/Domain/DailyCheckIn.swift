import Foundation

nonisolated struct DailyCheckInUpdate: Equatable, Sendable {
    let day: LocalDay
    let expectedBleeding: DailyBleedingObservation?
    let expectedSymptoms: [SymptomEntry]
    var bleeding: DailyBleedingObservation?
    var symptoms: [SymptomEntry]

    init(day: LocalDay, snapshot: TrackerSnapshot) {
        self.day = day
        expectedBleeding = snapshot.dailyBleeding.first { $0.day == day }
        expectedSymptoms = SymptomValidation.sorted(snapshot.symptoms.filter { $0.day == day })
        bleeding = expectedBleeding
        symptoms = expectedSymptoms
    }

    var hasAnswer: Bool { bleeding != nil || !symptoms.isEmpty }
    var hasChanges: Bool {
        bleeding != expectedBleeding || SymptomValidation.sorted(symptoms) != expectedSymptoms
    }

    mutating func setBleeding(_ state: DailyBleedingState?, flow: PeriodFlow? = nil) {
        guard let state else {
            bleeding = nil
            return
        }
        let original = expectedBleeding
        bleeding = DailyBleedingObservation(
            id: original?.id ?? bleeding?.id ?? UUID(),
            day: day,
            state: state,
            flow: state == .bleeding ? flow : nil,
            periodID: state == .bleeding ? (original?.periodID ?? bleeding?.periodID) : nil,
            createdAt: original?.createdAt ?? bleeding?.createdAt ?? Date(),
            updatedAt: original?.updatedAt ?? bleeding?.updatedAt
        )
    }

    mutating func setSymptom(_ kind: SymptomKind, selected: Bool) {
        symptoms.removeAll { $0.kind == kind }
        guard selected else { return }
        if let original = expectedSymptoms.first(where: { $0.kind == kind }) {
            symptoms.append(original)
        } else {
            symptoms.append(SymptomEntry(day: day, kind: kind))
        }
        symptoms = SymptomValidation.sorted(symptoms)
    }

    mutating func setRating(_ value: Int?, for kind: SymptomKind) {
        guard let index = symptoms.firstIndex(where: { $0.kind == kind }) else { return }
        symptoms[index].value = value
    }

    mutating func copyAnswers(from snapshot: TrackerSnapshot, previousDay: LocalDay) {
        if let prior = snapshot.dailyBleeding.first(where: { $0.day == previousDay }) {
            setBleeding(prior.state, flow: prior.flow)
        }
        symptoms = SymptomValidation.sorted(snapshot.symptoms.filter { $0.day == previousDay }.map {
            SymptomEntry(day: day, kind: $0.kind, value: $0.value)
        })
    }
}

nonisolated enum DailyCheckInError: Error, LocalizedError, Equatable {
    case empty, stale, unavailable

    var errorDescription: String? {
        switch self {
        case .empty: "Choose a bleeding answer or at least one symptom before saving."
        case .stale: "This day changed after the check-in opened. Review the latest entries and try again."
        case .unavailable: "Daily check-in isn’t available in this store. No records were changed."
        }
    }
}

extension CommonSymptom {
    nonisolated var symptomKind: SymptomKind? {
        switch self {
        case .cramps: .cramps
        case .headaches: .headache
        case .bloating: .bloating
        case .fatigue: .fatigue
        case .moodChanges: .moodChanges
        case .acne: .acne
        case .backPain: .backPain
        case .breastTenderness: .breastTenderness
        case .nausea: .nausea
        case .cravings: .cravings
        case .sleepChanges: .sleepQuality
        case .lowEnergy: .energyLevel
        case .digestiveChanges: .digestiveChanges
        case .none: nil
        }
    }
}

nonisolated enum DailyCheckInSuggestions {
    private static let defaults: [SymptomKind] = [.cramps, .headache, .bloating, .fatigue, .moodChanges, .energyLevel]

    static func symptoms(profile: LocalProfile?, existing: [SymptomEntry], recent: [SymptomEntry] = [],
                         preferences: CheckInPreferences? = nil) -> [SymptomKind] {
        let hidden = preferences?.hiddenSymptoms ?? []
        let pinned = preferences?.pinnedSymptoms ?? []
        let selected = Set(profile?.commonSymptoms.compactMap(\.symptomKind) ?? [])
        let preferred = SymptomKind.allCases.filter { selected.contains($0) }
        let base = preferred.isEmpty ? defaults : preferred
        let recentKinds = recent.sorted { $0.day > $1.day }.map(\.kind)
        let ordered = pinned + base + recentKinds + existing.map(\.kind)
        var seen = Set<SymptomKind>()
        return ordered.filter { !hidden.contains($0) && seen.insert($0).inserted }
    }
}
