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
    init() {
        center.delegate = ReminderNotificationDelegate.shared
        let snooze = UNNotificationAction(identifier: "CECY_SNOOZE", title: "Snooze until tomorrow")
        center.setNotificationCategories([UNNotificationCategory(identifier: "CECY_REMINDER", actions: [snooze], intentIdentifiers: [])])
    }
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
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(ReminderRequest.identifierPrefix) }
        let delivered = await center.deliveredNotifications().map { $0.request.identifier }.filter { $0.hasPrefix(ReminderRequest.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
        // Round-trip to the notification service before reset reports reconciliation complete.
        _ = await center.pendingNotificationRequests()
        _ = await center.deliveredNotifications()
    }
    func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.kind.notificationTitle(showDetails: request.showDetails)
        content.body = request.kind.notificationBody(showDetails: request.showDetails)
        content.sound = .default
        content.categoryIdentifier = "CECY_REMINDER"
        content.userInfo = ["deepLink": request.deepLink]
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.hour = request.hour
        components.minute = request.minute
        if let day = request.day {
            components.year = day.year
            components.month = day.month
            components.day = day.day
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: request.day == nil)
        try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }
}

extension Notification.Name {
    static let cecyReminderOpen = Notification.Name("cecy.reminder.open")
    static let cecyReminderSnooze = Notification.Name("cecy.reminder.snooze")
}

private final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = ReminderNotificationDelegate()
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let name: Notification.Name = response.actionIdentifier == "CECY_SNOOZE" ? .cecyReminderSnooze : .cecyReminderOpen
        let link = response.notification.request.content.userInfo["deepLink"] as? String
        await MainActor.run { NotificationCenter.default.post(name: name, object: link) }
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
                        status = requests.isEmpty ? "No future window reminder can be scheduled from the current estimate." : "Reminders scheduled. iOS controls delivery."
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
