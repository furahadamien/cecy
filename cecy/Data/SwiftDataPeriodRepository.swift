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
        try ProtectedFiles.directory(url.deletingLastPathComponent(), excludeFromBackup: true)
        let schema = Schema(versionedSchema: TrackerSchemaV6.self)
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
        let schema = Schema(versionedSchema: TrackerSchemaV6.self)
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
        let profiles = try context.fetch(FetchDescriptor<TrackerSchemaV4.ProfileRecord>())
        guard profiles.count <= 1 else { throw TrackingError.invalidData }
        let activities = try context.fetch(FetchDescriptor<TrackerSchemaV5.SexualActivityRecord>()).map { try $0.value() }
        try SexualActivityValidation.validate(activities)
        let imports = try context.fetch(FetchDescriptor<TrackerSchemaV6.HealthImportRecord>()).map { try $0.value() }
        guard Set(imports.map(\.id)).count == imports.count else { throw TrackingError.invalidData }
        return TrackerSnapshot(periods: periods, onboardingCompletedAt: states.first?.onboardingCompletedAt,
                               symptoms: SymptomValidation.sorted(symptoms), profile: try profiles.first?.value(),
                               sexualActivities: SexualActivityValidation.sorted(activities),
                               healthImports: imports.sorted { $0.id.uuidString < $1.id.uuidString })
    }

    private func writeProfile(_ profile: LocalProfile) throws {
        if let record = try context.fetch(FetchDescriptor<TrackerSchemaV4.ProfileRecord>()).first {
            record.payload = try JSONEncoder().encode(profile)
        } else { context.insert(try TrackerSchemaV4.ProfileRecord(profile)) }
    }

    func saveProfile(_ profile: LocalProfile, today: LocalDay) throws -> TrackerSnapshot {
        var candidate = try load()
        try profile.validate(today: today)
        guard candidate.profile == nil || candidate.profile?.id == profile.id else { throw ProfileError.identity }
        do {
            try writeProfile(profile)
            try saveContext(context)
            candidate.profile = profile
            return candidate
        } catch { context.rollback(); throw error }
    }

    func prepareOnboarding(_ draft: OnboardingDraft, today: LocalDay) throws -> TrackerSnapshot {
        try draft.validate(today: today)
        var candidate = try load()
        guard candidate.onboardingCompletedAt == nil else { throw ProfileError.alreadyCompleted }
        guard candidate.profile == nil || candidate.profile?.id == draft.profile.id else { throw ProfileError.identity }
        do {
            // Only unfinished setup can replace this draft history. Repeated attempts never append duplicates.
            let records = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>())
            records.forEach { context.delete($0) }
            draft.periods.forEach { context.insert(TrackerSchemaV2.PeriodRecord($0)) }
            try writeProfile(draft.profile)
            try saveContext(context)
            candidate.profile = draft.profile
            candidate.periods = draft.periods.sorted { $0.start < $1.start }
            return candidate
        } catch { context.rollback(); throw error }
    }

    func completeOnboarding(profileID: UUID, today: LocalDay, now: Date) throws -> TrackerSnapshot {
        var candidate = try load()
        guard candidate.profile?.id == profileID else { throw ProfileError.identity }
        if candidate.onboardingCompletedAt != nil { return candidate }
        try candidate.profile?.validate(today: today)
        guard candidate.profile?.typicalPeriodDays != nil else { throw ProfileError.duration }
        guard candidate.profile?.typicalCycleDays != nil else { throw ProfileError.cycleLength }
        guard !candidate.periods.isEmpty else { throw ProfileError.lastPeriod }
        try PeriodValidation.validate(candidate.periods, asOf: today)
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
        do {
            if let state = try context.fetch(FetchDescriptor<TrackerSchemaV2.AppStateRecord>()).first {
                state.onboardingCompletedAt = now
            } else { context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now)) }
            try saveContext(context)
            candidate.onboardingCompletedAt = now
            return candidate
        } catch { context.rollback(); throw error }
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

    func addSymptoms(_ entries: [SymptomEntry], today: LocalDay, now: Date) throws -> TrackerSnapshot {
        guard !entries.isEmpty else { throw TrackingError.invalidData }
        var candidate = try load()
        var values = entries.map {
            SymptomEntry(id: $0.id, day: $0.day, kind: $0.kind, value: $0.value, notes: $0.notes, createdAt: now)
        }
        try SymptomValidation.validate(candidate.symptoms + values, asOf: today)
        for index in values.indices {
            if values[index].notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                values[index].notes = nil
            }
        }
        candidate.symptoms = SymptomValidation.sorted(candidate.symptoms + values)
        do {
            values.forEach { context.insert(TrackerSchemaV3.SymptomRecord($0)) }
            try saveContext(context)
            return candidate
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteSymptoms(on day: LocalDay) throws -> TrackerSnapshot {
        var candidate = try load()
        let records = try context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>())
            .filter { $0.dayKey == day.key }
        guard !records.isEmpty else { throw TrackingError.missingRecord }
        do {
            records.forEach { context.delete($0) }
            try saveContext(context)
            candidate.symptoms.removeAll { $0.day == day }
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

    func saveSexualActivity(_ entry: SexualActivityEntry, editing: Bool, today: LocalDay, now: Date) throws -> TrackerSnapshot {
        var candidate = try load()
        let original = candidate.sexualActivities.first { $0.id == entry.id }
        if editing && original == nil { throw TrackingError.missingRecord }
        var value = SexualActivityEntry(id: entry.id, day: entry.day, activities: entry.activities, notes: entry.notes,
                                        createdAt: editing ? original!.createdAt : now, updatedAt: now)
        if editing { candidate.sexualActivities.removeAll { $0.id == entry.id } }
        try SexualActivityValidation.validate(candidate.sexualActivities + [value], asOf: today)
        if value.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true { value.notes = nil }
        candidate.sexualActivities = SexualActivityValidation.sorted(candidate.sexualActivities + [value])
        do {
            if editing {
                guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV5.SexualActivityRecord>()).first(where: { $0.id == value.id }) else {
                    throw TrackingError.missingRecord
                }
                record.dayKey = value.day.key
                record.activitiesRaw = value.orderedActivities.map(\.rawValue)
                record.notes = value.notes
                record.updatedAt = value.updatedAt
            } else { context.insert(TrackerSchemaV5.SexualActivityRecord(value)) }
            try saveContext(context)
            return candidate
        } catch { context.rollback(); throw error }
    }

    func deleteSexualActivity(id: UUID) throws -> TrackerSnapshot {
        var candidate = try load()
        guard let record = try context.fetch(FetchDescriptor<TrackerSchemaV5.SexualActivityRecord>()).first(where: { $0.id == id }) else {
            throw TrackingError.missingRecord
        }
        do {
            context.delete(record)
            try saveContext(context)
            candidate.sexualActivities.removeAll { $0.id == id }
            return candidate
        } catch { context.rollback(); throw error }
    }

    func importHealthStart(_ sample: HealthFlowSample, confirmedStart: LocalDay,
                           today: LocalDay, now: Date, timeZone: TimeZone) throws -> TrackerSnapshot {
        var candidate = try load()
        let (period, receipt) = try HealthImportPolicy.prepare(sample: sample, confirmedStart: confirmedStart,
                                                               existing: candidate, today: today, now: now, timeZone: timeZone)
        do {
            let record = try TrackerSchemaV6.HealthImportRecord(receipt)
            context.insert(TrackerSchemaV2.PeriodRecord(period))
            context.insert(record)
            try saveContext(context)
            candidate.periods = (candidate.periods + [period]).sorted { $0.start < $1.start }
            candidate.healthImports = (candidate.healthImports + [receipt]).sorted { $0.id.uuidString < $1.id.uuidString }
            return candidate
        } catch { context.rollback(); throw error }
    }

    func deleteAll() throws -> TrackerSnapshot {
        do {
            // Fetch before deleting anything. Reset also works for malformed domain records.
            let records = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>())
            let states = try context.fetch(FetchDescriptor<TrackerSchemaV2.AppStateRecord>())
            let symptoms = try context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>())
            let profiles = try context.fetch(FetchDescriptor<TrackerSchemaV4.ProfileRecord>())
            let activities = try context.fetch(FetchDescriptor<TrackerSchemaV5.SexualActivityRecord>())
            let imports = try context.fetch(FetchDescriptor<TrackerSchemaV6.HealthImportRecord>())
            try clearLegacyData()
            records.forEach { context.delete($0) }
            states.forEach { context.delete($0) }
            symptoms.forEach { context.delete($0) }
            profiles.forEach { context.delete($0) }
            activities.forEach { context.delete($0) }
            imports.forEach { context.delete($0) }
            try saveContext(context)
            return TrackerSnapshot()
        } catch {
            context.rollback()
            throw error
        }
    }
}
