import SwiftUI

struct TrackerSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    @State private var showReset = false
    @State private var confirmDeleteData = false
    @State private var appearanceError: String?

    private var reminderSummary: String {
        let preferences = session.privacy.preferences
        switch (preferences.dailyReminder, preferences.windowReminder) {
        case (true, true): return "Saved: Daily & period window"
        case (true, false): return "Saved: Daily"
        case (false, true): return "Saved: Period window"
        case (false, false): return "Off"
        }
    }

    var body: some View {
        SettingsForm(title: "Settings") {
            Section("Personal details") {
                NavigationLink { ProfileSettingsView(session: session) } label: {
                    SettingsRow(title: "Profile", systemImage: "person.crop.circle",
                                detail: session.snapshot.profile?.preferredName ?? "Add your personal details")
                }.accessibilityIdentifier("profileSettings")
                NavigationLink { AccountSettingsView(session: session) } label: {
                    SettingsRow(title: "Apple Account", systemImage: "person.badge.key",
                                detail: session.account.identity == nil ? "Not linked" : "Identity only · No cloud sync")
                }.accessibilityIdentifier("accountSettings")
            }
            Section {
                NavigationLink { PrivacySettingsView(session: session) } label: {
                    SettingsRow(title: "Privacy and export", systemImage: "lock.shield",
                                detail: "App lock: \(session.privacy.preferences.lockEnabled ? "On" : "Off")")
                }
                .accessibilityIdentifier("privacySettings")
                NavigationLink { ReminderSettingsView(privacy: session.privacy) } label: {
                    SettingsRow(title: "Reminders", systemImage: "bell", detail: reminderSummary)
                }
                .accessibilityIdentifier("reminderSettings")
                NavigationLink { HealthImportSettingsView(session: session) } label: {
                    SettingsRow(title: "Apple Health", systemImage: "heart.text.clipboard",
                                detail: "Optional · Review and import")
                }
                .accessibilityIdentifier("healthSettings")
            } header: {
                Text("Your preferences")
            } footer: {
                Text("Cecy keeps its records on this device. Optional Apple Health import is read-only.")
            }
            Section {
                Toggle(isOn: Binding(get: {
                    session.privacy.preferences.appearance.map { $0 == .dark } ?? (colorScheme == .dark)
                }, set: {
                    appearanceError = session.privacy.setAppearance($0 ? .dark : .light)
                })) {
                    Label("Dark mode", systemImage: "moon")
                }.accessibilityIdentifier("darkMode")
                Button("Use device appearance") { appearanceError = session.privacy.setAppearance(nil) }
                    .disabled(session.privacy.preferences.appearance == nil)
                    .accessibilityIdentifier("systemAppearance")
                if let appearanceError { InlineError(message: appearanceError) }
            } header: {
                Text("Appearance")
            } footer: {
                Text(session.privacy.preferences.appearance == nil ? "Following your device’s appearance." : "Your choice applies throughout Cecy.")
                    .accessibilityIdentifier("appearanceStatus")
            }
            Section("About") {
                NavigationLink { ContactSupportView() } label: {
                    SettingsRow(title: "Contact support", systemImage: "envelope",
                                detail: SupportContact.email)
                }
                .accessibilityIdentifier("contactSupport")
                NavigationLink { PredictionSettingsInfoView() } label: {
                    SettingsRow(title: "How predictions work", systemImage: "calendar",
                                detail: "Estimates, not guarantees")
                }
                .accessibilityIdentifier("predictionSettings")
                NavigationLink { AboutCecyView() } label: {
                    SettingsRow(title: "About Cecy", systemImage: "info.circle",
                                detail: "Version \(cecyVersion)")
                }
                .accessibilityIdentifier("aboutCecy")
            }
            Section {
                Button(role: .destructive) { confirmDeleteData = true } label: {
                    Label("Delete all data", systemImage: "trash").frame(minHeight: 44)
                }
                .accessibilityIdentifier("deleteAllData")
                .disabled(session.isSaving)
            } header: {
                Text("Your records")
            } footer: {
                Text("To edit or delete a single record, use Calendar or Insights.")
            }
        }
        .alert("Delete all data?", isPresented: $confirmDeleteData) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) { showReset = true }
                .accessibilityIdentifier("reviewDataDeletion")
        } message: {
            Text("Are you sure? Your data stored in Cecy will be permanently deleted. This cannot be undone. Continue to review what will be removed and confirm deletion.")
        }
        .sheet(isPresented: $showReset) { DeleteAllDataView(session: session) }
    }
}

/// Native grouped rows keep controls familiar and accommodate larger text.
struct SettingsForm<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        Form { content }
            .trackerFormStyle()
            .navigationTitle(title)
    }
}

private struct SettingsRow: View {
    let title: String
    let systemImage: String
    let detail: String

    var body: some View {
        TrackerNavigationLabel(title: title, symbol: systemImage, detail: detail, showsChevron: false)
    }
}

private var cecyVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
}

private struct PredictionSettingsInfoView: View {
    var body: some View {
        SettingsForm(title: "How predictions work") {
            Section("At a glance") {
                Label("Start with one recorded period", systemImage: "calendar.badge.plus")
                Text("Estimates use up to six recent cycle intervals. A window shows possible start dates—not bleeding duration.")
                Text("If your intervals vary too much, Cecy won’t show an estimate.")
            }
            Section {
                DisclosureGroup("Calculation details") {
                    Text("The same calculation works at every history size. With one start, your entered typical cycle length supplies the input and the provisional window adds three days on either side. As soon as a completed interval exists, up to six measured intervals supply the inputs instead. Profile assumptions never become observed history.")
                    Text("The center uses the median. The window extends two days around the shortest and longest intervals, beginning at least one day after the latest start.")
                    Text("A spread above 14 days means this simple model cannot provide a window. Unusual intervals are not discarded.")
                }
                .accessibilityIdentifier("predictionCalculationDetails")
                DisclosureGroup("Confidence and history checks") {
                    Text("Moderate confidence requires six intervals spanning at most seven days and at least three recent reconstructed checks, with none withheld, at least 80% inside their windows and average center error at most three days. Otherwise confidence is Low.")
                    Text("History checks reconstruct estimates from current corrected records. They are not saved predictions or proof of future accuracy. The median window remains unchanged.")
                    Text(PredictionEvidence.policy)
                    Text("Confidence labels are provisional—not measured probabilities.")
                }
            }
            Section {
                Text("Not medical advice. Do not use estimates for contraception, diagnosis, or fertility planning.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutCecyView: View {
    var body: some View {
        SettingsForm(title: "About Cecy") {
            Section("Cecy") {
                LabeledContent("Version", value: cecyVersion)
                #if DEBUG
                LabeledContent("Release", value: "Internal prototype")
                Text("Use synthetic records for now. Device privacy and accessibility verification are still pending before public release.")
                #endif
            }
            Section("On your device") {
                Text("Records and calculations stay on-device. Apple Health import is optional and read-only. Optional insights send selected information to Azure and OpenAI only with consent and a request. No health-data cloud sync or analytics.")
                Text("Health records and preferences are excluded from future system backups. Earlier backups and exported copies are not erased. Apple sign-in cannot restore records on another device yet.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DeleteAllDataView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    @State private var confirmation = ""
    @State private var error: String?
    @State private var isResetting = false
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        NavigationStack {
            SettingsForm(title: "Delete all data?") {
                Section("What’s removed") {
                    Label("All periods, flow, symptoms, ratings, sexual activity and notes", systemImage: "trash")
                    Label("Your profile and local Apple identity", systemImage: "person.crop.circle.badge.minus")
                    Label("Reminders, insight consent and temporary exports", systemImage: "bell.slash")
                    Text("Saved onboarding and old template database files are also removed. You’ll return to onboarding.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Text("App lock stays on if enabled.")
                    Text("Device backups and copies saved outside Cecy are not deleted.")
                    Text("Requests already sent cannot be recalled. Deletion stops new requests until you enable optional insights again.")
                    Text("Records in Apple Health are not deleted. Local import review history is cleared.")
                    Text("Your Apple Account and Apple’s sign-in authorization are not deleted. Manage that authorization in your Apple Account settings.")
                } header: {
                    Text("What stays")
                } footer: {
                    Text("Deletion cannot be undone and does not guarantee secure erasure of storage.")
                }
                Section("Type DELETE to confirm") {
                    TextField("DELETE", text: $confirmation)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .accessibilityIdentifier("resetConfirmation")
                    Button("Permanently delete local data", role: .destructive) {
                        isResetting = true
                        Task {
                            error = await session.deleteAllAndWait()
                            isResetting = false
                            if error == nil { dismiss() } else { errorFocused = true }
                        }
                    }
                    .disabled(confirmation != "DELETE" || session.isSaving || isResetting || session.privacy.isChangingReminders || session.privacy.isAuthenticating)
                    .frame(minHeight: 44).accessibilityIdentifier("confirmReset")
                }
                if let error { InlineError(message: error).accessibilityFocused($errorFocused) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(session.isSaving || isResetting) }
            }
            .interactiveDismissDisabled(session.isSaving || isResetting)
        }
    }
}
