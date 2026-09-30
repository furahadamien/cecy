import Foundation
import SwiftData

nonisolated enum TrackerSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
    static var models: [any PersistentModel.Type] {
        TrackerSchemaV4.models + [SexualActivityRecord.self]
    }

    @Model nonisolated final class SexualActivityRecord {
        var id: UUID
        var dayKey: Int
        var activitiesRaw: [String]
        var notes: String?
        var createdAt: Date
        var updatedAt: Date

        init(_ entry: SexualActivityEntry) {
            id = entry.id
            dayKey = entry.day.key
            activitiesRaw = entry.orderedActivities.map(\.rawValue)
            notes = entry.notes
            createdAt = entry.createdAt
            updatedAt = entry.updatedAt
        }

        func value() throws -> SexualActivityEntry {
            let activities = Set(activitiesRaw.compactMap(SexualActivityKind.init(rawValue:)))
            guard activities.count == activitiesRaw.count else { throw TrackingError.invalidData }
            return try SexualActivityEntry(id: id, day: LocalDay(key: dayKey), activities: activities,
                                           notes: notes, createdAt: createdAt, updatedAt: updatedAt)
        }
    }
}