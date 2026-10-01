import Foundation
import SwiftData
import Testing
@testable import cecy

private nonisolated func flowSample(id: UUID = UUID(), start: String = "2026-08-01T00:30:00Z",
                                    end: String = "2026-08-03T12:00:00Z", zone: String? = "UTC",
                                    value: Int = 3, source: String = "test.source") -> HealthFlowSample {
    let formatter = ISO8601DateFormatter()
    return HealthFlowSample(id: id, sourceName: "Synthetic source", sourceBundle: source,
                            start: formatter.date(from: start)!, end: formatter.date(from: end)!,
                            timeZoneIdentifier: zone, flowValue: value, markedCycleStart: false)
}

nonisolated struct PhaseSixDomainTests {
    private let today = try! LocalDay(key: 20260929)
    private var now: Date { today.formattingDate }

    @Test func civilMappingUsesSourceZoneAndExplicitFallbackAcrossDST() throws {
        #expect(try flowSample(zone: "America/Los_Angeles").suggestedDay(fallbackTimeZone: .gmt).key == 20260731)
        let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))
        #expect(try flowSample(zone: nil).suggestedDay(fallbackTimeZone: losAngeles).key == 20260731)
        #expect(try flowSample(zone: "invalid").suggestedDay(fallbackTimeZone: .gmt).key == 20260801)
        #expect(try flowSample(start: "2026-03-08T09:59:00Z", end: "2026-03-08T10:01:00Z", zone: "America/Los_Angeles")
            .suggestedDay(fallbackTimeZone: .gmt).key == 20260308)
        #expect(try flowSample(start: "2024-02-29T12:00:00Z", end: "2024-02-29T12:00:00Z")
            .suggestedDay(fallbackTimeZone: .gmt).key == 20240229)
    }

    @Test func multiDayFlowNeverInfersEndOrWholePeriodFlow() throws {
        let day = try LocalDay(key: 20260731)
        let (period, receipt) = try HealthImportPolicy.prepare(sample: flowSample(), confirmedStart: day,
            existing: TrackerSnapshot(), today: today, now: now, timeZone: .gmt)
        #expect(period.start == day && period.end == nil && period.flow == nil && period.notes == nil)
        #expect(receipt.periodID == period.id && receipt.acceptedStartKey == day.key && receipt.mappingVersion == 1)
    }

    @Test func rejectsNoFlowUnknownFutureAndConflictingRecords() throws {
        let day = try LocalDay(key: 20260801)
        for sample in [flowSample(value: 5), flowSample(value: 99),
                       flowSample(start: "2027-01-01T00:00:00Z", end: "2027-01-02T00:00:00Z")] {
            #expect(throws: (any Error).self) {
                try HealthImportPolicy.prepare(sample: sample, confirmedStart: day, existing: TrackerSnapshot(),
                                               today: today, now: now, timeZone: .gmt)
            }
        }
        #expect(throws: TrackingError.duplicateStart) {
            try HealthImportPolicy.prepare(sample: flowSample(), confirmedStart: day,
                existing: TrackerSnapshot(periods: [Period(start: day)]), today: today, now: now, timeZone: .gmt)
        }
        #expect(throws: TrackingError.overlap) {
            try HealthImportPolicy.prepare(sample: flowSample(), confirmedStart: day,
                existing: TrackerSnapshot(periods: [Period(start: try day.adding(days: -2), end: try day.adding(days: 2))]),
                today: today, now: now, timeZone: .gmt)
        }
    }

    @Test func dateLineTravelAllowsExplicitLocalCorrectionButNotAFutureConfirmedDay() throws {
        let sample = flowSample(start: "2026-09-29T23:00:00Z", end: "2026-09-29T23:01:00Z", zone: "Pacific/Kiritimati")
        let instant = ISO8601DateFormatter().date(from: "2026-09-29T23:30:00Z")!
        #expect(try sample.suggestedDay(fallbackTimeZone: .gmt).key == 20260930)
        let (period, _) = try HealthImportPolicy.prepare(sample: sample, confirmedStart: today, existing: TrackerSnapshot(),
                                                         today: today, now: instant, timeZone: .gmt)
        #expect(period.start == today)
        #expect(throws: TrackingError.futureDate) {
            try HealthImportPolicy.prepare(sample: sample, confirmedStart: today.adding(days: 1), existing: TrackerSnapshot(),
                                           today: today, now: instant, timeZone: .gmt)
        }
    }

    @Test func exportIncludesAcceptedPeriodButNotSourceMetadata() throws {
        let sample = flowSample(source: "sensitive.source.identifier")
        let (period, receipt) = try HealthImportPolicy.prepare(sample: sample, confirmedStart: LocalDay(key: 20260801),
            existing: TrackerSnapshot(), today: today, now: now, timeZone: .gmt)
        let data = try TrackerExport.encode(snapshot: TrackerSnapshot(periods: [period], healthImports: [receipt]),
                                           includeNotes: false, generatedAt: now)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("2026-08-01"))
        #expect(!json.contains(sample.id.uuidString) && !json.contains(sample.sourceBundle) && !json.contains(sample.sourceName))
    }
}

@MainActor struct PhaseSixRepositoryTests {
    private let today = try! LocalDay(key: 20260929)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case disk }

    @Test func importsAndReceiptsRollBackTogetherAndRetrySafely() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }; try $0.save()
        })
        let sample = flowSample()
        let day = try LocalDay(key: 20260801)
        #expect(throws: Failure.disk) {
            try repository.importHealthStart(sample, confirmedStart: day, today: today, now: now, timeZone: .gmt)
        }
        #expect(try repository.load() == TrackerSnapshot())
        fail = false
        let saved = try repository.importHealthStart(sample, confirmedStart: day, today: today, now: now, timeZone: .gmt)
        #expect(saved.periods.count == 1 && saved.healthImports.count == 1)
        #expect(throws: (any Error).self) {
            try repository.importHealthStart(sample, confirmedStart: day.adding(days: 1), today: today, now: now, timeZone: .gmt)
        }
        #expect(try repository.load() == saved)
        fail = true
        #expect(throws: Failure.disk) { try repository.deleteAll() }
        #expect(try repository.load() == saved)
        fail = false
        #expect(try repository.deleteAll() == TrackerSnapshot())
        #expect(try repository.load() == TrackerSnapshot())
    }

    @Test func editsDeletionAndSourceChangesNeverRecreateOrOverwriteLocalRecords() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let sample = flowSample()
        var snapshot = try repository.importHealthStart(sample, confirmedStart: LocalDay(key: 20260801),
                                                        today: today, now: now, timeZone: .gmt)
        var period = try #require(snapshot.periods.first)
        period.start = try LocalDay(key: 20260802)
        snapshot = try repository.update(period, today: today, now: now)
        let changed = flowSample(id: sample.id, value: 4)
        #expect(throws: (any Error).self) {
            try repository.importHealthStart(changed, confirmedStart: LocalDay(key: 20260803), today: today, now: now, timeZone: .gmt)
        }
        #expect(try repository.load() == snapshot)
        snapshot = try repository.delete(id: period.id)
        #expect(snapshot.periods.isEmpty && snapshot.healthImports.count == 1)
        #expect(throws: (any Error).self) {
            try repository.importHealthStart(sample, confirmedStart: LocalDay(key: 20260801), today: today, now: now, timeZone: .gmt)
        }
    }

    @Test func v5MigrationAndReopenPreserveEveryRecordAndReceipt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v5.store")
        let period = Period(start: today, createdAt: now)
        let symptom = SymptomEntry(day: today, kind: .headache, createdAt: now)
        let activity = SexualActivityEntry(day: today, activities: [.other], createdAt: now)
        var profile = LocalProfile(); profile.preferredName = "Synthetic"; profile.birthDayKey = 19950101
        try autoreleasepool {
            let schema = Schema(versionedSchema: TrackerSchemaV5.self)
            let config = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.insert(TrackerSchemaV2.PeriodRecord(period))
            context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
            context.insert(TrackerSchemaV3.SymptomRecord(symptom))
            context.insert(TrackerSchemaV5.SexualActivityRecord(activity))
            context.insert(try TrackerSchemaV4.ProfileRecord(profile))
            try context.save()
        }
        var saved = TrackerSnapshot()
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let migrated = try repository.load()
            #expect(migrated.periods == [period] && migrated.symptoms == [symptom])
            #expect(migrated.profile == profile && migrated.sexualActivities == [activity])
            #expect(migrated.onboardingCompletedAt == now && migrated.healthImports.isEmpty)
            saved = try repository.importHealthStart(flowSample(), confirmedStart: LocalDay(key: 20260801),
                                                     today: today, now: now, timeZone: .gmt)
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == saved)
    }
}

@MainActor private final class FakeHealthReader: HealthFlowReading {
    var isAvailable = true
    var requests = 0
    var reads = 0
    var values: [HealthFlowSample] = []
    var fail = false
    var holdRead = false
    var continuation: CheckedContinuation<[HealthFlowSample], Never>?
    func requestReadAccess() async throws { requests += 1 }
    func samples(from start: Date, through end: Date) async throws -> [HealthFlowSample] {
        reads += 1
        if fail { throw HealthImportError.unavailable }
        if holdRead { return await withCheckedContinuation { continuation = $0 } }
        return values
    }
}

@MainActor struct PhaseSixStateTests {
    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<500 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(2))
        }
        #expect(predicate(), "Timed out waiting for fake Health reader")
    }

    @Test func noImplicitPermissionEmptyIsNotDenialAndUnavailableNeverRequests() async {
        let reader = FakeHealthReader()
        let review = HealthImportReview(reader: reader)
        #expect(reader.requests == 0 && review.state == .off)
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { true })
        await waitUntil { !review.isBusy }
        #expect(review.state == .empty && review.message == nil && reader.requests == 1)
        review.stop()
        reader.isAvailable = false
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { true })
        #expect(review.state == .failed && reader.requests == 1)
    }

    @Test func identityUsesUUIDNotDateAndStopRejectsLateRead() async {
        let reader = FakeHealthReader()
        let first = flowSample()
        let second = flowSample(source: "another.source")
        reader.values = [first, first, second, flowSample(value: 5)]
        let review = HealthImportReview(reader: reader)
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { true })
        await waitUntil { !review.isBusy }
        #expect(review.samples.count == 2 && review.contains(first) && review.contains(second))
        reader.holdRead = true
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { true })
        await waitUntil { reader.continuation != nil }
        review.stop()
        reader.continuation?.resume(returning: [first])
        reader.continuation = nil
        try? await Task.sleep(for: .milliseconds(20))
        #expect(review.state == .off && review.samples.isEmpty)
    }

    @Test func lostAccessRejectsLateResultsEvenWithoutViewCallbacks() async {
        let reader = FakeHealthReader()
        reader.holdRead = true
        let review = HealthImportReview(reader: reader)
        var accessible = true
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { accessible })
        await waitUntil { reader.continuation != nil }
        accessible = false
        reader.continuation?.resume(returning: [flowSample()])
        reader.continuation = nil
        await waitUntil { !review.isBusy }
        #expect(review.state == .off && review.samples.isEmpty)
    }

    @Test func accessGateAndReadFailurePreserveLocalTracking() async {
        let reader = FakeHealthReader()
        let review = HealthImportReview(reader: reader)
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { false })
        #expect(reader.requests == 0 && review.state == .off)
        reader.fail = true
        review.begin(months: 12, now: Date(), timeZone: .gmt, canAccess: { true })
        await waitUntil { !review.isBusy }
        #expect(review.state == .failed && review.samples.isEmpty)
    }

    @Test func sessionRequiresReviewRecalculatesAndStopsOnReset() async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let today = try LocalDay(key: 20260929)
        let periods = try [20260410, 20260509, 20260607].map { Period(start: try LocalDay(key: $0)) }
        _ = try repository.add(periods, completingOnboarding: true, today: today, now: today.formattingDate)
        let reader = FakeHealthReader()
        let sample = flowSample(start: "2026-07-05T00:00:00Z", end: "2026-07-05T12:00:00Z")
        reader.values = [sample]
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt }, healthReader: reader)
        session.load()
        let before = session.snapshot
        #expect(try session.importHealthStart(sample, confirmedStart: LocalDay(key: 20260705)) != nil)
        #expect(session.snapshot == before && session.overview?.estimate == nil)
        session.reviewAppleHealth(months: 12)
        await waitUntil { !session.healthImport.isBusy }
        #expect(session.snapshot == before)
        #expect(try session.importHealthStart(sample, confirmedStart: LocalDay(key: 20260705)) == nil)
        #expect(session.snapshot.periods.count == 4 && session.overview?.estimate != nil)
        #expect(session.deleteAll() == nil)
        #expect(session.healthImport.state == .off && session.snapshot.healthImports.isEmpty)
        #expect(try repository.load() == TrackerSnapshot())
    }
}
