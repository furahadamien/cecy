import SwiftUI

nonisolated enum AIFeature {
    case wellness, insight(CycleInsight), summary(LocalDay), question, records
    var title: String {
        switch self {
        case .wellness: "For today"
        case .insight: "Explain this observation"
        case .summary: "Your cycle summary"
        case .question: "Ask about your records"
        case .records: "Insights from your records"
        }
    }
}

struct AIFeatureView: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let feature: AIFeature
    @Environment(\.dismiss) private var dismiss
    @State private var scope: CycleQuestionScope = .cycleLengths
    @State private var kinds: Set<SymptomKind> = [.headache]
    @State private var question = CycleQuestionScope.cycleLengths.suggestedQuestion(kind: .headache)
    @State private var typing = false
    @ScaledMetric(relativeTo: .body) private var questionEditorHeight = 118.0

    private var preparation: Result<AIRequest, Error> {
        Result {
            guard let today = session.today else { throw AIContextError.insufficientRecords }
            switch feature {
            case .wellness: return try AIContextBuilder.wellness(snapshot: session.snapshot, today: today)
            case .insight(let insight):
                guard session.insights.contains(insight) else { throw AIContextError.insufficientRecords }
                return try AIContextBuilder.insight(insight)
            case .summary(let start): return try AIContextBuilder.summary(snapshot: session.snapshot, start: start, today: today)
            case .question: return try AIContextBuilder.question(question, scope: scope, kinds: kinds, snapshot: session.snapshot, today: today)
            case .records: return try AIContextBuilder.recordInsights(snapshot: session.snapshot, today: today)
            }
        }
    }
    private var isQuestion: Bool { if case .question = feature { true } else { false } }
    private var isWellness: Bool { if case .wellness = feature { true } else { false } }
    private var wellnessOutput: AIOutput? {
        guard isWellness, session.canUseAI, case .success(let request) = preparation,
              let value = session.ai.wellness(for: request) else { return nil }
        return .wellness(value)
    }

    var body: some View {
        SettingsForm(title: feature.title) {
            if isWellness {
                Section { WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: session.today) }
            }
            if let wellnessOutput {
                Section { AIOutputView(output: wellnessOutput) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            Section {
                if !isWellness {
                    Text("A little clarity, based on your records.").font(.title3.weight(.medium))
                    Text("Even one record can be described. Small samples do not establish patterns; missing lengths and end dates stay unknown.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if isWellness {
                    NavigationLink("Edit wellness preferences") { ProfileSettingsView(session: session) }
                        .accessibilityIdentifier("wellnessPreferencesLink")
                    Text("Based on today’s symptoms and preferences. Always check ingredients against your allergies.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if isQuestion {
                Section("Choose the records to discuss") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(CycleQuestionScope.allCases) { choice in
                                SelectionChip(title: choice.title, selected: scope == choice) { scope = choice }
                                    .accessibilityIdentifier("aiQuestionScope_\(choice.rawValue)")
                            }
                        }.padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("aiQuestionScope")
                    if scope != .cycleLengths {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Symptoms").font(.headline)
                                Spacer()
                                Text("\(kinds.count) selected").font(.caption).foregroundStyle(.secondary)
                            }
                            SelectionFlowLayout {
                                ForEach(SymptomKind.allCases, id: \.self) { kind in
                                    SelectionChip(title: kind.title, symbol: kind.symbol, selected: kinds.contains(kind)) {
                                        if kinds.remove(kind) == nil { kinds.insert(kind) }
                                    }.accessibilityIdentifier("questionSymptom_\(kind.rawValue)")
                                }
                            }
                        }
                        .padding(12)
                        .background(TrackerPalette(scheme: colorScheme).sage, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("questionSymptoms")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your question").font(.subheadline.weight(.medium))
                        BoundedQuestionEditor(text: $question, focused: $typing)
                            .frame(height: questionEditorHeight)
                            .padding(14)
                            .background(TrackerPalette(scheme: colorScheme).background,
                                        in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous)
                                .strokeBorder(.secondary.opacity(0.5)))
                            .accessibilityLabel("Your question")
                            .accessibilityIdentifier("aiQuestionText")
                        Text("\(question.count) / 100").font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityIdentifier("questionCharacterCount")
                    }
                }.disabled(session.ai.isLoading)
            }
            switch preparation {
            case .success(let request):
                Section {
                    AIConsentControl(session: session)
                    Button(session.ai.output == nil && wellnessOutput == nil ? "Generate" : "Generate again") {
                        typing = false
                        session.performAI(request)
                    }
                    .disabled(!session.canUseAI || session.ai.isLoading)
                    .buttonStyle(TrackerPrimaryButtonStyle())
                    .accessibilityIdentifier("generateAI")
                    AIRequestStatus(coordinator: session.ai)
                } footer: {
                    Text("Only your question and selected details are sent when you generate. Results are not saved.")
                }
                if !isWellness, let output = session.ai.output, session.ai.request == request {
                    Section { AIOutputView(output: output) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                }
            case .failure(let error):
                Section {
                    InlineError(message: error.localizedDescription)
                    if isWellness {
                        NavigationLink("Edit local wellness preferences") { ProfileSettingsView(session: session) }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scope) { _, _ in session.ai.cancel(); question = scope.initialQuestion(kinds: kinds) }
        .onChange(of: kinds) { old, new in
            session.ai.cancel()
            if question == scope.initialQuestion(kinds: old) { question = scope.initialQuestion(kinds: new) }
        }
        .onChange(of: question) { _, value in
            if value.count > AIContextBuilder.maximumQuestionLength {
                question = String(value.prefix(AIContextBuilder.maximumQuestionLength))
            }
            session.ai.cancel()
        }
        .onChange(of: session.ai.revision) { _, _ in question = ""; dismiss() }
        .onAppear { session.ai.cancel() }
        .onDisappear { session.ai.cancel() }
    }
}
