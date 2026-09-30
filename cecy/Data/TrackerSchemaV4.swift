import Foundation
import SwiftData

nonisolated enum TrackerSchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [TrackerSchemaV2.PeriodRecord.self, TrackerSchemaV2.AppStateRecord.self,
         TrackerSchemaV3.SymptomRecord.self, ProfileRecord.self]
    }

    @Model nonisolated final class ProfileRecord {
        var key: String
        var formatVersion: Int
        var payload: Data

        init(_ profile: LocalProfile) throws {
            key = "local-profile"
            formatVersion = 1
            payload = try JSONEncoder().encode(profile)
        }

        func value() throws -> LocalProfile {
            guard key == "local-profile", formatVersion == 1 else { throw TrackingError.invalidData }
            let profile = try JSONDecoder().decode(LocalProfile.self, from: payload)
            try profile.validate()
            return profile
        }
    }
}