import SwiftUI

nonisolated enum AIFeature {
    case wellness, insight(CycleInsight), summary(LocalDay), question, records
    var title: String {
        switch self {
        case .wellness: "Today’s insights"
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
    private var coordinator: AIRequestCoordinator { isWellness ? session.dailyAI : session.ai }
    private var wellnessOutput: AIOutput? {
        isWellness ? session.dailyInsightOutput : nil
    }

    var body: some View {
        SettingsForm(title: feature.title) {
            if case .insight(let insight) = feature, session.insights.contains(insight) {
                Section("Calculated on this device") {
                    InsightCard(insight: insight)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("aiLocalInsight")
                }
            }
            if isWellness {
                Section { WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: session.today) }
            }
            if let wellnessOutput {
                Section { AIOutputView(output: wellnessOutput) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            if isWellness {
                Section { DailyInsightsPreference(session: session) }
            }
            Section {
                if !isWellness {
                    Text("A little clarity, based on your records.").font(.title3.weight(.medium))
                    Text("Even one record can be described. Small samples do not establish patterns; missing lengths and end dates stay unknown.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if isWellness, session.snapshot.profile?.wellnessPreferences?.isReadyForInsights == true {
                    NavigationLink("Edit wellness preferences") { DailyInsightSetupView(session: session) }
                        .accessibilityIdentifier("wellnessPreferencesLink")
                }
            }
            if isQuestion {
                if let today = session.today {
                    Section {
                        ForEach(PreparedRecordAnswers.build(snapshot: session.snapshot, today: today)) { item in
                            DisclosureGroup(item.question) {
                                Text(item.answer).font(.subheadline)
                            }.accessibilityIdentifier("preparedAnswer_\(item.id)")
                        }
                    } header: { Text("Ready answers") }
                    footer: { Text("Calculated on this device from recorded facts. No request needed.") }
                }
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
                                ForEach(AISymptomType.allCases.map(\.kind), id: \.self) { kind in
                                    SelectionChip(title: kind.title, symbol: kind.symbol, selected: kinds.contains(kind)) {
                                        if kinds.remove(kind) == nil { kinds.insert(kind) }
                                    }.accessibilityIdentifier("questionSymptom_\(kind.rawValue)")
                                }
                            }
                            Text("Only selected symptoms and the recorded facts needed for this question are sent after consent. Energy questions count low ratings; timing questions use poor sleep and low sex-drive ratings.")
                                .font(.caption).foregroundStyle(.secondary)
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
                    if !isWellness { AIConsentControl(session: session) }
                    Button(coordinator.output == nil ? (isWellness ? "Generate today’s insights" : "Generate") : "Generate again") {
                        typing = false
                        session.performAI(request)
                    }
                    .disabled(!session.canUseAI || coordinator.isLoading)
                    .buttonStyle(TrackerPrimaryButtonStyle())
                    .accessibilityIdentifier("generateAI")
                    AIRequestStatus(coordinator: coordinator)
                } footer: {
                    if isWellness {
                        Text("Check ingredients against your allergies. Not medical advice. Results are not saved.")
                    } else {
                        Text("Your question and selected details are sent when you generate. Ready answers stay on-device. Generated results are not saved.")
                    }
                }
                if !isWellness, let output = session.ai.output, session.ai.request == request {
                    Section { AIOutputView(output: output) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                } else if case .records = feature, request == session.dailyInsightRequest,
                          let output = session.dailyInsightOutput {
                    Section { AIOutputView(output: output) }
                        .listRowBackground(Color.clear)
                }
            case .failure(let error):
                if !isWellness || session.snapshot.profile?.wellnessPreferences?.isReadyForInsights == true {
                    Section {
                        InlineError(message: error.localizedDescription)
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
        .onChange(of: session.ai.revision) { _, _ in
            if !isWellness { question = ""; dismiss() }
        }
        .onAppear {
            if isWellness, let today = session.today {
                // A manual visit counts as today's presentation, avoiding a duplicate popup.
                _ = session.privacy.reserveDailyInsightPresentation(on: today)
            } else { session.ai.cancel() }
        }
        .onDisappear { if !isWellness { session.ai.cancel() } }
    }
}
