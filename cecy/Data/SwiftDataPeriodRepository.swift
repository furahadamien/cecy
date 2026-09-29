import Foundation
import SwiftData

nonisolated enum TrackerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [PeriodRecord.self, AppStateRecord.self] }

    @Model nonisolated final class PeriodRecord {
        var id: UUID
        var startKey: Int
        var endKey: Int?
        var createdAt: Date
        var updatedAt: Date

        init(_ period: Period) {
            id = period.id
            startKey = period.start.key
            endKey = period.end?.key
            createdAt = period.createdAt
            updatedAt = period.updatedAt
        }

        func value() throws -> Period {
            try Period(id: id, start: LocalDay(key: startKey), end: endKey.map { try LocalDay(key: $0) },
                       createdAt: createdAt, updatedAt: updatedAt)
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

@MainActor
final class SwiftDataPeriodRepository: PeriodRepository {
    let container: ModelContainer
    private let context: ModelContext
    private let saveContext: (ModelContext) throws -> Void

    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        saveContext = save
    }

    static func local(url: URL) throws -> SwiftDataPeriodRepository {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: TrackerSchemaV1.self)
        let configuration = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
        return try SwiftDataPeriodRepository(container: ModelContainer(for: schema, configurations: [configuration]))
    }

    static func production() throws -> SwiftDataPeriodRepository {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        return try local(url: support.appendingPathComponent("Cecy", isDirectory: true)
            .appendingPathComponent("CecyPeriodsV1.store"))
    }

    static func inMemory() throws -> SwiftDataPeriodRepository {
        let schema = Schema(versionedSchema: TrackerSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try SwiftDataPeriodRepository(container: ModelContainer(for: schema, configurations: [configuration]))
    }

    func load() throws -> TrackerSnapshot {
        let records = try context.fetch(FetchDescriptor<TrackerSchemaV1.PeriodRecord>())
        let states = try context.fetch(FetchDescriptor<TrackerSchemaV1.AppStateRecord>())
        guard states.count <= 1, states.allSatisfy({ $0.key == "onboarding" }),
              states.allSatisfy({ $0.onboardingCompletedAt?.timeIntervalSinceReferenceDate.isFinite ?? true }) else {
            throw TrackingError.invalidData
        }
        let periods = try records.map { try $0.value() }.sorted { $0.start < $1.start }
        try PeriodValidation.validate(periods)
        return TrackerSnapshot(periods: periods, onboardingCompletedAt: states.first?.onboardingCompletedAt)
    }

    func add(_ periods: [Period], completingOnboarding: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot {
        var candidate = try load()
        candidate.periods += periods
        try PeriodValidation.validate(candidate.periods, asOf: today)
        candidate.periods.sort { $0.start < $1.start }
        if completingOnboarding && candidate.onboardingCompletedAt == nil { candidate.onboardingCompletedAt = now }
        do {
            periods.forEach { context.insert(TrackerSchemaV1.PeriodRecord($0)) }
            if completingOnboarding {
                if let state = try context.fetch(FetchDescriptor<TrackerSchemaV1.AppStateRecord>()).first {
                    state.onboardingCompletedAt = candidate.onboardingCompletedAt
                } else {
                    context.insert(TrackerSchemaV1.AppStateRecord(completedAt: candidate.onboardingCompletedAt))
                }
            }
            try saveContext(context)
            return candidate
        } catch {
            context.rollback()
            throw error
        }
    }

    func update(_ period: Period, today: LocalDay, now: Date) throws -> TrackerSnapshot {
        var candidate = try load()
        guard let index = candidate.periods.firstIndex(where: { $0.id == period.id }) else { throw TrackingError.missingRecord }
        var updated = candidate.periods[index]
        updated.start = period.start
        updated.end = period.end
        updated.updatedAt = now
        candidate.periods[index] = updated
        try PeriodValidation.validate(candidate.periods, asOf: today)
        guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV1.PeriodRecord>()).first(where: { $0.id == period.id }) else {
            throw TrackingError.missingRecord
        }
        do {
            record.startKey = updated.start.key
            record.endKey = updated.end?.key
            record.updatedAt = now
            try saveContext(context)
            candidate.periods.sort { $0.start < $1.start }
            return candidate
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws -> TrackerSnapshot {
        var candidate = try load()
        guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV1.PeriodRecord>()).first(where: { $0.id == id }) else {
            throw TrackingError.missingRecord
        }
        candidate.periods.removeAll { $0.id == id }
        do {
            context.delete(record)
            try saveContext(context)
            return candidate
        } catch {
            context.rollback()
            throw error
        }
    }
}
