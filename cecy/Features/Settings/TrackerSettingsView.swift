import SwiftUI

struct TrackerSettingsView: View {
    let session: TrackerSession
    @State private var showReset = false
    var body: some View {
        TrackerPage(title: "Settings", subtitle: "Your information. Your choices.") {
            TrackerCard(highlighted: true) { PrivacyDetails() }
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
                Text("A spread above 14 days means this simple model cannot provide a window. Six intervals with a spread of seven days or less receive Moderate confidence; other eligible estimates receive Low confidence.")
                Text("These labels are provisional—not measured probabilities. The window represents possible start dates, not bleeding duration.")
                Text("Not medical advice. Do not use estimates for contraception, diagnosis, or fertility planning.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            TrackerCard {
                Text("Internal prototype").font(.headline)
                Text("You can correct or delete saved records. Export and app locking are not available yet. Device and accessibility verification remain required before public release.")
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
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This removes all local period dates, flow, symptoms, ratings, private notes, and onboarding completion, plus any old template database files. You will return to onboarding.")
                    Text("This cannot be undone. It does not erase device backups or copies outside the app, and is not a secure-erasure guarantee.")
                }
                Section("Type DELETE to confirm") {
                    TextField("DELETE", text: $confirmation)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .accessibilityIdentifier("resetConfirmation")
                    Button("Permanently delete local data", role: .destructive) {
                        error = session.deleteAll()
                        if error == nil { dismiss() } else { errorFocused = true }
                    }
                    .disabled(confirmation != "DELETE" || session.isSaving)
                    .frame(minHeight: 44).accessibilityIdentifier("confirmReset")
                }
                if let error { InlineError(message: error).accessibilityFocused($errorFocused) }
            }
            .navigationTitle("Delete all data?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(session.isSaving) }
            }
            .interactiveDismissDisabled(session.isSaving)
        }
    }
}
