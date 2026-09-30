import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    @State private var profile: LocalProfile
    @State private var error: String?
    @State private var discard = false
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession) {
        self.session = session
        _profile = State(initialValue: session.snapshot.profile ?? LocalProfile())
    }

    private var hasChanges: Bool { session.snapshot.profile != profile }

    var body: some View {
        SettingsForm(title: "Profile") {
            if let today = session.today {
                if let error { Section { InlineError(message: error).accessibilityFocused($errorFocused) } }
                Section("About you") { ProfileBasicsFields(profile: $profile, today: today) }
                Section { ProfileMeasurementFields(profile: $profile) } header: {
                    Text("Measurements · Optional")
                } footer: {
                    Text("Not used to predict your next period.")
                }
                Section { ProfileCycleFields(profile: $profile) } header: {
                    Text("Cycle basics")
                } footer: {
                    Text("Typical length is your own summary, not a measured average. Edit historical dates in Calendar or Insights to update predictions.")
                }
                Section {
                    DisclosureGroup("Common symptoms (\(profile.commonSymptoms.count))") { ProfileSymptomFields(profile: $profile) }
                    DisclosureGroup("Cycle context (\(profile.cycleContext.count))") { ProfileContextFields(profile: $profile) }
                    DisclosureGroup("Tracking goals (\(profile.goals.count))") { ProfileGoalFields(profile: $profile) }
                } footer: {
                    Text("These choices personalize your profile. They are not symptom logs, diagnoses or inputs to the prediction algorithm.")
                }
                Section {
                    NavigationLink("Notification preferences") { ReminderSettingsView(privacy: session.privacy) }
                        .accessibilityIdentifier("profileReminders")
                } footer: {
                    Text("Reminder changes are saved on their own screen. Save your profile edits here.")
                }
                Section {
                    Label("Your health data stays on your device.", systemImage: "iphone")
                        .font(.footnote)
                    Text("No cloud backup or cross-device restore yet. Existing users can add a profile without re-entering period history.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(hasChanges)
        .toolbar {
            if hasChanges {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { discard = true } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    profile.preferredName = profile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                    error = session.saveProfile(profile)
                    if error == nil { dismiss() } else { errorFocused = true }
                }.disabled(!hasChanges || session.isSaving).accessibilityIdentifier("saveProfile")
            }
        }
        .confirmationDialog("Discard profile changes?", isPresented: $discard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }
}

struct AccountSettingsView: View {
    let session: TrackerSession

    private var status: String {
        switch session.account.state {
        case .notLinked: "Not linked"
        case .unchecked: "Saved on this device"
        case .authorized: "Connected"
        case .revoked: "Sign in again"
        case .unavailable: "Check unavailable"
        }
    }

    var body: some View {
        SettingsForm(title: "Apple Account") {
            Section {
                LabeledContent("Status", value: status).accessibilityIdentifier("appleAccountStatus")
                Text("Your Apple identity is stored securely on this device. Cecy has no cloud account database or health-data sync yet.")
            }
            if let profile = session.snapshot.profile {
                AppleSignInSection(session: session, profileID: profile.id) {}
            } else {
                Section {
                    Text("Save your local profile before linking an Apple Account. Your existing records won’t change.")
                    NavigationLink("Add profile") { ProfileSettingsView(session: session) }
                }
            }
            Section("Change or remove your account") {
                Text("Use Delete all data in Settings to remove the local Apple link and health records. To use a different Apple Account, remove the local data first.")
                Text("This does not delete your Apple Account or revoke Apple’s authorization. You can stop using Apple sign-in for Cecy in your Apple Account settings.")
                Text("Revoking authorization never automatically deletes local health records.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await session.account.checkCredentialState() }
    }
}