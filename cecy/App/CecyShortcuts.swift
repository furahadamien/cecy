import AppIntents
import Foundation

/// Holds a requested in-app destination until the root view is ready (cold launch from Shortcuts).
@MainActor
enum CecyLaunchRoute {
    static let checkIn = "cecy://check-in"
    private(set) static var pending: String?

    static func request(_ link: String) {
        pending = link
        NotificationCenter.default.post(name: .cecyReminderOpen, object: link)
    }

    static func consume() -> String? {
        defer { pending = nil }
        return pending
    }
}

/// Opens the daily check-in only. Nothing is recorded until the user reviews and taps Save,
/// and app lock still applies because the request is routed through the normal app UI.
nonisolated struct OpenDailyCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Open daily check-in"
    static let description = IntentDescription("Opens Cecy’s daily check-in so you can review and save today’s answers.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CecyLaunchRoute.request(CecyLaunchRoute.checkIn)
        return .result()
    }
}

nonisolated struct CecyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenDailyCheckInIntent(),
                    phrases: ["Open \(.applicationName) check-in", "Log my day in \(.applicationName)"],
                    shortTitle: "Daily check-in", systemImageName: "checklist")
    }
}
