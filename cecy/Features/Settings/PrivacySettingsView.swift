import SwiftUI
import UIKit

struct PrivacySettingsView: View {
    let session: TrackerSession
    @State private var includeNotes = false
    @State private var includeProfile = false
    @State private var includeSexualActivity = false
    @State private var confirmDisableLock = false
    private var privacy: TrackerPrivacy { session.privacy }

    var body: some View {
        @Bindable var privacy = privacy
        SettingsForm(title: "Privacy and export") {
            if let message = privacy.message { Section { InlineError(message: message) } }
            AIPrivacySection(session: session)
            Section {
                LabeledContent("Status") {
                    Text(privacy.preferences.lockEnabled ? "On" : "Off")
                        .accessibilityIdentifier("lockState")
                }
                if privacy.preferences.lockEnabled {
                    Button("Lock now") { privacy.lockNow() }.frame(minHeight: 44).accessibilityIdentifier("lockNow")
                    Button("Turn off app lock") { confirmDisableLock = true }.frame(minHeight: 44)
                } else {
                    Button("Enable app lock") { Task { await privacy.setLockEnabled(true) } }
                        .frame(minHeight: 44).accessibilityIdentifier("enableAppLock")
                }
                if privacy.isAuthenticating { ProgressView("Authenticating…") }
                DisclosureGroup("When does Cecy lock?") {
                    Text("With app lock on, returning from the background requires unlocking again. Unsaved drafts may be discarded.")
                    Text("App lock protects the screen; it is not separate encryption.")
                }
            } header: {
                Text("App lock")
            } footer: {
                Text("Uses Face ID, Touch ID or your device passcode. Anyone with that passcode can unlock Cecy.")
            }
            .disabled(privacy.isAuthenticating)
            Section {
                Toggle("Include private notes", isOn: $includeNotes).accessibilityIdentifier("exportNotes")
                Toggle("Include sexual activity", isOn: $includeSexualActivity).accessibilityIdentifier("exportSexualActivity")
                if session.snapshot.profile != nil {
                    Toggle("Include personal profile", isOn: $includeProfile).accessibilityIdentifier("exportProfile")
                }
                DisclosureGroup("What’s included?") {
                    Text("Dates, record IDs, flow, observation types and ratings. Private notes are optional; predictions are not included.")
                    Text("Accepted Apple Health period dates are included. Health sample identifiers and source metadata are not exported.")
                    Text("Sexual activity is excluded unless you turn it on above. Activity notes also require Include private notes.")
                    Text("Personal profile is optional and includes your name, birth date, measurements and preferences, including any wellness choices and food allergies. Apple identity is never exported.")
                    Text("JSON is a readable data file. Importing it back into Cecy is not supported.")
                    Text("Leaving Cecy while sharing may cancel the export.")
                }
                Label("Not encrypted. Share only with a destination you trust.", systemImage: "exclamationmark.shield")
                    .font(.footnote).foregroundStyle(.secondary)
                Button {
                    privacy.export(snapshot: session.snapshot, includeNotes: includeNotes, includeProfile: includeProfile,
                                   includeSexualActivity: includeSexualActivity)
                } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up").frame(minHeight: 44)
                }
                .accessibilityIdentifier("prepareExport")
            } header: {
                Text("Export records")
            } footer: {
                Text("Saved or shared copies leave Cecy’s control. Delete all data won’t remove them.")
            }
            Section {
                NavigationLink { StorageSettingsInfoView() } label: {
                    Label("Storage and backups", systemImage: "externaldrive")
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("storageSettings")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Turn off app lock?", isPresented: $confirmDisableLock) {
            Button("Keep app lock", role: .cancel) {}
            Button("Authenticate to turn off", role: .destructive) { Task { await privacy.setLockEnabled(false) } }
        } message: { Text("After authentication, anyone using this unlocked device could open Cecy.") }
        .sheet(item: $privacy.preparedExport, onDismiss: { privacy.cleanupExport() }) { export in
            ExportShareSheet(url: export.url) { privacy.cleanupExport() }
        }
    }
}

private struct StorageSettingsInfoView: View {
    var body: some View {
        SettingsForm(title: "Storage and backups") {
            Section("Device protection") {
                Text("Cecy requests complete iOS Data Protection for records and temporary exports. Your device passcode and system protections matter.")
                Text("App lock is an additional screen gate, not separate encryption.")
            }
            Section("System backups") {
                Text("Local records, your profile and preferences are excluded from future system backups. Earlier backups may still contain data. Deleting data in Cecy does not erase earlier backups or guarantee overwriting storage pages.")
                Text("No cloud sync or automatic restore is available yet. Keep a trusted export if needed; importing it into Cecy is not currently supported.")
                Text("Apple Health manages its own records and sync settings. Cecy’s read-only import and local deletion do not change those records or settings.")
            }
            Section("Exported files") {
                Text("Temporary exports are excluded from backups and cleaned up after sharing, locking and on the next launch.")
                Text("Copies you save or share are outside Cecy’s control. Delete those separately if needed.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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

    private var hasUnsavedChanges: Bool {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        let saved = privacy.preferences
        return daily != saved.dailyReminder || window != saved.windowReminder
            || parts.hour != saved.reminderHour || parts.minute != saved.reminderMinute
    }

    var body: some View {
        SettingsForm(title: "Reminders") {
            if let message = privacy.message { Section { InlineError(message: message) } }
            Section {
                Toggle("Daily check-in", isOn: $daily).accessibilityIdentifier("dailyReminder")
                Toggle("Before period window", isOn: $window).accessibilityIdentifier("windowReminder")
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            } header: {
                Text("Choose reminders")
            } footer: {
                Text("Uses local time. Period reminders need an available estimate and a future reminder time.")
            }
            Section {
                Button("Save changes") {
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                    Task { await privacy.setReminders(daily: daily, window: window, hour: parts.hour ?? 20, minute: parts.minute ?? 0) }
                }
                .frame(minHeight: 44).accessibilityIdentifier("saveReminders")
                if privacy.isChangingReminders { ProgressView("Updating reminders…") }
                if hasUnsavedChanges {
                    Text("Unsaved changes").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("reminderDraftStatus")
                }
            }
            Section("Saved settings") {
                LabeledContent("Daily check-in") {
                    Text(privacy.preferences.dailyReminder ? "On" : "Off")
                        .accessibilityIdentifier("savedDailyReminder")
                }
                LabeledContent("Period window") {
                    Text(privacy.preferences.windowReminder ? "On" : "Off")
                        .accessibilityIdentifier("savedWindowReminder")
                }
                Text(privacy.reminders.status).accessibilityIdentifier("reminderStatus")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("Delivery and privacy") {
                    Text("Notifications never include symptoms, notes or predicted dates. iOS still knows the schedule. Permission is requested only when you save enabled reminders.")
                    Text("A period reminder is scheduled the day before the earliest estimated start, only if that time is still in the future. No estimate means no period reminder.")
                    Text("Reminders update when you open Cecy or change records or settings. Focus and system settings may delay or prevent delivery. These are not medical alerts.")
                }
                Button("iOS notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                }.frame(minHeight: 44)
            } footer: {
                Text("Discreet notifications. No health details on your lock screen.")
            }
        }
        .disabled(privacy.isChangingReminders)
        .navigationBarTitleDisplayMode(.inline)
    }
}
