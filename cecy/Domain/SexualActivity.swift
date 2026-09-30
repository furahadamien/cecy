import Foundation

/// Private daily records, never inputs to cycle or fertility predictions.
nonisolated enum SexualActivityKind: String, CaseIterable, Sendable {
    case vaginalSex, oralSex, analSex, masturbation, other

    var title: String {
        switch self {
        case .vaginalSex: "Vaginal sex"
        case .oralSex: "Oral sex"
        case .analSex: "Anal sex"
        case .masturbation: "Masturbation"
        case .other: "Other activity"
        }
    }
}

nonisolated struct SexualActivityEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    var day: LocalDay
    var activities: Set<SexualActivityKind>
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), day: LocalDay, activities: Set<SexualActivityKind>, notes: String? = nil,
         createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.activities = activities
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var orderedActivities: [SexualActivityKind] { SexualActivityKind.allCases.filter { activities.contains($0) } }
    var summary: String { orderedActivities.map(\.title).joined(separator: ", ") }
}

nonisolated enum SexualActivityError: Error, LocalizedError {
    case empty, duplicateDay

    var errorDescription: String? {
        switch self {
        case .empty: "Choose at least one activity."
        case .duplicateDay: "Sexual activity is already recorded for this day. Edit that daily record to add or remove activities."
        }
    }
}

nonisolated enum SexualActivityValidation {
    static func validate(_ entries: [SexualActivityEntry], asOf today: LocalDay? = nil) throws {
        guard Set(entries.map(\.id)).count == entries.count else { throw TrackingError.invalidData }
        var days: Set<LocalDay> = []
        for entry in entries {
            guard !entry.activities.isEmpty else { throw SexualActivityError.empty }
            guard entry.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt >= entry.createdAt else { throw TrackingError.invalidData }
            if let today, entry.day > today { throw TrackingError.futureDate }
            if (entry.notes?.count ?? 0) > PeriodValidation.maximumNoteLength { throw TrackingError.noteTooLong }
            guard days.insert(entry.day).inserted else { throw SexualActivityError.duplicateDay }
        }
    }

    static func sorted(_ entries: [SexualActivityEntry]) -> [SexualActivityEntry] {
        entries.sorted { $0.day < $1.day }
    }
}
