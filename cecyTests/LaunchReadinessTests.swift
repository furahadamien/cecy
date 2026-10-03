import Foundation
import SwiftData
import Testing
@testable import cecy

@MainActor
struct LaunchReadinessTests {
    private enum Failure: Error { case keychain }

    @MainActor private final class IdentityStore: AppleIdentityStoring {
        var identity: AppleIdentity?
        var failClear = false
        func load() -> AppleIdentity? { identity }
        func save(_ value: AppleIdentity) { identity = value }
        func clear() throws {
            if failClear { throw Failure.keychain }
            identity = nil
        }
    }

    @Test func corruptStoreFailsWithoutReplacingItsBytesOnRetry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("corrupt.store")
        let original = Data("Synthetic invalid SQLite store; preserve for recovery.".utf8)
        try original.write(to: url)
        let session = TrackerSession(repository: { try SwiftDataPeriodRepository.local(url: url) })
        for _ in 0..<2 {
            session.load()
            #expect(session.phase == .failed)
            #expect(session.failureMessage?.contains("not been reset") == true)
            #expect(session.confirmation == nil)
            #expect(session.save([]) != nil)
            #expect(try Data(contentsOf: url) == original)
        }
    }

    @Test func unreadableProfilePayloadDoesNotEraseHealthyRecordsOnReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("profile.store")
        let today = try LocalDay(key: 20260929)
        let period = Period(start: try LocalDay(key: 20260902), createdAt: today.formattingDate)
        let invalidPayload = Data("{\"unsupportedSyntheticProfile\":true}".utf8)
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            _ = try repository.add([period], completingOnboarding: true, today: today, now: today.formattingDate)
            var profile = LocalProfile()
            profile.preferredName = "Synthetic Alex"
            profile.birthDayKey = 19950512
            let record = try TrackerSchemaV4.ProfileRecord(profile)
            record.payload = invalidPayload
            let context = ModelContext(repository.container)
            context.insert(record)
            try context.save()
        }
        let repository = try SwiftDataPeriodRepository.local(url: url)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        #expect(session.phase == .failed)
        session.load()
        #expect(session.phase == .failed)
        let context = ModelContext(repository.container)
        let periods = try context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>())
        #expect(try periods.map { try $0.value() } == [period])
        let profiles = try context.fetch(FetchDescriptor<TrackerSchemaV4.ProfileRecord>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.payload == invalidPayload)
    }

    @Test func signedOutResetReportsPartialCleanupAndCanRetry() async throws {
        let today = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add([Period(start: today)], completingOnboarding: true, today: today, now: today.formattingDate)
        let store = IdentityStore()
        let account = AppleAccount(store: store)
        try account.link(userID: "synthetic-apple-user", profileID: UUID(), protectsExistingProfile: false)
        try account.signOut()
        let identity = account.identity
        store.failClear = true
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate },
                                     timeZone: { .gmt }, account: account)
        let error = await session.deleteAllAndWait()
        #expect(error?.contains("records may already be deleted") == true)
        #expect(try repository.load() == TrackerSnapshot())
        #expect(account.identity == identity)
        #expect(account.requiresSignIn)
        #expect(session.confirmation == nil)
        store.failClear = false
        #expect(await session.deleteAllAndWait() == nil)
        #expect(account.identity == nil)
        #expect(session.phase == .loaded)
        #expect(session.snapshot == TrackerSnapshot())
    }
}
