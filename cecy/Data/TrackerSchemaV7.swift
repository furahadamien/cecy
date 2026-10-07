import Foundation
import SwiftData

nonisolated enum TrackerSchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(7, 0, 0) }
    static var models: [any PersistentModel.Type] { TrackerSchemaV6.models + [DailyBleedingRecord.self] }

    @Model nonisolated final class DailyBleedingRecord {
        var id: UUID
        var dayKey: Int
        var stateRaw: String
        var flowRaw: String?
        // The sole association: no inverse relationship or implicit cascade.
        var periodID: UUID?
        var createdAt: Date
        var updatedAt: Date

        init(_ observation: DailyBleedingObservation) {
            id = observation.id
            dayKey = observation.day.key
            stateRaw = observation.state.rawValue
            flowRaw = observation.flow?.rawValue
            periodID = observation.periodID
            createdAt = observation.createdAt
            updatedAt = observation.updatedAt
        }

        func value() throws -> DailyBleedingObservation {
            guard let state = DailyBleedingState(rawValue: stateRaw) else { throw TrackingError.invalidData }
            let flow = flowRaw.flatMap(PeriodFlow.init(rawValue:))
            guard flowRaw == nil || flow != nil else { throw TrackingError.invalidData }
            return try DailyBleedingObservation(id: id, day: LocalDay(key: dayKey), state: state, flow: flow,
                                               periodID: periodID, createdAt: createdAt, updatedAt: updatedAt)
        }

        func update(_ observation: DailyBleedingObservation) {
            dayKey = observation.day.key
            stateRaw = observation.state.rawValue
            flowRaw = observation.flow?.rawValue
            periodID = observation.periodID
            updatedAt = observation.updatedAt
        }
    }
}
