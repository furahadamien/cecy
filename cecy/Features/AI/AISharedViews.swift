import SwiftUI

struct AIConsentView: View {
    let session: TrackerSession
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    var body: some View {
        NavigationStack {
            SettingsForm(title: "Optional insights") {
                Section("Your choice") {
                    Text("Cecy uses AI to suggest things based on your current cycle phase, symptoms and preferences.")
                        .accessibilityIdentifier("aiExpandedCatalogDisclosure")
                    Text("Suggestions can be wrong and are not medical advice.")
                        .accessibilityIdentifier("aiPhaseBleedingDisclosure")
                }
                Section {
                    if let error { InlineError(message: error) }
                    Button("Enable insights") {
                        error = session.setAIEnabled(true)
                        if error == nil { dismiss() }
                    }
                    .accessibilityIdentifier("enableAI")
                    Button("Not now") { dismiss() }.accessibilityIdentifier("declineAI")
                } footer: {
                    Text("Turn off anytime in Settings → Privacy and export.")
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
            Button("Enable optional insights") { showConsent = true }
                .frame(minHeight: 44).accessibilityIdentifier("reviewAIConsent")
                .sheet(isPresented: $showConsent) { AIConsentView(session: session) }
        }
    }
}

struct AIRequestStatus: View {
    let coordinator: AIRequestCoordinator
    var label = "Generating insights"
    var body: some View {
        if coordinator.isLoading {
            ProgressView(label)
                .accessibilityIdentifier("aiLoading")
            Text("Hang tight while we gather your insights. Your records won’t change.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Cancel request") { coordinator.cancel() }.accessibilityIdentifier("cancelAIRequest")
        }
        if let message = coordinator.message {
            InlineError(message: message).accessibilityIdentifier("aiError")
        }
    }
}

struct WellnessSafetyNotice: View {
    let symptoms: [SymptomEntry]
    let today: LocalDay?
    var body: some View {
        if symptoms.contains(where: { $0.day == today && $0.value == 3 && $0.kind.usesSeverity }) {
            Label("You logged a severe symptom today. General wellness suggestions are not treatment. Consider medical advice; seek urgent care for severe or sudden concerning symptoms.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("localSevereSymptomNotice")
        }
    }
}

struct AISafetyNotice: View {
    let message: String?
    var body: some View {
        if let message {
            Label { Text(verbatim: message) } icon: { Image(systemName: "exclamationmark.triangle") }
                .font(.footnote).padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("aiSafetyMessage")
        }
    }
}

struct AIPrivacySection: View {
    let session: TrackerSession
    @State private var error: String?
    var body: some View {
        Section("Optional insights") {
            LabeledContent("External processing", value: session.privacy.aiEnabled ? "Enabled" : "Off")
                .accessibilityIdentifier("aiConsentStatus")
            if session.privacy.aiEnabled || session.privacy.preferences.aiConsent != nil {
                Button("Turn off insights", role: .destructive) { error = session.setAIEnabled(false) }
                    .accessibilityIdentifier("disableAI")
            }
            DailyInsightsPreference(session: session)
            if let error { InlineError(message: error) }
            Text("Requests are manual unless daily preparation is enabled separately. Today’s insights stay on this device until the day ends and are never exported. Turning off deletes them, not your records.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// One daily_insights_v2 section. Unavailable sections are successful results, not errors.
/// Generated strings use Text(verbatim:) so they are never parsed as Markdown or linkified.
struct DailyInsightSectionView: View {
    let section: DailyInsightSection
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(section.kind.title, systemImage: section.kind.symbol)
                .font(compact ? .subheadline.weight(.semibold) : .headline)
                .accessibilityAddTraits(.isHeader)
            if section.status == .available {
                ForEach(Array(section.suggestions.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        if !compact { Image(systemName: "circle.fill").font(.system(size: 5)).accessibilityHidden(true) }
                        Text(verbatim: item).font(compact ? .subheadline : .body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(Self.message(for: section.unavailableReason))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dailyInsightUnavailable_\(section.kind.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyInsightSection_\(section.kind.rawValue)")
    }

    static func message(for reason: DailyInsightSection.Reason?) -> String {
        switch reason {
        case .missingPreferences?: "Add your preferences in Insight settings to personalize this."
        case .safetyLimit?: "Paused today because of a severe symptom you logged. Rest and consider medical advice."
        case .insufficientContext?, nil: "Not enough information for this today."
        }
    }
}

/// All generated strings render as plain text, not Markdown, links, or executable instructions.
struct AIOutputView: View {
    let output: AIOutput
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Key insights", systemImage: "sparkles")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            switch output {
            case .symptoms:
                EmptyView() // Only the editable, confirmed symptom review may render these.
            case .insight(let value):
                TrackerCard(highlighted: true) {
                    Text(verbatim: value.title).font(.title3.weight(.semibold))
                    Text(verbatim: value.explanation)
                }
                TrackerCard { Text("AI interpretation · Check against your records").font(.headline); Text(verbatim: value.supportingObservation) }
                AISafetyNotice(message: value.safetyMessage)
            case .wellness(let value):
                list("Movement", value.movementSuggestions, symbol: "figure.walk")
                list("Food", value.foodSuggestions, symbol: "fork.knife")
                TrackerCard { Label("Hydration", systemImage: "drop").font(.headline); Text(verbatim: value.hydrationSuggestion) }
                list("Recovery", value.recoverySuggestions, symbol: "leaf")
                TrackerCard { DisclosureGroup("Why these?") { Text(verbatim: value.explanation).padding(.top, 8) } }
                AISafetyNotice(message: value.safetyMessage)
            case .summary(let value):
                TrackerCard(highlighted: true) { Text(verbatim: value.summary) }
                list("Highlights", value.highlights, symbol: "list.bullet")
                AISafetyNotice(message: value.safetyMessage)
            case .question(let value):
                TrackerCard(highlighted: true) { Text(verbatim: value.answer) }
                list("Supporting observations", value.supportingFacts, symbol: "chart.bar")
                AISafetyNotice(message: value.safetyMessage)
            case .dailyInsights(let value):
                AISafetyNotice(message: value.safetyMessage)
                ForEach(value.sections, id: \.kind) { section in
                    TrackerCard { DailyInsightSectionView(section: section) }
                }
                TrackerCard { DisclosureGroup("Why these?") { Text(verbatim: value.explanation).padding(.top, 8) } }
            }
            Text("Check against your records. Not medical advice.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .font(.body).lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("aiOutput")
    }
    private func list(_ title: String, _ items: [String], symbol: String) -> some View {
        TrackerCard {
            Label(title, systemImage: symbol).font(.headline).accessibilityAddTraits(.isHeader)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "circle.fill").font(.system(size: 5)).accessibilityHidden(true)
                    Text(verbatim: item).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
