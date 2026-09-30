import Foundation
import Observation

struct PreparedExport: Identifiable {
    let url: URL
    var id: URL { url }
}

@MainActor @Observable final class TrackerPrivacy {
    private(set) var preferences = PrivacyPreferences()
    private(set) var isReady = false
    private(set) var isLocked = true
    private(set) var isAuthenticating = false
    private(set) var isChangingReminders = false
    private(set) var startupError: String?
    var message: String?
    var preparedExport: PreparedExport?
    let reminders: ReminderCoordinator
    var canAccess: Bool { isReady && !isLocked }

    @ObservationIgnored private let storage: any PrivacyPreferenceStoring
    @ObservationIgnored private let authentication: any DeviceAuthenticating
    @ObservationIgnored private let exports: any ExportFileManaging
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var prediction: CyclePrediction?
    @ObservationIgnored private var now = Date()
    @ObservationIgnored private var timeZone = TimeZone.current

    init(storage: any PrivacyPreferenceStoring, authentication: any DeviceAuthenticating,
         exports: any ExportFileManaging, delivery: any ReminderDelivering) {
        self.storage = storage
        self.authentication = authentication
        self.exports = exports
        reminders = ReminderCoordinator(delivery: delivery)
    }

    func start() {
        guard !isReady else { return }
        do {
            let loaded = try storage.load()
            try loaded.validate()
            preferences = loaded
            isLocked = loaded.lockEnabled
            isReady = true
            startupError = nil
            cleanupExport()
            if !loaded.dailyReminder && !loaded.windowReminder { reminders.replace(with: [], enabled: false) }
        } catch {
            isLocked = true
            startupError = "Privacy settings couldn’t be opened. Your records have not been reset. Unlock your device and try again."
        }
    }

    private func authenticate(_ reason: String) async -> Bool {
        guard isReady, !isAuthenticating else { return false }
        let token = generation
        isAuthenticating = true
        defer { if token == generation { isAuthenticating = false } }
        let succeeded = await authentication.authenticate(reason: reason)
        guard token == generation else { return false }
        if !succeeded { message = "Authentication was cancelled or unavailable. Try again using Face ID, Touch ID or your device passcode." }
        return succeeded
    }

    func unlock() async {
        guard isLocked else { return }
        if await authenticate("Unlock your private Cecy records") { isLocked = false; message = nil }
    }

    func setLockEnabled(_ enabled: Bool) async {
        guard canAccess, enabled != preferences.lockEnabled else { return }
        guard await authenticate(enabled ? "Enable protection for your Cecy records" : "Turn off Cecy app locking") else { return }
        var candidate = preferences
        candidate.lockEnabled = enabled
        do { try storage.save(candidate); preferences = candidate; message = nil }
        catch { message = "App-lock settings were not saved. The previous setting remains in place." }
    }

    func wentToBackground() {
        generation += 1
        authentication.cancel()
        isAuthenticating = false
        if preferences.lockEnabled { isLocked = true }
        cleanupExport()
    }

    func lockNow() { wentToBackground() }

    func trackingChanged(prediction: CyclePrediction?, now: Date, timeZone: TimeZone) {
        self.prediction = prediction
        self.now = now
        self.timeZone = timeZone
        reschedule()
    }

    private func reschedule() {
        guard isReady else { return }
        let enabled = preferences.dailyReminder || preferences.windowReminder
        do {
            let requests = try ReminderPlanner.requests(preferences: preferences, prediction: prediction, now: now, timeZone: timeZone)
            reminders.replace(with: requests, enabled: enabled)
        } catch {
            reminders.replace(with: [], enabled: false)
            message = "Reminders cannot be scheduled in the current date context. Review your recorded dates."
        }
    }

    func setReminders(daily: Bool, window: Bool, hour: Int, minute: Int) async {
        guard canAccess, !isChangingReminders else { return }
        isChangingReminders = true
        defer { isChangingReminders = false }
        let token = generation
        if daily || window {
            guard await reminders.permissionForUserRequest(), token == generation, canAccess else { return }
        }
        var candidate = preferences
        candidate.dailyReminder = daily
        candidate.windowReminder = window
        candidate.reminderHour = hour
        candidate.reminderMinute = minute
        do {
            try candidate.validate()
            try storage.save(candidate)
            preferences = candidate
            reschedule()
            await reminders.flush()
        } catch { message = "Reminder settings were not saved. Try again." }
    }

    func export(snapshot: TrackerSnapshot, includeNotes: Bool, generatedAt: Date = Date()) {
        guard canAccess else { return }
        do {
            let data = try TrackerExport.encode(snapshot: snapshot, includeNotes: includeNotes, generatedAt: generatedAt)
            preparedExport = PreparedExport(url: try exports.prepare(data))
            message = nil
        } catch { message = "The export could not be prepared. Your records are unchanged. Try again." }
    }

    func cleanupExport() {
        preparedExport = nil
        do { try exports.clean() }
        catch { message = "A temporary export could not be removed. Reopen Cecy to retry cleanup. Any shared copies remain outside Cecy’s control." }
    }

    /// Ancillary cleanup precedes record deletion. A failure preserves records but may already disable reminders.
    func prepareForReset() throws {
        guard canAccess, !isAuthenticating, !isChangingReminders else { throw TrackingError.invalidData }
        var candidate = preferences
        candidate.dailyReminder = false
        candidate.windowReminder = false
        candidate.reminderHour = 20
        candidate.reminderMinute = 0
        try storage.save(candidate)
        preferences = candidate
        reminders.replace(with: [], enabled: false)
        preparedExport = nil
        try exports.clean()
        message = nil
    }

    static func isolated() -> TrackerPrivacy {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CecyPreviewExports").appendingPathComponent(UUID().uuidString)
        let result = TrackerPrivacy(storage: MemoryPrivacyPreferences(), authentication: FixedDeviceAuthentication(),
                                    exports: ProtectedExportFiles(directory: directory), delivery: MemoryReminderDelivery())
        result.start()
        return result
    }

    static func production() -> TrackerPrivacy {
        let support = URL.applicationSupportDirectory.appendingPathComponent("CecyPrivacy", isDirectory: true)
        return TrackerPrivacy(storage: FilePrivacyPreferences(url: support.appendingPathComponent("preferences.json")),
                              authentication: DeviceOwnerAuthentication(),
                              exports: ProtectedExportFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent("CecyExports", isDirectory: true)),
                              delivery: LocalReminderDelivery())
    }

    #if DEBUG
    static func testing(id: UUID) -> TrackerPrivacy {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CecyUITests").appendingPathComponent(id.uuidString)
        return TrackerPrivacy(storage: FilePrivacyPreferences(url: root.appendingPathComponent("privacy/preferences.json")),
                              authentication: FixedDeviceAuthentication(succeeds: ProcessInfo.processInfo.environment["CECY_UI_AUTH"] == "success"),
                              exports: ProtectedExportFiles(directory: root.appendingPathComponent("exports")), delivery: MemoryReminderDelivery())
    }
    #endif
}
