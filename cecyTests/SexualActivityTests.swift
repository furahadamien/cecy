import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct SexualActivityDomainTests {
    private let today = try! LocalDay(key: 20260929)

    @Test func multipleActivitiesAreOneDailyRecordAndInvalidRecordsAreRejected() throws {
        let entry = SexualActivityEntry(day: today, activities: [.oralSex, .vaginalSex])
        try SexualActivityValidation.validate([entry], asOf: today)
        #expect(entry.orderedActivities == [.vaginalSex, .oralSex])
        #expect(entry.summary == "Vaginal sex, Oral sex")
        #expect(throws: SexualActivityError.empty) {
            try SexualActivityValidation.validate([SexualActivityEntry(day: today, activities: [])])
        }
        #expect(throws: SexualActivityError.duplicateDay) {
            try SexualActivityValidation.validate([entry, SexualActivityEntry(day: today, activities: [.other])])
        }
        #expect(throws: TrackingError.invalidData) { try SexualActivityValidation.validate([entry, entry]) }
        var invalid = entry
        invalid.day = try today.adding(days: 1)
        #expect(throws: TrackingError.futureDate) { try SexualActivityValidation.validate([invalid], asOf: today) }
        invalid = entry
        invalid.notes = String(repeating: " ", count: 2_001)
        #expect(throws: TrackingError.noteTooLong) { try SexualActivityValidation.validate([invalid]) }
        invalid = entry
        invalid.updatedAt = entry.createdAt.addingTimeInterval(-1)
        #expect(throws: TrackingError.invalidData) { try SexualActivityValidation.validate([invalid]) }
        invalid.updatedAt = Date(timeIntervalSinceReferenceDate: .nan)
        #expect(throws: TrackingError.invalidData) { try SexualActivityValidation.validate([invalid]) }
    }

    @Test func exportsRequireSeparateActivityAndNotesConsent() throws {
        let now = today.formattingDate
        let entry = SexualActivityEntry(day: today, activities: [.vaginalSex, .oralSex], notes: "Synthetic private note", createdAt: now)
        let snapshot = TrackerSnapshot(sexualActivities: [entry])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        for includeNotes in [false, true] {
            let excluded = try TrackerExport.encode(snapshot: snapshot, includeNotes: includeNotes, generatedAt: now)
            let oldFormat = try decoder.decode(TrackerExport.Document.self, from: excluded)
            #expect(oldFormat.formatVersion == 1 && oldFormat.sexualActivities == nil)
            #expect(!String(decoding: excluded, as: UTF8.self).contains("vaginalSex"))
            #expect(!String(decoding: excluded, as: UTF8.self).contains("Synthetic private note"))
            let data = try TrackerExport.encode(snapshot: snapshot, includeNotes: includeNotes, generatedAt: now, includeSexualActivity: true)
            let document = try decoder.decode(TrackerExport.Document.self, from: data)
            #expect(document.formatVersion == 3)
            let record = try #require(document.sexualActivities?.first)
            #expect(record.id == entry.id && record.date == "2026-09-29")
            #expect(record.activities == ["vaginalSex", "oralSex"])
            #expect(record.notes == (includeNotes ? entry.notes : nil))
        }
    }
}

@MainActor struct SexualActivityRepositoryTests {
    private let today = try! LocalDay(key: 20260929)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case disk }

    @Test func recordsPersistEditWithoutDuplicatesAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let initial = SexualActivityEntry(day: today, activities: [.vaginalSex, .oralSex], notes: "  ")
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let saved = try repository.saveSexualActivity(initial, editing: false, today: today, now: now)
            #expect(saved.sexualActivities.first?.activities == initial.activities)
            #expect(saved.sexualActivities.first?.notes == nil)
            #expect(throws: SexualActivityError.duplicateDay) {
                try repository.saveSexualActivity(SexualActivityEntry(day: today, activities: [.other]), editing: false, today: today, now: now)
            }
            #expect(try repository.load() == saved)
        }
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            var entry = try #require(repository.load().sexualActivities.first)
            #expect(entry.activities == initial.activities)
            entry.activities = [.masturbation]
            entry.day = try today.adding(days: -1)
            entry.notes = "Updated private note"
            let edited = try repository.saveSexualActivity(entry, editing: true, today: today, now: now.addingTimeInterval(60))
            #expect(edited.sexualActivities.count == 1)
            #expect(edited.sexualActivities[0].createdAt == now)
            #expect(edited.sexualActivities[0].updatedAt == now.addingTimeInterval(60))
        }
        let repository = try SwiftDataPeriodRepository.local(url: url)
        let reopened = try #require(repository.load().sexualActivities.first)
        #expect(reopened.activities == [.masturbation] && reopened.notes == "Updated private note")
        #expect(try reopened.day == today.adding(days: -1))
        #expect(try repository.deleteSexualActivity(id: reopened.id).sexualActivities.isEmpty)
        #expect(throws: TrackingError.missingRecord) { try repository.deleteSexualActivity(id: reopened.id) }
    }

    @Test func failedWritesRollBackAndResetRemovesActivity() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = false
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }; try $0.save()
        })
        var entry = SexualActivityEntry(day: today, activities: [.oralSex, .analSex])
        fail = true
        #expect(throws: Failure.disk) { try repository.saveSexualActivity(entry, editing: false, today: today, now: now) }
        #expect(try repository.load().sexualActivities.isEmpty)
        fail = false
        let saved = try repository.saveSexualActivity(entry, editing: false, today: today, now: now)
        entry.activities = [.other]
        fail = true
        #expect(throws: Failure.disk) { try repository.saveSexualActivity(entry, editing: true, today: today, now: now) }
        #expect(try repository.load() == saved)
        #expect(throws: Failure.disk) { try repository.deleteSexualActivity(id: entry.id) }
        #expect(try repository.load() == saved)
        #expect(throws: Failure.disk) { try repository.deleteAll() }
        #expect(try repository.load() == saved)
        fail = false
        #expect(try repository.deleteAll() == TrackerSnapshot())
        #expect(try repository.load() == TrackerSnapshot())
    }

    @Test func malformedStoredActivityFailsClosedAndCanBeReset() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let context = ModelContext(repository.container)
        let record = TrackerSchemaV5.SexualActivityRecord(SexualActivityEntry(day: today, activities: [.other]))
        record.activitiesRaw = ["unknown"]
        context.insert(record)
        try context.save()
        #expect(throws: TrackingError.invalidData) { try repository.load() }
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func v4MigrationPreservesAllExistingRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let period = Period(start: today, createdAt: now)
        let symptom = SymptomEntry(day: today, kind: .cramps, createdAt: now)
        var profile = LocalProfile(); profile.preferredName = "Synthetic"; profile.birthDayKey = 19950512
        try autoreleasepool {
            let schema = Schema(versionedSchema: TrackerSchemaV4.self)
            let configuration = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            context.insert(TrackerSchemaV2.PeriodRecord(period))
            context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
            context.insert(TrackerSchemaV3.SymptomRecord(symptom))
            context.insert(try TrackerSchemaV4.ProfileRecord(profile))
            try context.save()
        }
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let snapshot = try repository.load()
            #expect(snapshot.periods == [period] && snapshot.symptoms == [symptom] && snapshot.profile == profile)
            #expect(snapshot.onboardingCompletedAt == now && snapshot.sexualActivities.isEmpty)
            _ = try repository.saveSexualActivity(SexualActivityEntry(day: today, activities: [.oralSex]), editing: false, today: today, now: now)
        }
        let reopened = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(reopened.sexualActivities.first?.activities == [.oralSex])
        #expect(reopened.periods == [period] && reopened.symptoms == [symptom] && reopened.profile == profile)
    }

    @Test func activityDoesNotChangePredictionsAndLockedWritesAreDenied() async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        _ = try repository.add(periods, completingOnboarding: true, today: today, now: now)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let privacy = TrackerPrivacy(storage: MemoryPrivacyPreferences(), authentication: FixedDeviceAuthentication(succeeds: true),
                                     exports: ProtectedExportFiles(directory: directory), delivery: MemoryReminderDelivery())
        privacy.start()
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt }, privacy: privacy)
        session.load()
        let overview = session.overview
        let insights = session.insights
        let entry = SexualActivityEntry(day: today, activities: [.vaginalSex, .oralSex])
        #expect(session.saveSexualActivity(entry) == nil)
        #expect(session.overview == overview && session.insights == insights)
        let saved = session.snapshot
        await privacy.setLockEnabled(true)
        #expect(privacy.preferences.lockEnabled)
        privacy.lockNow()
        #expect(!privacy.canAccess)
        #expect(session.saveSexualActivity(entry, editing: true) != nil)
        #expect(session.deleteSexualActivity(id: entry.id) != nil)
        #expect(session.snapshot == saved)
        #expect(try repository.load() == saved)
    }
}
