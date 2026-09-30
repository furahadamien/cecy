import SwiftUI
import UIKit

struct PrivacySettingsView: View {
    let session: TrackerSession
    @State private var includeNotes = false
    @State private var confirmDisableLock = false
    private var privacy: TrackerPrivacy { session.privacy }

    var body: some View {
        @Bindable var privacy = privacy
        TrackerPage(title: "Privacy and export") {
            TrackerCard {
                Text("App lock").font(.headline)
                Text(privacy.preferences.lockEnabled ? "App lock is on." : "App lock is off.")
                    .accessibilityIdentifier("lockState")
                Text("Face ID or Touch ID, with your device passcode as fallback. Anyone who knows that passcode can unlock Cecy. Returning from the background requires unlocking again; unsaved drafts may be discarded.")
                if privacy.preferences.lockEnabled {
                    Button("Lock now") { privacy.lockNow() }.frame(minHeight: 44).accessibilityIdentifier("lockNow")
                    Button("Turn off app lock") { confirmDisableLock = true }.frame(minHeight: 44)
                } else {
                    Button("Enable app lock") { Task { await privacy.setLockEnabled(true) } }
                        .frame(minHeight: 44).accessibilityIdentifier("enableAppLock")
                }
                if privacy.isAuthenticating { ProgressView("Authenticating…") }
            }
            .disabled(privacy.isAuthenticating)
            TrackerCard {
                Text("Export your records").font(.headline)
                Text("JSON contains readable health information, not an encrypted archive. It includes dates, IDs, flow, observation types and ratings. It does not include predictions. Importing this file into Cecy is not currently supported.")
                Toggle("Include private notes", isOn: $includeNotes).accessibilityIdentifier("exportNotes")
                Text("Only share with a destination you trust. Saved or shared copies leave Cecy’s control and cannot be removed by Delete all data. Leaving the app while sharing may cancel the export.")
                Button("Prepare JSON export") { privacy.export(snapshot: session.snapshot, includeNotes: includeNotes) }
                    .frame(minHeight: 44).accessibilityIdentifier("prepareExport")
            }
            TrackerCard {
                Text("Device storage and backups").font(.headline)
                Text("Cecy requests complete iOS Data Protection for its records and temporary exports. Device passcode and system protections matter. App locking is an additional screen gate, not separate encryption.")
                Text("System backups may contain records and settings. Temporary exports are excluded from backups and cleaned up after sharing, locking and on next launch. Deletion does not erase backups or guarantee overwriting storage pages.")
            }
            if let message = privacy.message { InlineError(message: message) }
        }
        .alert("Turn off app lock?", isPresented: $confirmDisableLock) {
            Button("Keep app lock", role: .cancel) {}
            Button("Authenticate to turn off", role: .destructive) { Task { await privacy.setLockEnabled(false) } }
        } message: { Text("After authentication, anyone using this unlocked device could open Cecy.") }
        .sheet(item: $privacy.preparedExport, onDismiss: { privacy.cleanupExport() }) { export in
            ExportShareSheet(url: export.url) { privacy.cleanupExport() }
        }
    }
}

private struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completion: @MainActor () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in completion() }
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct ReminderSettingsView: View {
    let privacy: TrackerPrivacy
    @State private var daily: Bool
    @State private var window: Bool
    @State private var time: Date

    init(privacy: TrackerPrivacy) {
        self.privacy = privacy
        let preferences = privacy.preferences
        _daily = State(initialValue: preferences.dailyReminder)
        _window = State(initialValue: preferences.windowReminder)
        _time = State(initialValue: Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1,
                      hour: preferences.reminderHour, minute: preferences.reminderMinute)) ?? Date())
    }

    var body: some View {
        Form {
            Section("Choose reminders") {
                Toggle("Daily logging reminder", isOn: $daily).accessibilityIdentifier("dailyReminder")
                Toggle("Before estimated start window", isOn: $window).accessibilityIdentifier("windowReminder")
                DatePicker("Local reminder time", selection: $time, displayedComponents: .hourAndMinute)
                Text("The window reminder is scheduled for the day before the earliest estimated start, only when its time is still in the future. If no estimate is available, no window reminder is scheduled.")
            }
            Section {
                Button("Save reminder choices") {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                    Task { await privacy.setReminders(daily: daily, window: window, hour: parts.hour ?? 20, minute: parts.minute ?? 0) }
                }
                .frame(minHeight: 44).accessibilityIdentifier("saveReminders")
                if privacy.isChangingReminders { ProgressView("Updating reminders…") }
                Text(privacy.reminders.status).accessibilityIdentifier("reminderStatus")
                Text("Saved daily reminder: \(privacy.preferences.dailyReminder ? "On" : "Off")")
                Text("Saved window reminder: \(privacy.preferences.windowReminder ? "On" : "Off")")
            }
            Section("Your privacy") {
                Text("Notification text is always discreet and contains no symptoms, notes or predicted dates. iOS still knows the schedule. Permission is requested only when you save enabled reminders.")
                Text("Reminders are recalculated when you open Cecy and change records or settings. Focus and system settings can delay or prevent delivery; reminders are not medical alerts.")
                Button("Open iOS notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                }.frame(minHeight: 44)
            }
            if let message = privacy.message { InlineError(message: message) }
        }
        .disabled(privacy.isChangingReminders)
        .navigationTitle("Reminders")
    }
}
