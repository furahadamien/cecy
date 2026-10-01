import Foundation
import SwiftData

nonisolated enum TrackerSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }
    static var models: [any PersistentModel.Type] { TrackerSchemaV5.models + [HealthImportRecord.self] }

    @Model nonisolated final class HealthImportRecord {
        var sampleID: UUID
        var payload: Data

        init(_ receipt: HealthImportReceipt) throws {
            sampleID = receipt.id
            payload = try JSONEncoder().encode(receipt)
        }

        func value() throws -> HealthImportReceipt {
            let receipt = try JSONDecoder().decode(HealthImportReceipt.self, from: payload)
            guard receipt.id == sampleID, receipt.mappingVersion == HealthImportPolicy.mappingVersion,
                  receipt.acceptedAt.timeIntervalSinceReferenceDate.isFinite,
                  TimeZone(identifier: receipt.mappingTimeZone) != nil else { throw TrackingError.invalidData }
            _ = try LocalDay(key: receipt.acceptedStartKey)
            _ = try receipt.sample.suggestedDay(fallbackTimeZone: TimeZone(secondsFromGMT: 0)!)
            return receipt
        }
    }
}
