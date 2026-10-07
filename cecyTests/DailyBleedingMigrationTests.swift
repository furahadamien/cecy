import Foundation
import SwiftData
import Testing
@testable import cecy

@MainActor struct DailyBleedingMigrationTests {
    private let today = try! LocalDay(key: 20261007)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case disk }

    @Test(arguments: [1, 2, 3, 4, 5, 6])
    func everySupportedSchemaMigratesWithoutFabricatingDailyHistory(version: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("CecyPeriodsV1.store")
        let closed = try Period(start: LocalDay(key: 20260901), end: LocalDay(key: 20260905),
                                flow: version == 1 ? nil : .heavy, notes: version == 1 ? nil : "Synthetic note",
                                createdAt: now.addingTimeInterval(-120), updatedAt: now.addingTimeInterval(-60))
        let open = Period(start: today, createdAt: now)
        let symptom = SymptomEntry(day: today, kind: .headache, notes: "Synthetic symptom", createdAt: now)
        let activity = SexualActivityEntry(day: today, activities: [.other], notes: "Synthetic activity", createdAt: now)
        var profile = LocalProfile()
        profile.preferredName = "Synthetic"; profile.birthDayKey = 19950101
        profile.typicalCycleDays = 28; profile.typicalPeriodDays = 5
        let sample = HealthFlowSample(id: UUID(), sourceName: "Synthetic source", sourceBundle: "test.source",
            start: now, end: now, timeZoneIdentifier: "GMT", flowValue: 2, markedCycleStart: true)
        let receipt = HealthImportReceipt(sample: sample, periodID: open.id, acceptedStartKey: today.key,
            mappingTimeZone: "GMT", acceptedAt: now, mappingVersion: HealthImportPolicy.mappingVersion)
        let expected = TrackerSnapshot(periods: [closed, open], onboardingCompletedAt: now,
            symptoms: version >= 3 ? [symptom] : [], profile: version >= 4 ? profile : nil,
            sexualActivities: version >= 5 ? [activity] : [], healthImports: version >= 6 ? [receipt] : [])
        var legacyProfilePayload: Data?
        try autoreleasepool {
            let versions: [any VersionedSchema.Type] = [TrackerSchemaV1.self, TrackerSchemaV2.self, TrackerSchemaV3.self,
                                                        TrackerSchemaV4.self, TrackerSchemaV5.self, TrackerSchemaV6.self]
            let schema = Schema(versionedSchema: versions[version - 1])
            let configuration = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container); context.autosaveEnabled = false
            if version == 1 {
                context.insert(TrackerSchemaV1.PeriodRecord(closed)); context.insert(TrackerSchemaV1.PeriodRecord(open))
                context.insert(TrackerSchemaV1.AppStateRecord(completedAt: now))
            } else {
                context.insert(TrackerSchemaV2.PeriodRecord(closed)); context.insert(TrackerSchemaV2.PeriodRecord(open))
                context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
            }
            if version >= 3 { context.insert(TrackerSchemaV3.SymptomRecord(symptom)) }
            if version >= 4 {
                let record = try TrackerSchemaV4.ProfileRecord(profile)
                legacyProfilePayload = record.payload
                context.insert(record)
            }
            if version >= 5 { context.insert(TrackerSchemaV5.SexualActivityRecord(activity)) }
            if version >= 6 { context.insert(try TrackerSchemaV6.HealthImportRecord(receipt)) }
            try context.save()
        }
        var saved = TrackerSnapshot()
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            #expect(try repository.load() == expected)
            #expect(try repository.load().dailyBleeding.isEmpty)
            if let legacyProfilePayload {
                let context = ModelContext(repository.container)
                #expect(try context.fetch(FetchDescriptor<TrackerSchemaV4.ProfileRecord>()).first?.payload == legacyProfilePayload)
            }
            // Only this explicit action creates a daily row; the old five-day range creates none.
            saved = try repository.saveDailyBleeding(DailyBleedingObservation(day: today, state: .bleeding,
                flow: .light, periodID: open.id), editing: false, today: today, now: now)
            #expect(saved.periods == expected.periods && saved.dailyBleeding.count == 1)
        }
        try autoreleasepool {
            let reopened = try SwiftDataPeriodRepository.local(url: url)
            #expect(try reopened.load() == saved)
            #expect(try reopened.deleteAll() == TrackerSnapshot())
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == TrackerSnapshot())
    }

    @Test func freshStoreReopensAllStatesWithNoImplicitCoverage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("fresh.store")
        var saved = TrackerSnapshot()
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            #expect(try repository.load() == TrackerSnapshot())
            for (offset, state) in DailyBleedingState.allCases.enumerated() {
                saved = try repository.saveDailyBleeding(DailyBleedingObservation(day: today.adding(days: -offset), state: state,
                    flow: state == .bleeding ? .moderate : nil), editing: false, today: today, now: now)
            }
        }
        let reopened = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(reopened == saved && reopened.dailyBleeding.count == 4 && reopened.periods.isEmpty)
    }

    @Test func failedCoupledSaveAndResetPreserveDiskStateAcrossReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("rollback.store")
        var original = TrackerSnapshot()
        try autoreleasepool {
            let base = try SwiftDataPeriodRepository.local(url: url)
            let period = Period(start: today, createdAt: now)
            _ = try base.add([period], completingOnboarding: true, today: today, now: now)
            original = try base.saveDailyBleeding(DailyBleedingObservation(day: today, state: .bleeding, periodID: period.id),
                                                  editing: false, today: today, now: now)
            let failing = SwiftDataPeriodRepository(container: base.container, save: { _ in throw Failure.disk })
            let review = try BleedingReconciliation.retainingDailyRecordsWhenDeleting(period.id, from: original)
            #expect(throws: Failure.disk) { try failing.reconcileBleeding(review, today: today, now: now) }
            #expect(throws: Failure.disk) { try failing.deleteAll() }
            #expect(try failing.load() == original)
        }
        try autoreleasepool {
            let reopened = try SwiftDataPeriodRepository.local(url: url)
            #expect(try reopened.load() == original)
            let review = try BleedingReconciliation.retainingDailyRecordsWhenDeleting(original.periods[0].id, from: original)
            original = try reopened.reconcileBleeding(review, today: today, now: now)
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == original)
    }

    @Test func corruptStoreIsNotReplacedWithAnEmptyStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("corrupt.store")
        let bytes = Data("Not a database. Synthetic failure fixture.".utf8)
        try bytes.write(to: url)
        #expect(throws: (any Error).self) { try SwiftDataPeriodRepository.local(url: url) }
        #expect(try Data(contentsOf: url) == bytes)
        let session = TrackerSession(repository: { try SwiftDataPeriodRepository.local(url: url) },
                                     clock: { self.now }, timeZone: { .gmt })
        session.load()
        #expect(session.phase == .failed && session.failureMessage != nil)
        #expect(try Data(contentsOf: url) == bytes)
    }
}
