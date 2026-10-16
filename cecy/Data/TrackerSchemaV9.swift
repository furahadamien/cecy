import Foundation
import SwiftData

nonisolated enum TrackerSchemaV9: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(9, 0, 0) }
    static var models: [any PersistentModel.Type] { TrackerSchemaV8.models + [P2DataRecord.self] }

    @Model nonisolated final class P2DataRecord {
        var key: String
        var payload: Data

        init(_ value: P2Data) throws {
            key = "p2-data"
            payload = try JSONEncoder().encode(value)
        }

        func value() throws -> P2Data {
            guard key == "p2-data" else { throw TrackingError.invalidData }
            return try JSONDecoder().decode(P2Data.self, from: payload)
        }

        func update(_ value: P2Data) throws { payload = try JSONEncoder().encode(value) }
    }
}
