import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct PhaseFiveDomainTests {
    private let now = ISO8601DateFormatter().date(from: "2026-09-29T12:00:00Z")!
    private func prediction(_ key: Int) throws -> CyclePrediction {
        let day = try LocalDay(key: key)
        return CyclePrediction(center: day, earliest: day, latest: try day.adding(days: 4), confidence: .low, sourceLengths: [28, 28, 28])
    }

    @Test func exportIsVersionedSortedAndNotesRequireConsent() throws {
        let day = try LocalDay(key: 20240229)
        let period = Period(start: day, end: try day.adding(days: 3), flow: .heavy, notes: "Synthetic private period note", createdAt: now)
        let observation = SymptomEntry(day: day, kind: .energyLevel, value: 1, notes: "Synthetic private observation note", createdAt: now)
        let snapshot = TrackerSnapshot(periods: [period], symptoms: [observation])
        for include in [false, true] {
            let data = try TrackerExport.encode(snapshot: snapshot, includeNotes: include, generatedAt: now)
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let export = try decoder.decode(TrackerExport.Document.self, from: data)
            #expect(export.formatVersion == 1 && export.generatedAt == now && export.includesPrivateNotes == include)
            let saved = try #require(export.periods.first)
            #expect(saved.id == period.id && saved.start == "2024-02-29" && saved.end == "2024-03-03")
            #expect(saved.flow == "heavy" && saved.createdAt == now)
            let entry = try #require(export.observations.first)
            #expect(entry.id == observation.id && entry.type == "energyLevel" && entry.rating == 1 && entry.ratingLabel == "Low")
            #expect(saved.notes == (include ? period.notes : nil) && entry.notes == (include ? observation.notes : nil))
            #expect(!String(decoding: data, as: UTF8.self).contains("prediction"))
        }
        let empty = try TrackerExport.encode(snapshot: TrackerSnapshot(), includeNotes: false, generatedAt: now)
        #expect(!empty.isEmpty)
        #expect(try TrackerExport.civilDate(LocalDay(key: 10101)) == "0001-01-01")
        // Export structurally valid future civil dates without hiding records needing correction.
        let future = try Period(start: LocalDay(key: 20990101))
        #expect(try !TrackerExport.encode(snapshot: TrackerSnapshot(periods: [future]), includeNotes: false, generatedAt: now).isEmpty)
        #expect(throws: TrackingError.duplicateStart) {
            try TrackerExport.encode(snapshot: TrackerSnapshot(periods: [period, Period(start: day)]), includeNotes: false, generatedAt: now)
        }
    }

    @Test func remindersAreOptInBoundedAndNeverCatchUp() throws {
        var preferences = PrivacyPreferences()
        #expect(try ReminderPlanner.requests(preferences: preferences, prediction: prediction(20261001), now: now, timeZone: .gmt).isEmpty)
        preferences.dailyReminder = true; preferences.windowReminder = true
        let requests = try ReminderPlanner.requests(preferences: preferences, prediction: prediction(20261001), now: now, timeZone: .gmt)
        #expect(requests.count == 2 && Set(requests.map(\.id)).count == 2)
        #expect(requests[0].kind == .daily && requests[0].day == nil)
        #expect(requests[1].day?.key == 20260930 && requests[1].hour == 20)
        #expect(try ReminderPlanner.requests(preferences: preferences, prediction: nil, now: now, timeZone: .gmt).count == 1)
        let past = try ReminderPlanner.requests(preferences: preferences, prediction: prediction(20260929), now: now, timeZone: .gmt)
        #expect(past.count == 1)
        let exact = ISO8601DateFormatter().date(from: "2026-09-30T20:00:00Z")!
        #expect(try ReminderPlanner.requests(preferences: preferences, prediction: prediction(20261001), now: exact, timeZone: .gmt).count == 1)
        preferences.reminderHour = 24
        #expect(throws: TrackingError.invalidData) { try preferences.validate() }
        preferences.reminderHour = 20; preferences.version = 2
        #expect(throws: TrackingError.invalidData) { try preferences.validate() }
    }

    @Test func reminderCivilDatesResolveDSTLeapDayAndTravel() throws {
        var preferences = PrivacyPreferences(); preferences.windowReminder = true
        preferences.reminderHour = 2; preferences.reminderMinute = 30
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let before = ISO8601DateFormatter().date(from: "2026-03-07T00:00:00Z")!
        let spring = try #require(ReminderPlanner.requests(preferences: preferences, prediction: prediction(20260309), now: before, timeZone: zone).first)
        #expect(spring.day?.key == 20260308 && spring.hour == 3 && spring.minute == 0)
        let old = ISO8601DateFormatter().date(from: "2024-02-01T00:00:00Z")!
        #expect(try ReminderPlanner.requests(preferences: preferences, prediction: prediction(20240301), now: old, timeZone: zone).first?.day?.key == 20240229)
        preferences.reminderHour = 20; preferences.reminderMinute = 0
        let estimate = try prediction(20260930)
        let east = try ReminderPlanner.requests(preferences: preferences, prediction: estimate, now: now, timeZone: TimeZone(secondsFromGMT: 14 * 3600)!)
        let west = try ReminderPlanner.requests(preferences: preferences, prediction: estimate, now: now, timeZone: TimeZone(secondsFromGMT: -12 * 3600)!)
        #expect(east.isEmpty && west.count == 1)
    }

    @Test func reminderDetailsAreExplicitAndMessagesMatchTheirPurpose() throws {
        let legacy = Data(#"{"version":1,"lockEnabled":false,"dailyReminder":true,"windowReminder":true,"reminderHour":20,"reminderMinute":0}"#.utf8)
        var preferences = try JSONDecoder().decode(PrivacyPreferences.self, from: legacy)
        #expect(preferences.reminderDetailsEnabled == nil)
        for enabled in [false, true] {
            preferences.reminderDetailsEnabled = enabled
            let requests = try ReminderPlanner.requests(preferences: preferences, prediction: prediction(20261001), now: now, timeZone: .gmt)
            #expect(requests.count == 2)
            #expect(requests.allSatisfy { $0.showDetails == enabled })
            for request in requests {
                let body = request.kind.notificationBody(showDetails: request.showDetails)
                #expect(body.count < 100)
                #expect(!body.contains("A reminder you asked for"))
                if !enabled {
                    #expect(!body.contains("period") && !body.contains("symptoms"))
                }
            }
        }
        #expect(ReminderRequest.Kind.daily.notificationBody(showDetails: true) == "Log your period, symptoms or how you feel today.")
        #expect(ReminderRequest.Kind.window.notificationBody(showDetails: true) == "Check your estimated period start window in Cecy.")
        #expect(!ReminderRequest.Kind.window.notificationBody(showDetails: true).contains("tomorrow"))
        #expect(ReminderRequest.Kind.daily.notificationTitle(showDetails: true) == "Daily check-in")
        #expect(ReminderRequest.Kind.window.notificationTitle(showDetails: true) == "Period window")
        #expect(try JSONDecoder().decode(PrivacyPreferences.self, from: JSONEncoder().encode(preferences)) == preferences)
    }
}

@MainActor private final class TestPreferences: PrivacyPreferenceStoring {
    enum Failure: Error { case disk }
    var value = PrivacyPreferences()
    var failLoad = false
    var failSave = false
    func load() throws -> PrivacyPreferences { if failLoad { throw Failure.disk }; return value }
    func save(_ value: PrivacyPreferences) throws { if failSave { throw Failure.disk }; self.value = value }
}

@MainActor private final class TestAuthentication: DeviceAuthenticating {
    var result = true
    var suspend = false
    var pending: CheckedContinuation<Bool, Never>?
    var cancellations = 0
    var attempts = 0
    func authenticate(reason: String) async -> Bool {
        attempts += 1
        if suspend { return await withCheckedContinuation { pending = $0 } }
        return result
    }
    func cancel() { cancellations += 1 }
    func finish(_ value: Bool) { let saved = pending; pending = nil; saved?.resume(returning: value) }
}

@MainActor private final class TestExports: ExportFileManaging {
    var fail = false
    var data: Data?
    func prepare(_ data: Data) throws -> URL {
        if fail { throw TestPreferences.Failure.disk }
        self.data = data
        return URL(fileURLWithPath: "/synthetic/Cecy-export.json")
    }
    func clean() throws { if fail { throw TestPreferences.Failure.disk }; data = nil }
}

@MainActor private final class TestReminders: ReminderDelivering {
    var permission: ReminderAuthorization = .allowed
    var grant = true
    var permissionRequests = 0
    var requests: [ReminderRequest] = []
    var failAdd = false
    var suspendAdd = false
    var pending: CheckedContinuation<Void, Never>?
    func authorization() -> ReminderAuthorization { permission }
    func requestPermission() -> Bool {
        permissionRequests += 1
        permission = grant ? .allowed : .denied
        return grant
    }
    func clear() { requests = [] }
    func add(_ request: ReminderRequest) async throws {
        if suspendAdd { suspendAdd = false; await withCheckedContinuation { pending = $0 } }
        if failAdd { throw TestPreferences.Failure.disk }
        requests.append(request)
    }
    func finishAdd() { let saved = pending; pending = nil; saved?.resume() }
}

@MainActor struct PhaseFivePrivacyTests {
    private func controller(_ preferences: TestPreferences? = nil, auth: TestAuthentication? = nil,
                            exports: TestExports? = nil, delivery: TestReminders? = nil) -> TrackerPrivacy {
        TrackerPrivacy(storage: preferences ?? TestPreferences(), authentication: auth ?? TestAuthentication(),
                       exports: exports ?? TestExports(), delivery: delivery ?? TestReminders())
    }
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 { if condition() { return }; await Task.yield() }
    }

    @Test func corruptPreferencesFailClosedAndRetryPreservesLock() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FilePrivacyPreferences(url: directory.appendingPathComponent("preferences.json"))
        #expect(try store.load() == PrivacyPreferences())
        var saved = PrivacyPreferences(); saved.lockEnabled = true
        try store.save(saved)
        #expect(try FilePrivacyPreferences(url: store.url).load() == saved)
        try Data("invalid JSON".utf8).write(to: store.url)
        let privacy = TrackerPrivacy(storage: store, authentication: TestAuthentication(), exports: TestExports(), delivery: TestReminders())
        privacy.start()
        #expect(!privacy.isReady && privacy.isLocked && privacy.startupError != nil)
        try store.save(saved)
        privacy.start()
        #expect(privacy.isReady && privacy.isLocked && !privacy.canAccess)
    }

    @Test func lockedStartupDoesNotOpenRepositoryAndCancelNeverUnlocks() async throws {
        let store = TestPreferences(); store.value.lockEnabled = true
        let auth = TestAuthentication(); auth.result = false
        let privacy = controller(store, auth: auth)
        var opened = 0
        let session = TrackerSession(repository: { opened += 1; return try SwiftDataPeriodRepository.inMemory() }, privacy: privacy)
        session.load(); privacy.start(); session.load()
        #expect(opened == 0 && privacy.isLocked)
        await privacy.unlock()
        #expect(!privacy.canAccess && privacy.message != nil)
        auth.result = true
        await privacy.unlock(); session.load()
        #expect(opened == 1 && privacy.canAccess)
        privacy.wentToBackground(); session.refresh()
        #expect(privacy.isLocked && opened == 1)
        #expect(session.save([]) != nil && session.deleteAll() != nil)
    }

    @Test func automaticUnlockAttemptsOnceAndManualRetryRemainsAvailable() async {
        let store = TestPreferences(); store.value.lockEnabled = true
        let auth = TestAuthentication(); auth.result = false
        let privacy = controller(store, auth: auth); privacy.start()
        await privacy.unlockAutomatically()
        #expect(privacy.isLocked && auth.attempts == 1)
        await privacy.unlockAutomatically()
        #expect(privacy.isLocked && auth.attempts == 1)
        auth.result = true
        await privacy.unlock()
        #expect(privacy.canAccess && auth.attempts == 2)
        privacy.lockNow()
        await privacy.unlockAutomatically()
        #expect(privacy.isLocked && auth.attempts == 2)
        privacy.wentToBackground()
        await privacy.unlockAutomatically()
        #expect(privacy.canAccess && auth.attempts == 3)
    }

    @Test func backgroundInvalidatesAutomaticAuthentication() async {
        let store = TestPreferences(); store.value.lockEnabled = true
        let auth = TestAuthentication(); auth.suspend = true
        let privacy = controller(store, auth: auth); privacy.start()
        let task = Task { await privacy.unlockAutomatically() }
        await waitUntil { auth.pending != nil }
        #expect(auth.pending != nil)
        await privacy.unlockAutomatically()
        #expect(auth.attempts == 1)
        privacy.wentToBackground()
        auth.finish(true); await task.value
        #expect(privacy.isLocked && !privacy.isAuthenticating)
        auth.suspend = false
        await privacy.unlockAutomatically()
        #expect(privacy.canAccess && auth.attempts == 2)
    }

    @Test func staleAuthenticationCannotUnlockOrEnableLock() async throws {
        let store = TestPreferences(); store.value.lockEnabled = true
        let auth = TestAuthentication(); auth.suspend = true
        let privacy = controller(store, auth: auth); privacy.start()
        let task = Task { await privacy.unlock() }
        await waitUntil { auth.pending != nil }
        #expect(auth.pending != nil)
        privacy.wentToBackground()
        auth.finish(true); await task.value
        #expect(privacy.isLocked && !privacy.isAuthenticating && auth.cancellations == 1)
        auth.suspend = false; await privacy.unlock()
        #expect(privacy.canAccess)
        auth.result = false; await privacy.setLockEnabled(false)
        #expect(store.value.lockEnabled)
        auth.result = true; await privacy.setLockEnabled(false)
        #expect(!store.value.lockEnabled)
        auth.suspend = true
        let enable = Task { await privacy.setLockEnabled(true) }
        await waitUntil { auth.pending != nil }
        privacy.wentToBackground(); auth.finish(true); await enable.value
        #expect(!store.value.lockEnabled)
    }

    @Test func failedPreferenceWritesKeepPreviousSecurityChoice() async {
        let store = TestPreferences(); let privacy = controller(store); privacy.start()
        store.failSave = true
        await privacy.setLockEnabled(true)
        #expect(!privacy.preferences.lockEnabled && privacy.message != nil)
        store.failSave = false; await privacy.setLockEnabled(true)
        store.failSave = true; await privacy.setLockEnabled(false)
        #expect(privacy.preferences.lockEnabled && store.value.lockEnabled)
    }

    @Test func exportCleanupAndFailureNeverResetRecords() async throws {
        let exports = TestExports(); let privacy = controller(exports: exports); privacy.start()
        privacy.export(snapshot: TrackerSnapshot(), includeNotes: false)
        #expect(exports.data != nil && privacy.preparedExport != nil)
        privacy.wentToBackground()
        #expect(exports.data == nil && privacy.preparedExport == nil)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, privacy: privacy)
        session.load()
        #expect(try session.save([Period(start: LocalDay(key: 20240101))], completingOnboarding: true) == nil)
        let original = session.snapshot
        exports.fail = true
        #expect(await session.deleteAllAndWait() != nil)
        #expect(session.snapshot == original)
        #expect(try repository.load() == original)
        privacy.cleanupExport(); #expect(privacy.message != nil)
        exports.fail = false
        #expect(await session.deleteAllAndWait() == nil)
        #expect(session.snapshot == TrackerSnapshot())
    }

    @Test func exportsExcludeBackupsAndCleanupIsScoped() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let unrelated = root.appendingPathComponent("keep.txt")
        try Data("Synthetic".utf8).write(to: unrelated)
        let exports = ProtectedExportFiles(directory: root.appendingPathComponent("exports"))
        let url = try exports.prepare(Data("{}".utf8))
        #expect(try Data(contentsOf: url) == Data("{}".utf8))
        #expect(try exports.directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        try exports.clean(); try exports.clean()
        #expect(!FileManager.default.fileExists(atPath: url.path) && FileManager.default.fileExists(atPath: unrelated.path))
    }

    #if targetEnvironment(simulator)
    @Test(.disabled("Simulator does not expose iOS file-protection attributes; run on a physical iOS device."))
    #else
    @Test
    #endif
    func completeProtectionCoversExportsStoresAndSidecars() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let exports = ProtectedExportFiles(directory: root.appendingPathComponent("exports"))
        let export = try exports.prepare(Data("{}".utf8))
        let store = root.appendingPathComponent("store")
        let nested = store.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let files = ["tracker.store", "tracker.store-wal", "tracker.store-shm", "nested/synthetic.json"].map {
            store.appendingPathComponent($0)
        }
        for file in files { try Data().write(to: file) }
        try ProtectedFiles.protectTree(store)
        for url in [export, exports.directory, store, nested] + files {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let value = try #require(attributes[.protectionKey])
            let protection = (value as? FileProtectionType)?.rawValue ?? (value as? String)
            #expect(protection == FileProtectionType.complete.rawValue, "Complete protection required for \(url.lastPathComponent)")
        }
    }

    @Test func permissionsAreOnlyRequestedByUserAndRevocationClearsRequests() async {
        let store = TestPreferences(); let delivery = TestReminders(); delivery.permission = .notDetermined; delivery.grant = false
        let privacy = controller(store, delivery: delivery); privacy.start(); await privacy.reminders.flush()
        #expect(delivery.permissionRequests == 0 && delivery.requests.isEmpty)
        await privacy.setReminders(daily: true, window: false, hour: 20, minute: 0)
        #expect(delivery.permissionRequests == 1 && !privacy.preferences.dailyReminder)
        delivery.permission = .allowed
        await privacy.setReminders(daily: true, window: false, hour: 20, minute: 0)
        #expect(delivery.requests.count == 1 && privacy.preferences.dailyReminder)
        delivery.permission = .denied
        privacy.trackingChanged(prediction: nil, now: Date(), timeZone: .gmt)
        await privacy.reminders.flush()
        #expect(delivery.requests.isEmpty && privacy.reminders.status.contains("disabled"))
        #expect(delivery.permissionRequests == 1)
    }

    @Test func failedSchedulingClearsPartialRequestsAndRetries() async {
        let delivery = TestReminders(); delivery.failAdd = true
        let coordinator = ReminderCoordinator(delivery: delivery)
        let request = ReminderRequest(kind: .daily, hour: 20, minute: 0, day: nil)
        coordinator.replace(with: [request], enabled: true); await coordinator.flush()
        #expect(delivery.requests.isEmpty && coordinator.status.contains("could not"))
        delivery.failAdd = false
        coordinator.replace(with: [request], enabled: true); await coordinator.flush()
        #expect(delivery.requests == [request])
    }

    @Test func detailChoicePersistsAndFailedOrDeniedSavesDoNotEnableIt() async {
        let store = TestPreferences(); let delivery = TestReminders()
        let privacy = controller(store, delivery: delivery); privacy.start()
        store.failSave = true
        #expect(await privacy.setReminders(daily: true, window: false, hour: 20, minute: 0, showDetails: true) == .failed)
        #expect(privacy.preferences.reminderDetailsEnabled != true)
        store.failSave = false; delivery.permission = .denied
        #expect(await privacy.setReminders(daily: true, window: false, hour: 20, minute: 0, showDetails: true) == .permissionUnavailable)
        #expect(store.value.reminderDetailsEnabled != true)
        delivery.permission = .allowed
        #expect(await privacy.setReminders(daily: true, window: false, hour: 20, minute: 0, showDetails: true) == .saved)
        #expect(delivery.requests.first?.showDetails == true)
        let reopened = controller(store); reopened.start()
        #expect(reopened.preferences.reminderDetailsEnabled == true)
        await privacy.setReminders(daily: true, window: false, hour: 9, minute: 30)
        #expect(delivery.requests.first?.showDetails == true)
        await privacy.setReminders(daily: true, window: false, hour: 9, minute: 30, showDetails: false)
        #expect(delivery.requests.count == 1 && delivery.requests.first?.showDetails == false)
        #expect(store.value.reminderDetailsEnabled == false)
    }

    @Test func resetWaitsForInFlightAddAndClearsEverythingButLock() async throws {
        let store = TestPreferences(); store.value.dailyReminder = true
        let delivery = TestReminders(); delivery.suspendAdd = true
        let privacy = controller(store, delivery: delivery); privacy.start()
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, privacy: privacy)
        session.load()
        #expect(try session.save([Period(start: LocalDay(key: 20240101))], completingOnboarding: true) == nil)
        await privacy.setLockEnabled(true)
        await waitUntil { delivery.pending != nil }
        #expect(delivery.pending != nil)
        var done = false
        let reset = Task { let result = await session.deleteAllAndWait(); done = true; return result }
        await waitUntil { !privacy.preferences.dailyReminder }
        #expect(!done && !session.snapshot.periods.isEmpty)
        delivery.finishAdd()
        #expect(await reset.value == nil)
        await privacy.reminders.flush()
        #expect(delivery.requests.isEmpty && session.snapshot == TrackerSnapshot())
        #expect(privacy.preferences.lockEnabled && store.value.lockEnabled && !store.value.dailyReminder)
    }

    @Test func latestReminderRevisionWinsWithoutDuplicateRequests() async {
        let delivery = TestReminders(); delivery.suspendAdd = true
        let coordinator = ReminderCoordinator(delivery: delivery)
        let first = ReminderRequest(kind: .daily, hour: 20, minute: 0, day: nil)
        let last = ReminderRequest(kind: .daily, hour: 9, minute: 30, day: nil)
        coordinator.replace(with: [first], enabled: true)
        await waitUntil { delivery.pending != nil }
        coordinator.replace(with: [last], enabled: true)
        delivery.finishAdd(); await coordinator.flush()
        #expect(delivery.requests == [last])
    }
}
