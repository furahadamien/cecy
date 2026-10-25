import SwiftUI

/// Controls for the Today follow-up questions: on/off, which kinds, and asking skipped ones again.
struct FollowUpSettingsView: View {
    let session: TrackerSession
    @State private var error: String?
    @State private var resetDone = false

    var body: some View {
        List {
            Section {
                Toggle("Ask follow-up questions", isOn: Binding(get: { session.privacy.followUpsEnabled }, set: {
                    error = session.privacy.setFollowUpsEnabled($0)
                }))
                .accessibilityIdentifier("followUpsEnabled")
            } footer: {
                Text("When you open the app, Cecy sometimes asks a short question on Today to keep your records current, like how you're feeling or whether a trip has ended. Up to a few a day, spaced out, and never the same question twice in a day. Answers save to the same records you see in Settings.")
            }
            if session.privacy.followUpsEnabled {
                Section {
                    ForEach(FollowUpKind.allCases, id: \.self) { kind in
                        Toggle(kind.settingsTitle, isOn: Binding(get: { !session.privacy.followUpMemory.disabledKinds.contains(kind) }, set: {
                            error = session.setFollowUpKind(kind, enabled: $0)
                        }))
                        .accessibilityIdentifier("followUpKind.\(kind.rawValue)")
                    }
                } header: { Text("Ask about") }
                Section {
                    Button("Ask skipped questions again") {
                        error = session.resetSkippedFollowUps()
                        resetDone = error == nil
                    }
                    .accessibilityIdentifier("resetFollowUps")
                    if resetDone { Label("Skipped questions can be asked again.", systemImage: "checkmark").font(.footnote) }
                } footer: {
                    Text("Turns back on any question types you switched off and clears “Not now” and “Nothing to note” answers. Your records are not changed.")
                }
            }
            if let error { Section { InlineError(message: error) } }
            Section {
                Text("Which questions you answered or skipped is saved only on this device. It isn’t exported or sent anywhere, and Delete all data removes it.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Check-in questions")
    }
}
