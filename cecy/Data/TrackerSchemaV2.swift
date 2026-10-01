import Foundation
import SwiftData

nonisolated enum TrackerSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [PeriodRecord.self, AppStateRecord.self] }

    @Model nonisolated final class PeriodRecord {
        var id: UUID
        var startKey: Int
        var endKey: Int?
        var createdAt: Date
        var updatedAt: Date
        var flowRaw: String?
        var notes: String?

        init(_ period: Period) {
            id = period.id
            startKey = period.start.key
            endKey = period.end?.key
            createdAt = period.createdAt
            updatedAt = period.updatedAt
            flowRaw = period.flow?.rawValue
            notes = period.notes
        }

        func value() throws -> Period {
            let flow = flowRaw.flatMap(PeriodFlow.init(rawValue:))
            guard flowRaw == nil || flow != nil else { throw TrackingError.invalidData }
            return try Period(id: id, start: LocalDay(key: startKey), end: endKey.map { try LocalDay(key: $0) },
                              flow: flow, notes: notes, createdAt: createdAt, updatedAt: updatedAt)
        }
    }

    @Model nonisolated final class AppStateRecord {
        var key: String
        var onboardingCompletedAt: Date?

        init(completedAt: Date?) {
            key = "onboarding"
            onboardingCompletedAt = completedAt
        }
    }
}

nonisolated enum TrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TrackerSchemaV1.self, TrackerSchemaV2.self, TrackerSchemaV3.self, TrackerSchemaV4.self, TrackerSchemaV5.self, TrackerSchemaV6.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: TrackerSchemaV1.self, toVersion: TrackerSchemaV2.self),
         .lightweight(fromVersion: TrackerSchemaV2.self, toVersion: TrackerSchemaV3.self),
         .lightweight(fromVersion: TrackerSchemaV3.self, toVersion: TrackerSchemaV4.self),
         .lightweight(fromVersion: TrackerSchemaV4.self, toVersion: TrackerSchemaV5.self),
         .lightweight(fromVersion: TrackerSchemaV5.self, toVersion: TrackerSchemaV6.self)]
    }
}

/// The inactive Core Data template used only timestamp rows and no external binary storage.
/// Only called by an explicitly confirmed production reset; never by migration or test factories.
nonisolated enum LegacyStoreCleanup {
    static func removeTemplateStore(in applicationSupport: URL) throws {
        for name in ["cecy.sqlite", "cecy.sqlite-wal", "cecy.sqlite-shm"] {
            let url = applicationSupport.appendingPathComponent(name)
            do { try FileManager.default.removeItem(at: url) }
            catch let error as CocoaError where error.code == .fileNoSuchFile { continue }
        }
    }
}
