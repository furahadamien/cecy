import Foundation
import SwiftData

nonisolated enum TrackerSchemaV8: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(8, 0, 0) }
    static var models: [any PersistentModel.Type] {
        TrackerSchemaV7.models + [CycleFactorRecord.self, TreatmentDataRecord.self,
                                  TreatmentAdherenceRecord.self, OnboardingProgressRecord.self]
    }

    @Model nonisolated final class CycleFactorRecord {
        var id: UUID
        var payload: Data
        init(_ value: CycleFactor) throws { id = value.id; payload = try JSONEncoder().encode(value) }
        func value() throws -> CycleFactor { try JSONDecoder().decode(CycleFactor.self, from: payload) }
        func update(_ value: CycleFactor) throws { payload = try JSONEncoder().encode(value) }
    }

    @Model nonisolated final class TreatmentDataRecord {
        var id: UUID
        var payload: Data
        init(_ value: TreatmentRecord) throws { id = value.id; payload = try JSONEncoder().encode(value) }
        func value() throws -> TreatmentRecord { try JSONDecoder().decode(TreatmentRecord.self, from: payload) }
        func update(_ value: TreatmentRecord) throws { payload = try JSONEncoder().encode(value) }
    }

    @Model nonisolated final class TreatmentAdherenceRecord {
        var id: UUID
        var payload: Data
        init(_ value: TreatmentAdherence) throws { id = value.id; payload = try JSONEncoder().encode(value) }
        func value() throws -> TreatmentAdherence { try JSONDecoder().decode(TreatmentAdherence.self, from: payload) }
        func update(_ value: TreatmentAdherence) throws { payload = try JSONEncoder().encode(value) }
    }

    @Model nonisolated final class OnboardingProgressRecord {
        var key: String
        var payload: Data
        init(_ value: OnboardingProgress) throws {
            key = "onboarding-progress"
            payload = try JSONEncoder().encode(value)
        }
        func value() throws -> OnboardingProgress {
            guard key == "onboarding-progress" else { throw TrackingError.invalidData }
            return try JSONDecoder().decode(OnboardingProgress.self, from: payload)
        }
        func update(_ value: OnboardingProgress) throws { payload = try JSONEncoder().encode(value) }
    }
}
