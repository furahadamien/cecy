import Foundation
import Testing
@testable import cecy

@MainActor
struct FinalEngineeringTests {
    private final class PausedReminderDelivery: ReminderDelivering {
        var pauseNextClear = false
        var continuation: CheckedContinuation<Void, Never>?
        func authorization() -> ReminderAuthorization { .allowed }
        func requestPermission() -> Bool { true }
        func add(_ request: ReminderRequest) {}
        func clear() async {
            guard pauseNextClear else { return }
            pauseNextClear = false
            await withCheckedContinuation { continuation = $0 }
        }
        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    @Test(arguments: [false, true])
    func resetRejectsWritesWhileAncillaryCleanupIsSuspended(cancelled: Bool) async throws {
        let day = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let delivery = PausedReminderDelivery()
        let privacy = TrackerPrivacy(storage: MemoryPrivacyPreferences(), authentication: FixedDeviceAuthentication(),
            exports: ProtectedExportFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
            delivery: delivery)
        privacy.start()
        let session = TrackerSession(repository: { repository }, clock: { day.formattingDate }, timeZone: { .gmt }, privacy: privacy)
        session.load()
        let original = Period(start: try day.adding(days: -28))
        #expect(session.save([original]) == nil)
        await privacy.reminders.flush()
        delivery.pauseNextClear = true
        let reset = Task { await session.deleteAllAndWait() }
        for _ in 0..<1_000 {
            if delivery.continuation != nil { break }
            await Task.yield()
        }
        defer { delivery.resume() }
        try #require(delivery.continuation != nil)
        #expect(session.isSaving)
        #expect(session.save([Period(start: day)]) != nil)
        #expect(session.deleteAll() != nil)
        if cancelled { reset.cancel() }
        delivery.resume()
        let result = await reset.value
        #expect((result != nil) == cancelled)
        #expect(!session.isSaving)
        #expect(try repository.load().periods.map(\.id) == (cancelled ? [original.id] : []))
    }

    @Test func resetCannotOvertakePendingPredictionUpdate() async throws {
        let day = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { day.formattingDate }, timeZone: { .gmt })
        session.load()
        let reset = Task {
            #expect(session.isUpdatingPredictions)
            #expect(await session.deleteAllAndWait() != nil)
            #expect(session.deleteAll() != nil)
        }
        let result = await session.withPredictionUpdate { session.save([Period(start: day)]) }
        await reset.value
        #expect(result == nil)
        #expect(try repository.load().periods.count == 1)
    }
}
