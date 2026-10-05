import AuthenticationServices
import Foundation
import SwiftData
import Testing
@testable import cecy

private actor RegistrySpy: UserRegistryServing {
    struct Call: Equatable, Sendable { let id: String; let name: String? }
    private(set) var calls: [Call] = []
    var error: UserRegistryError?
    private var hold = false
    private var continuation: CheckedContinuation<Void, Never>?
    func configure(error: UserRegistryError? = nil, hold: Bool = false) { self.error = error; self.hold = hold }
    func release() { hold = false; continuation?.resume(); continuation = nil }
    func activate(id: String, displayName: String) async throws { try await send(Call(id: id, name: displayName)) }
    func deactivate(id: String) async throws { try await send(Call(id: id, name: nil)) }
    private func send(_ call: Call) async throws {
        calls.append(call)
        if hold { await withCheckedContinuation { continuation = $0 } }
        if let error { throw error }
    }
}

@MainActor private final class RegistryTestStore: RegistryOperationStoring {
    enum Failure: Error { case disk }
    var data = Data("[]".utf8)
    var failWrites = false
    func load() throws -> [RegistryOperation] { try JSONDecoder().decode([RegistryOperation].self, from: data) }
    func save(_ operations: [RegistryOperation]) throws {
        if failWrites { throw Failure.disk }
        data = try JSONEncoder().encode(operations)
    }
}

@MainActor private final class RegistryIdentityStore: AppleIdentityStoring {
    var identity: AppleIdentity?
    var failClear = false
    func load() -> AppleIdentity? { identity }
    func save(_ identity: AppleIdentity) { self.identity = identity }
    func clear() throws {
        if failClear { throw AccountError.storage }
        identity = nil
    }
}

@MainActor struct UserRegistryLifecycleTests {
    private let rawID = "synthetic-apple-user"
    private func eventually(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Registry did not reach the expected state")
    }

    @Test func retriesSurviveRecreationWithoutLeakingRawIdentity() async throws {
        let store = RegistryTestStore()
        let spy = RegistrySpy()
        await spy.configure(error: .network)
        let first = UserRegistryCoordinator(service: spy, store: store)
        #expect(first.activate(appleUserID: rawID, displayName: "Synthetic"))
        first.resume()
        try await eventually { first.operations.first?.attempts == 1 }
        first.pause()
        #expect(first.operations.first?.nextAttempt ?? .distantPast > Date())
        #expect(!String(decoding: store.data, as: UTF8.self).contains(rawID))
        let replacementStore = RegistryTestStore()
        replacementStore.data = store.data
        let nextSpy = RegistrySpy()
        let next = UserRegistryCoordinator(service: nextSpy, store: replacementStore,
                                           clock: { Date().addingTimeInterval(600) })
        next.resume()
        defer { next.pause() }
        try await eventually { await nextSpy.calls.count == 1 && next.operations.isEmpty }
        #expect(try replacementStore.load().isEmpty)
    }

    @Test func deletionIntentWaitsAndContainsNoNameThenRetriesAfterRelaunch() async throws {
        let store = RegistryTestStore()
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy, store: store)
        #expect(queue.activate(appleUserID: rawID, displayName: "Synthetic Name"))
        try queue.prepareDeletion(appleUserID: rawID)
        queue.resume()
        await Task.yield()
        #expect(await spy.calls.isEmpty)
        #expect(queue.operations.first?.kind == .deleting)
        #expect(!String(decoding: store.data, as: UTF8.self).contains("Synthetic Name"))
        #expect(!String(decoding: store.data, as: UTF8.self).contains(rawID))
        await spy.configure(error: .rejected(503))
        queue.completeDeletion()
        try await eventually { queue.operations.first?.attempts == 1 }
        queue.pause()
        let restoredStore = RegistryTestStore()
        restoredStore.data = store.data
        let nextSpy = RegistrySpy()
        let restored = UserRegistryCoordinator(service: nextSpy, store: restoredStore, clock: { Date().addingTimeInterval(600) })
        restored.resume()
        defer { restored.pause() }
        try await eventually { await nextSpy.calls.count == 1 && restored.operations.isEmpty }
        #expect(await nextSpy.calls.first?.name == nil)
        #expect(try restoredStore.load().isEmpty)
    }

    @Test func lateActivationCannotEraseDeletionAndRequestsStaySerialized() async throws {
        let spy = RegistrySpy()
        await spy.configure(hold: true)
        let queue = UserRegistryCoordinator(service: spy)
        queue.activate(appleUserID: rawID, displayName: "Synthetic")
        queue.resume()
        defer { queue.pause() }
        try await eventually { await spy.calls.count == 1 }
        try queue.prepareDeletion(appleUserID: rawID)
        queue.completeDeletion()
        #expect(await spy.calls.count == 1)
        await spy.release()
        try await eventually { await spy.calls.count == 2 && queue.operations.isEmpty }
        #expect(await spy.calls.map(\.name) == ["Synthetic", nil])
    }

    @Test func newSignInSupersedesPendingDeactivationWithoutLosingOtherAccount() async throws {
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy)
        try queue.prepareDeletion(appleUserID: rawID)
        queue.completeDeletion()
        try queue.prepareDeletion(appleUserID: "synthetic-other")
        queue.completeDeletion()
        queue.activate(appleUserID: rawID, displayName: "New Synthetic")
        queue.resume()
        defer { queue.pause() }
        try await eventually { await spy.calls.count == 2 && queue.operations.isEmpty }
        let calls = await spy.calls
        #expect(calls.contains(.init(id: RegistryIdentity.id(for: rawID), name: "New Synthetic")))
        #expect(!calls.contains(.init(id: RegistryIdentity.id(for: rawID), name: nil)))
        #expect(calls.contains(.init(id: RegistryIdentity.id(for: "synthetic-other"), name: nil)))
    }

    @Test func permanentErrorsAreRetainedWithoutRetryStormAndBackoffIsCapped() async throws {
        let spy = RegistrySpy()
        await spy.configure(error: .rejected(400))
        let queue = UserRegistryCoordinator(service: spy)
        queue.activate(appleUserID: rawID, displayName: "Synthetic")
        queue.resume()
        defer { queue.pause() }
        try await eventually { queue.operations.first?.blocked == true }
        queue.resume()
        await Task.yield()
        #expect(await spy.calls.count == 1)
        #expect(queue.diagnostic != nil)
        #expect(UserRegistryCoordinator.retryDelay(attempt: 1) == 5)
        #expect(UserRegistryCoordinator.retryDelay(attempt: 2) == 10)
        #expect(UserRegistryCoordinator.retryDelay(attempt: 20) == 300)
    }

    @Test func failedSecureWritesDoNotSendAndCorruptStateIsNotOverwritten() async throws {
        let store = RegistryTestStore()
        store.failWrites = true
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy, store: store)
        #expect(!queue.activate(appleUserID: rawID, displayName: "Synthetic"))
        #expect(throws: AccountError.storage) { try queue.prepareDeletion(appleUserID: rawID) }
        queue.resume()
        defer { queue.pause() }
        await Task.yield()
        #expect(await spy.calls.isEmpty)
        let corrupt = RegistryTestStore()
        corrupt.data = Data("invalid".utf8)
        let unavailable = UserRegistryCoordinator(service: spy, store: corrupt)
        #expect(!unavailable.activate(appleUserID: rawID, displayName: "Synthetic"))
        #expect(corrupt.data == Data("invalid".utf8))
    }

    @Test func setupMustCommitBeforeActivationAndEveryNewSignInReactivates() async throws {
        let today = try LocalDay(key: 20260929)
        let memory = try SwiftDataPeriodRepository.inMemory()
        var writes = 0
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            writes += 1
            if writes == 2 { throw RegistryTestStore.Failure.disk }
            try $0.save()
        })
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy)
        let account = AppleAccount()
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt },
                                     account: account, registry: queue)
        session.load()
        session.resumeRegistry()
        defer { queue.pause() }
        var draft = OnboardingDraft()
        draft.profile.preferredName = "Synthetic Alex"
        draft.profile.birthDayKey = 19950512
        draft.profile.typicalPeriodDays = 5
        draft.periods = [Period(start: try LocalDay(key: 20260902))]
        try account.link(userID: rawID, profileID: draft.profile.id, protectsExistingProfile: false)
        #expect(queue.operations.isEmpty)
        #expect(await session.finishSetup(draft) != nil)
        #expect(queue.operations.isEmpty)
        #expect(await spy.calls.isEmpty)
        #expect(await session.finishSetup(draft) == nil)
        try await eventually { await spy.calls.count == 1 && queue.operations.isEmpty }
        session.refresh(); session.resumeRegistry()
        await Task.yield()
        #expect(await spy.calls.count == 1)
        #expect(session.logOut() == nil)
        #expect(queue.operations.isEmpty)
        try account.link(userID: rawID, profileID: draft.profile.id, protectsExistingProfile: true)
        session.load()
        try await eventually { await spy.calls.count == 2 && queue.operations.isEmpty }
        #expect(await spy.calls.allSatisfy { $0.name == "Synthetic Alex" })
    }

    @Test func cancelledFailedOrStaleAuthorizationNeverEnqueues() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let queue = UserRegistryCoordinator()
        let account = AppleAccount()
        let session = TrackerSession(repository: { repository }, account: account, registry: queue)
        session.load()
        let profileID = UUID()
        for code in [ASAuthorizationError.canceled, ASAuthorizationError.failed] {
            let token = account.beginAuthorization()
            #expect(!account.accept(.failure(ASAuthorizationError(code)), token: token,
                                    profileID: profileID, protectsExistingProfile: false))
        }
        let stale = account.beginAuthorization()
        account.cancelPendingAuthorization()
        #expect(!account.accept(.failure(AccountError.unavailable), token: stale,
                                profileID: profileID, protectsExistingProfile: false))
        #expect(queue.operations.isEmpty)
    }

    @Test(arguments: [false, true]) func partialDeletionRetainsIDAndNeverPatchesUntilRetry(signedOut: Bool) async throws {
        let today = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add([Period(start: today)], completingOnboarding: true, today: today, now: today.formattingDate)
        let identityStore = RegistryIdentityStore()
        let account = AppleAccount(store: identityStore)
        try account.link(userID: rawID, profileID: UUID(), protectsExistingProfile: false)
        if signedOut { try account.signOut() }
        let store = RegistryTestStore()
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy, store: store)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt },
                                     account: account, registry: queue)
        session.load(); session.resumeRegistry()
        defer { queue.pause() }
        identityStore.failClear = true
        #expect(await session.deleteAllAndWait() != nil)
        #expect(try repository.load() == TrackerSnapshot())
        #expect(account.identity != nil)
        #expect(queue.operations.first?.kind == .deleting)
        await Task.yield()
        #expect(await spy.calls.isEmpty)
        identityStore.failClear = false
        #expect(await session.deleteAllAndWait() == nil)
        try await eventually { await spy.calls.count == 1 && queue.operations.isEmpty }
        #expect(account.identity == nil)
        #expect(await spy.calls.first?.name == nil)
    }

    @Test func healthStoreFailurePreservesIdentityAndDoesNotDeactivate() async throws {
        let today = try LocalDay(key: 20260929)
        let memory = try SwiftDataPeriodRepository.inMemory()
        _ = try memory.add([Period(start: today)], completingOnboarding: true, today: today, now: today.formattingDate)
        let repository = SwiftDataPeriodRepository(container: memory.container, save: { _ in throw RegistryTestStore.Failure.disk })
        let account = AppleAccount()
        try account.link(userID: rawID, profileID: UUID(), protectsExistingProfile: false)
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, account: account, registry: queue)
        session.load(); session.resumeRegistry()
        defer { queue.pause() }
        #expect(await session.deleteAllAndWait() != nil)
        #expect(account.identity?.userID == rawID)
        #expect(try repository.load().periods.count == 1)
        #expect(queue.operations.first?.kind == .deleting)
        #expect(await spy.calls.isEmpty)
    }

    @Test func lateDeactivationCannotEraseNewActivation() async throws {
        let spy = RegistrySpy()
        await spy.configure(hold: true)
        let queue = UserRegistryCoordinator(service: spy)
        try queue.prepareDeletion(appleUserID: rawID)
        queue.completeDeletion()
        queue.resume()
        defer { queue.pause() }
        try await eventually { await spy.calls.count == 1 }
        queue.activate(appleUserID: rawID, displayName: "Returning Synthetic")
        #expect(await spy.calls.count == 1)
        await spy.release()
        try await eventually { await spy.calls.count == 2 && queue.operations.isEmpty }
        #expect(await spy.calls.map(\.name) == [nil, "Returning Synthetic"])
    }

    @Test func queueWriteFailurePreventsDeletionAndResumeDoesNotDeactivateExistingRecords() async throws {
        let today = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let original = try repository.add([Period(start: today)], completingOnboarding: true,
                                          today: today, now: today.formattingDate)
        let store = RegistryTestStore()
        store.failWrites = true
        let spy = RegistrySpy()
        let queue = UserRegistryCoordinator(service: spy, store: store)
        let account = AppleAccount()
        try account.link(userID: rawID, profileID: UUID(), protectsExistingProfile: false)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, account: account, registry: queue)
        session.load()
        #expect(await session.deleteAllAndWait() != nil)
        #expect(try repository.load() == original)
        #expect(account.identity?.userID == rawID)
        store.failWrites = false
        try queue.prepareDeletion(appleUserID: rawID)
        session.load(); session.resumeRegistry()
        defer { queue.pause() }
        await Task.yield()
        #expect(queue.operations.first?.kind == .deleting)
        #expect(await spy.calls.isEmpty)
    }

    @Test func completedDeletionJournalRecoversAfterProcessRestart() async throws {
        let store = RegistryTestStore()
        let previous = UserRegistryCoordinator(store: store)
        try previous.prepareDeletion(appleUserID: rawID)
        // Simulate termination after local records/identity were cleared but before promotion.
        let spy = RegistrySpy()
        let restored = UserRegistryCoordinator(service: spy, store: store)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, registry: restored)
        session.load(); session.resumeRegistry()
        defer { restored.pause() }
        try await eventually { await spy.calls.count == 1 && restored.operations.isEmpty }
        #expect(await spy.calls.first?.name == nil)
    }
}
