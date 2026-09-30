import Foundation
import UserNotifications
import Observation

nonisolated enum ReminderAuthorization: Sendable { case notDetermined, allowed, denied }

@MainActor protocol ReminderDelivering {
    func authorization() async -> ReminderAuthorization
    func requestPermission() async throws -> Bool
    func clear() async
    func add(_ request: ReminderRequest) async throws
}

@MainActor final class LocalReminderDelivery: ReminderDelivering {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> ReminderAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return settings.alertSetting == .disabled ? .denied : .allowed
        default: return .denied
        }
    }
    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }
    func clear() async {
        center.removePendingNotificationRequests(withIdentifiers: ReminderRequest.identifiers)
        center.removeDeliveredNotifications(withIdentifiers: ReminderRequest.identifiers)
        // Round-trip to the notification service before reset reports reconciliation complete.
        _ = await center.pendingNotificationRequests()
        _ = await center.deliveredNotifications()
    }
    func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Cecy"
        content.body = "A reminder you asked for. Open Cecy when it suits you."
        content.sound = .default
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.hour = request.hour
        components.minute = request.minute
        if let day = request.day {
            components.year = day.year
            components.month = day.month
            components.day = day.day
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: request.kind == .daily)
        try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }
}

/// In-memory delivery for isolated tests/previews. Never contacts notification APIs.
@MainActor final class MemoryReminderDelivery: ReminderDelivering {
    var permission: ReminderAuthorization = .allowed
    var requests: [ReminderRequest] = []
    func authorization() -> ReminderAuthorization { permission }
    func requestPermission() -> Bool { permission == .allowed }
    func clear() { requests = [] }
    func add(_ request: ReminderRequest) { requests.append(request) }
}

@MainActor @Observable final class ReminderCoordinator {
    private(set) var status = "Reminders are off."
    @ObservationIgnored private let delivery: any ReminderDelivering
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var desired: [ReminderRequest] = []
    @ObservationIgnored private var enabled = false
    @ObservationIgnored private var task: Task<Void, Never>?

    init(delivery: any ReminderDelivering) { self.delivery = delivery }

    func permissionForUserRequest() async -> Bool {
        let current = await delivery.authorization()
        if current == .allowed { return true }
        if current == .notDetermined {
            do {
                let granted = try await delivery.requestPermission()
                let updated = await delivery.authorization()
                if granted && updated == .allowed { return true }
                status = "Notifications are unavailable or disabled. You can change permissions in iOS Settings."
                return false
            }
            catch { status = "Permission could not be requested. Try again."; return false }
        }
        status = "Notifications are unavailable or disabled. You can change permissions in iOS Settings."
        return false
    }

    func replace(with requests: [ReminderRequest], enabled: Bool) {
        desired = requests
        self.enabled = enabled
        revision += 1
        guard task == nil else { return }
        task = Task { await reconcile() }
    }

    private func reconcile() async {
        while true {
            let current = revision
            let requests = desired
            let wanted = enabled
            await delivery.clear()
            if wanted {
                let permission = await delivery.authorization()
                if permission == .allowed {
                    do {
                        for request in requests {
                            guard current == revision else { break }
                            try await delivery.add(request)
                        }
                        status = requests.isEmpty ? "No future window reminder can be scheduled from the current estimate." : "Discreet reminders scheduled. iOS controls delivery."
                    } catch {
                        await delivery.clear()
                        status = "Reminders could not be scheduled. Reopen Cecy or change a setting to retry."
                    }
                } else { status = "Notifications are unavailable or disabled. You can change permissions in iOS Settings." }
            } else { status = "Reminders are off." }
            if current == revision { break }
        }
        task = nil
    }

    func flush() async { await task?.value }
}
