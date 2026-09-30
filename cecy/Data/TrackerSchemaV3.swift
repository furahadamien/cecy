import Foundation
import SwiftData

nonisolated enum TrackerSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [TrackerSchemaV2.PeriodRecord.self, TrackerSchemaV2.AppStateRecord.self, SymptomRecord.self]
    }

    @Model nonisolated final class SymptomRecord {
        var id: UUID
        var dayKey: Int
        var kindRaw: String
        var rating: Int?
        var notes: String?
        var createdAt: Date
        var updatedAt: Date

        init(_ entry: SymptomEntry) {
            id = entry.id
            dayKey = entry.day.key
            kindRaw = entry.kind.rawValue
            rating = entry.value
            notes = entry.notes
            createdAt = entry.createdAt
            updatedAt = entry.updatedAt
        }

        func value() throws -> SymptomEntry {
            guard let kind = SymptomKind(rawValue: kindRaw) else { throw TrackingError.invalidData }
            return try SymptomEntry(id: id, day: LocalDay(key: dayKey), kind: kind,
                                    value: rating, notes: notes, createdAt: createdAt, updatedAt: updatedAt)
        }
    }
}