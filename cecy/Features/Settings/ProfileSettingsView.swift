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
                Section {
                    DisclosureGroup {
                        ProfileGenderFields(profile: $profile)
                    } label: {
                        Text("Gender · \(profile.genderIdentity?.title ?? "Not answered")")
                            .accessibilityIdentifier("profileGenderChoices")
                    }
                    DisclosureGroup { ProfilePartnerFields(profile: $profile) } label: {
                        Text("Who you have sex with").accessibilityIdentifier("profilePartnerChoices")
                    }
                } header: { Text("Personal details · Optional") } footer: {
                    Text("Kept in your local profile, never used for predictions or sent for insights. Partner answers are exported only with both profile and sexual-information permission.")
                }
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
                    NavigationLink {
                        WellnessPreferencesView(preferences: $profile.wellnessPreferences)
                    } label: {
                        Label("Wellness preferences", systemImage: "leaf")
                    }
                    .accessibilityIdentifier("profileWellness")
                } footer: {
                    Text("Activity, exercise, food and wellness choices. Not used for predictions.")
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
                    Label("Records are stored on this device. Optional insights send only selected information when requested.", systemImage: "iphone")
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
    @State private var confirmLogout = false
    @State private var logoutError: String?

    private var status: String {
        switch session.account.state {
        case .notLinked: "Not linked"
        case .unchecked: "Saved on this device"
        case .authorized: "Connected"
        case .revoked: "Sign in again"
        case .unavailable: "Check unavailable"
        case .signedOut: "Logged out"
        }
    }

    var body: some View {
        SettingsForm(title: "Apple Account") {
            Section {
                LabeledContent("Status", value: status).accessibilityIdentifier("appleAccountStatus")
                Text("Your Apple identity is stored securely on this device. Cecy has no cloud account database or health-data sync yet.")
            }
            if let profile = session.snapshot.profile {
                if session.account.state != .authorized && session.account.state != .unchecked {
                    AppleSignInSection(session: session, profileID: profile.id, purpose: .connect) {}
                }
            } else {
                Section {
                    Text("Save your local profile before linking an Apple Account. Your existing records won’t change.")
                    NavigationLink("Add profile") { ProfileSettingsView(session: session) }
                }
            }
            if session.account.identity != nil {
                Section {
                    Button(role: .destructive) { confirmLogout = true } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right").frame(minHeight: 44)
                    }
                    .disabled(session.isSaving || session.account.isSigningIn || session.privacy.isAuthenticating || session.privacy.isChangingReminders)
                    .accessibilityIdentifier("logOut")
                    if let logoutError { InlineError(message: logoutError) }
                } footer: {
                    Text("Keeps your local records. Sign in with the same Apple Account to reopen them.")
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
        .alert("Log out of Cecy?", isPresented: $confirmLogout) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) { logoutError = session.logOut() }
                .accessibilityIdentifier("confirmLogout")
        } message: {
            Text("Your details stay on this device, hidden until you sign back in with the same Apple Account. Reminders and app lock stay unchanged. This does not revoke Apple’s authorization.")
        }
    }
}

struct SignedOutAccountView: View {
    let session: TrackerSession
    @State private var showReset = false

    var body: some View {
        SettingsForm(title: "Welcome back") {
            Section {
                Label("You’re logged out", systemImage: "lock.shield")
                    .font(.headline).accessibilityIdentifier("signedOutScreen")
                Text("Reconnect with the same Apple Account to open any profile saved on this device. Logging out does not delete it.")
            }
            if session.account.identityLoaded, let identity = session.account.identity {
                AppleSignInSection(session: session, profileID: identity.profileID, purpose: .reconnect) { session.load() }
            } else {
                Section {
                    Text(session.account.message ?? "Your Apple identity couldn’t be read securely.")
                    Button("Try again") { session.account.reload(); session.load() }
                }
            }
            Section {
                Text("Logging out doesn’t delete records, disable your reminders or turn off app lock. The account binding stays in this device’s Keychain to prevent another Apple Account opening your records.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Delete local data and start over", role: .destructive) { showReset = true }
                    .accessibilityIdentifier("signedOutReset")
            }
        }
        .sheet(isPresented: $showReset) { DeleteAllDataView(session: session) }
    }
}
