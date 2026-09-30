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
    private let clearLegacyData: () throws -> Void

    init(container: ModelContainer, clearLegacyData: @escaping () throws -> Void = {},
         save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
        saveContext = save
        self.clearLegacyData = clearLegacyData
    }

    static func local(url: URL, clearLegacyData: @escaping () throws -> Void = {}) throws -> SwiftDataPeriodRepository {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: TrackerSchemaV3.self)
        let configuration = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
        return try SwiftDataPeriodRepository(container: ModelContainer(for: schema, migrationPlan: TrackerMigrationPlan.self,
                                                                       configurations: [configuration]), clearLegacyData: clearLegacyData)
    }

    static func production() throws -> SwiftDataPeriodRepository {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("Cecy", isDirectory: true)
        try ProtectedFiles.protectTree(directory)
        let repository = try local(url: directory
            .appendingPathComponent("CecyPeriodsV1.store"), clearLegacyData: {
                try LegacyStoreCleanup.removeTemplateStore(in: support)
            })
        try ProtectedFiles.protectTree(directory)
        return repository
    }

    static func inMemory() throws -> SwiftDataPeriodRepository {
        let schema = Schema(versionedSchema: TrackerSchemaV3.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try SwiftDataPeriodRepository(container: ModelContainer(for: schema, migrationPlan: TrackerMigrationPlan.self,
                                                                       configurations: [configuration]))
    }

    func load() throws -> TrackerSnapshot {
        let records = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>())
        let states = try context.fetch(FetchDescriptor<TrackerSchemaV2.AppStateRecord>())
        guard states.count <= 1, states.allSatisfy({ $0.key == "onboarding" }),
              states.allSatisfy({ $0.onboardingCompletedAt?.timeIntervalSinceReferenceDate.isFinite ?? true }) else {
            throw TrackingError.invalidData
        }
        let periods = try records.map { try $0.value() }.sorted { $0.start < $1.start }
        try PeriodValidation.validate(periods)
        let symptoms = try context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>()).map { try $0.value() }
        try SymptomValidation.validate(symptoms)
        return TrackerSnapshot(periods: periods, onboardingCompletedAt: states.first?.onboardingCompletedAt,
                               symptoms: SymptomValidation.sorted(symptoms))
    }

    func add(_ periods: [Period], completingOnboarding: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot {
        var candidate = try load()
        candidate.periods += periods
        try PeriodValidation.validate(candidate.periods, asOf: today)
        candidate.periods.sort { $0.start < $1.start }
        if completingOnboarding && candidate.onboardingCompletedAt == nil { candidate.onboardingCompletedAt = now }
        do {
            periods.forEach { context.insert(TrackerSchemaV2.PeriodRecord($0)) }
            if completingOnboarding {
                if let state = try context.fetch(FetchDescriptor<TrackerSchemaV2.AppStateRecord>()).first {
                    state.onboardingCompletedAt = candidate.onboardingCompletedAt
                } else {
                    context.insert(TrackerSchemaV2.AppStateRecord(completedAt: candidate.onboardingCompletedAt))
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
        updated.flow = period.flow
        updated.notes = period.notes
        updated.updatedAt = now
        candidate.periods[index] = updated
        try PeriodValidation.validate(candidate.periods, asOf: today)
        guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>()).first(where: { $0.id == period.id }) else {
            throw TrackingError.missingRecord
        }
        do {
            record.startKey = updated.start.key
            record.endKey = updated.end?.key
            record.flowRaw = updated.flow?.rawValue
            record.notes = updated.notes
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
        guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>()).first(where: { $0.id == id }) else {
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

    func saveSymptom(_ entry: SymptomEntry, editing: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot {
        var candidate = try load()
        var value = entry
        if editing {
            guard let original = candidate.symptoms.first(where: { $0.id == entry.id }) else { throw TrackingError.missingRecord }
            value = SymptomEntry(id: original.id, day: entry.day, kind: entry.kind, value: entry.value,
                                 notes: entry.notes, createdAt: original.createdAt, updatedAt: now)
            candidate.symptoms.removeAll { $0.id == entry.id }
        } else {
            value = SymptomEntry(id: entry.id, day: entry.day, kind: entry.kind, value: entry.value,
                                 notes: entry.notes, createdAt: now)
        }
        // Validate before normalizing so oversized whitespace notes are never silently accepted.
        try SymptomValidation.validate(candidate.symptoms + [value], asOf: today)
        if value.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { value.notes = nil }
        candidate.symptoms.append(value)
        candidate.symptoms = SymptomValidation.sorted(candidate.symptoms)
        do {
            if editing {
                guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>()).first(where: { $0.id == value.id }) else {
                    throw TrackingError.missingRecord
                }
                record.dayKey = value.day.key
                record.kindRaw = value.kind.rawValue
                record.rating = value.value
                record.notes = value.notes
                record.updatedAt = value.updatedAt
            } else { context.insert(TrackerSchemaV3.SymptomRecord(value)) }
            try saveContext(context)
            return candidate
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteSymptom(id: UUID) throws -> TrackerSnapshot {
        var candidate = try load()
        guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>()).first(where: { $0.id == id }) else {
            throw TrackingError.missingRecord
        }
        do {
            context.delete(record)
            try saveContext(context)
            candidate.symptoms.removeAll { $0.id == id }
            return candidate
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteAll() throws -> TrackerSnapshot {
        do {
            // Fetch before deleting anything. Reset also works for malformed domain records.
            let records = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>())
            let states = try context.fetch(FetchDescriptor<TrackerSchemaV2.AppStateRecord>())
            let symptoms = try context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>())
            try clearLegacyData()
            records.forEach { context.delete($0) }
            states.forEach { context.delete($0) }
            symptoms.forEach { context.delete($0) }
            try saveContext(context)
            return TrackerSnapshot()
        } catch {
            context.rollback()
            throw error
        }
    }
}
