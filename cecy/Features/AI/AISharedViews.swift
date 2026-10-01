import SwiftUI

struct AIConsentView: View {
    let session: TrackerSession
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        NavigationStack {
            SettingsForm(title: "Optional AI") {
                Section("Before you enable AI") {
                    Text("AI features send selected information from your request to Cecy’s Azure service and OpenAI for processing. Your full health history is not uploaded.")
                    Text("Descriptions and questions send the text you type. Other requests send limited locally calculated facts; wellness also sends your selected preferences and food allergies. Avoid names or other identifying details in free text.")
                    Text("Your records stay on this device. The gateway is designed to be stateless; external processing is subject to the providers’ data policies. Turning AI off cannot recall a request already sent.")
                    Text("AI can make mistakes. It does not diagnose conditions, predict fertility, or replace medical care. Check suggestions against your records and personal needs.")
                    Text("This is a prototype service. Requests may be unavailable. Manual tracking works without AI.")
                }
                Section {
                    if let error { InlineError(message: error) }
                    Button("Enable AI") {
                        error = session.setAIEnabled(true)
                        if error == nil { dismiss() }
                    }
                    .accessibilityIdentifier("enableAI")
                    Button("Not now") { dismiss() }.accessibilityIdentifier("declineAI")
                } footer: {
                    Text("Enabling does not send a request. Review the selected information and tap the request button afterward. Change this choice in Settings → Privacy and export. Notice v\(AIConsentRecord.currentVersion).")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AIConsentControl: View {
    let session: TrackerSession
    @State private var showConsent = false
    var body: some View {
        if !session.privacy.aiEnabled {
            Button("Review AI privacy and enable") { showConsent = true }
                .frame(minHeight: 44).accessibilityIdentifier("reviewAIConsent")
                .sheet(isPresented: $showConsent) { AIConsentView(session: session) }
        }
    }
}

struct AIRequestStatus: View {
    let coordinator: AIRequestCoordinator
    var body: some View {
        if coordinator.isLoading {
            ProgressView("Waiting for AI…")
                .accessibilityIdentifier("aiLoading")
            Text("This may take up to 75 seconds. No records will change while you wait.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Cancel request") { coordinator.cancel() }.accessibilityIdentifier("cancelAIRequest")
        }
        if let message = coordinator.message {
            InlineError(message: message).accessibilityIdentifier("aiError")
        }
    }
}

struct AISafetyNotice: View {
    let message: String?
    var body: some View {
        if let message {
            Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }
                .font(.headline).accessibilityIdentifier("aiSafetyMessage")
        }
    }
}

struct AIPrivacySection: View {
    let session: TrackerSession
    @State private var error: String?
    var body: some View {
        Section("Optional AI") {
            LabeledContent("AI processing", value: session.privacy.aiEnabled ? "Enabled" : "Off")
                .accessibilityIdentifier("aiConsentStatus")
            if session.privacy.aiEnabled || session.privacy.preferences.aiConsent != nil {
                Button("Turn off AI", role: .destructive) { error = session.setAIEnabled(false) }
                    .accessibilityIdentifier("disableAI")
            }
            AIConsentControl(session: session)
            if let error { InlineError(message: error) }
            Text("Only explicit requests use the existing Azure/OpenAI service. Turning off clears pending AI results, not confirmed records. AI prose and conversations are not saved or exported.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// All generated strings render as plain text, not Markdown, links, or executable instructions.
struct AIOutputView: View {
    let output: AIOutput
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("AI-generated · Check against your records", systemImage: "sparkles").font(.headline)
            switch output {
            case .symptoms:
                EmptyView() // Only the editable, confirmed symptom review may render these.
            case .insight(let value):
                Text(verbatim: value.title).font(.headline)
                Text(verbatim: value.explanation)
                Text(verbatim: value.supportingObservation)
                AISafetyNotice(message: value.safetyMessage)
            case .wellness(let value):
                list("Movement", value.movementSuggestions)
                list("Food", value.foodSuggestions)
                Text("Hydration").font(.headline)
                Text(verbatim: value.hydrationSuggestion)
                list("Recovery", value.recoverySuggestions)
                DisclosureGroup("Why these?") { Text(verbatim: value.explanation) }
                AISafetyNotice(message: value.safetyMessage)
            case .summary(let value):
                Text(verbatim: value.summary)
                list("Highlights", value.highlights)
                AISafetyNotice(message: value.safetyMessage)
            case .question(let value):
                Text(verbatim: value.answer)
                list("AI supporting observations", value.supportingFacts)
                AISafetyNotice(message: value.safetyMessage)
            }
            Text("Not medical advice. This result is temporary and is cleared when you leave or your records change.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("aiOutput")
    }
    private func list(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in Text(verbatim: "• " + item) }
        }
    }
}
