import SwiftUI

struct TrackerSettingsView: View {
    let session: TrackerSession
    @State private var showReset = false
    var body: some View {
        TrackerPage(title: "Settings", subtitle: "Your information. Your choices.") {
            TrackerCard(highlighted: true) { PrivacyDetails() }
            NavigationLink("Privacy and export") { PrivacySettingsView(session: session) }
                .frame(minHeight: 44).accessibilityIdentifier("privacySettings")
            NavigationLink("Reminders") { ReminderSettingsView(privacy: session.privacy) }
                .frame(minHeight: 44).accessibilityIdentifier("reminderSettings")
            TrackerCard {
                Text("Your records").font(.headline)
                Text("Edit or delete individual periods from Calendar or Manage recorded periods in Insights.")
                Text("Manage symptoms, ratings, and private notes from Calendar or Observations and patterns in Insights. Pattern calculations stay on your device.")
                Button("Delete all data", role: .destructive) { showReset = true }
                    .frame(minHeight: 44).accessibilityIdentifier("deleteAllData")
            }
            TrackerCard {
                Text("About predictions").font(.headline).accessibilityAddTraits(.isHeader)
                Text("Four recorded starts provide the three completed intervals needed for a first estimate. Up to six recent intervals are used.")
                Text("The center uses the median. The window extends two days around the shortest and longest intervals, beginning at least one day after the latest start.")
                Text("A spread above 14 days means this simple model cannot provide a window. Moderate confidence requires six intervals spanning at most seven days and at least three recent reconstructed checks, with none withheld, at least 80% inside their windows and average center error at most three days. Otherwise confidence is Low.")
                Text("History checks reconstruct estimates from current corrected records. They are not saved predictions or proof of future accuracy. The median window remains unchanged; unusual intervals are not discarded.")
                Text(PredictionEvidence.policy).font(.caption)
                Text("These labels are provisional—not measured probabilities. The window represents possible start dates, not bleeding duration.")
                Text("Not medical advice. Do not use estimates for contraception, diagnosis, or fertility planning.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            TrackerCard {
                Text("Internal prototype").font(.headline)
                Text("You can correct, export or delete saved records. Optional app locking and discreet local reminders are available. Device and accessibility verification remain required before public release.")
                Text("Cecy \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showReset) { DeleteAllDataView(session: session) }
    }
}

private struct DeleteAllDataView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    @State private var confirmation = ""
    @State private var error: String?
    @State private var isResetting = false
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This removes local period dates, flow, symptoms, ratings, private notes, onboarding completion, temporary exports and old template database files. Reminders are disabled and cleared. App lock stays enabled if you chose it. You will return to onboarding.")
                    Text("This cannot be undone. It does not erase device backups or copies outside the app, and is not a secure-erasure guarantee.")
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
            .navigationTitle("Delete all data?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(session.isSaving || isResetting) }
            }
            .interactiveDismissDisabled(session.isSaving || isResetting)
        }
    }
}
