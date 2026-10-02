import SwiftUI

nonisolated enum AIFeature {
    case wellness, insight(CycleInsight), summary(LocalDay), question
    var title: String {
        switch self {
        case .wellness: "For today"
        case .insight: "Explain this observation"
        case .summary: "Your cycle summary"
        case .question: "Ask about your records"
        }
    }
}

struct AIFeatureView: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let feature: AIFeature
    @Environment(\.dismiss) private var dismiss
    @State private var scope: CycleQuestionScope = .cycleLengths
    @State private var kind: SymptomKind = .headache
    @State private var question = CycleQuestionScope.cycleLengths.suggestedQuestion(kind: .headache)
    @FocusState private var typing: Bool

    private var preparation: Result<AIRequest, Error> {
        Result {
            guard let today = session.today else { throw AIContextError.insufficientRecords }
            switch feature {
            case .wellness: return try AIContextBuilder.wellness(snapshot: session.snapshot, today: today)
            case .insight(let insight):
                guard session.insights.contains(insight) else { throw AIContextError.insufficientRecords }
                return try AIContextBuilder.insight(insight)
            case .summary(let start): return try AIContextBuilder.summary(snapshot: session.snapshot, start: start, today: today)
            case .question: return try AIContextBuilder.question(question, scope: scope, kind: kind, snapshot: session.snapshot, today: today)
            }
        }
    }
    private var isQuestion: Bool { if case .question = feature { true } else { false } }
    private var isWellness: Bool { if case .wellness = feature { true } else { false } }
    private var severeSymptoms: Bool {
        session.snapshot.symptoms.contains { $0.day == session.today && $0.value == 3 && $0.kind != .sleepQuality && $0.kind != .energyLevel }
    }

    var body: some View {
        SettingsForm(title: feature.title) {
            Section {
                Text("A little clarity, based on your records.").font(.title3.weight(.medium))
                if isWellness {
                    Text("Based on today’s symptoms and preferences. Always check ingredients against your allergies.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if severeSymptoms {
                        Label("You logged a severe symptom today. General wellness suggestions are not treatment. Consider medical advice; seek urgent care for severe or sudden concerning symptoms.", systemImage: "exclamationmark.triangle")
                            .accessibilityIdentifier("localSevereSymptomNotice")
                    }
                }
            }
            if isQuestion {
                Section("Choose the records to discuss") {
                    Picker("Scope", selection: $scope) {
                        ForEach(CycleQuestionScope.allCases) { Text($0.title).tag($0) }
                    }.accessibilityIdentifier("aiQuestionScope")
                    if scope != .cycleLengths {
                        Picker("Symptom", selection: $kind) {
                            ForEach(SymptomKind.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your question").font(.subheadline.weight(.medium))
                        TextField("Type a question about your records", text: $question, axis: .vertical)
                            .lineLimit(3...5).focused($typing)
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
                    Button("Use suggested question") { question = scope.suggestedQuestion(kind: kind) }
                }.disabled(session.ai.isLoading)
            }
            switch preparation {
            case .success(let request):
                Section {
                    DisclosureGroup("Information used for this request") { AIContextPreview(request: request).padding(.vertical, 8) }
                }
                Section {
                    AIConsentControl(session: session)
                    Button(session.ai.output == nil ? "Generate" : "Generate again") {
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
                if let output = session.ai.output, session.ai.request == request {
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
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Hide keyboard") { typing = false } } }
        .onChange(of: scope) { _, _ in session.ai.cancel(); question = scope.suggestedQuestion(kind: kind) }
        .onChange(of: kind) { _, _ in session.ai.cancel(); question = scope.suggestedQuestion(kind: kind) }
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

struct AIContextPreview: View {
    let request: AIRequest
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch request {
            case .symptoms(let value): Text(verbatim: value.text)
            case .insight(let value):
                Text(verbatim: value.facts.metric)
                if let old = value.facts.previousMetric, let recent = value.facts.recentMetric {
                    Text("Previous: \(old.formatted()) days; recent: \(recent.formatted()) days.")
                    Text("\(value.facts.previousRecordCount ?? 0) previous and \(value.facts.recentRecordCount ?? 0) recent records.")
                }
                if let count = value.facts.startsAnalyzed {
                    Text("\(value.facts.symptom?.kind.timingTitle ?? "Symptom"): matching logs near \(value.facts.matchingStarts ?? 0) of \(count) eligible starts.")
                    Text(verbatim: value.facts.timingWindow ?? "")
                }
                Text(verbatim: value.facts.evidence)
                Text(verbatim: value.facts.caveat)
            case .wellness(let value):
                if let day = value.cycleDay { Text("Recorded cycle day: \(day) — not a phase estimate.") }
                if value.symptoms.isEmpty { Text("No qualifying symptoms logged today; this does not mean symptom-free.") }
                ForEach(value.symptoms, id: \.type) { symptom in
                    Text("\(symptom.type.kind.timingTitle): \(symptom.severity?.rawValue ?? "severity not supplied")")
                }
                Text("Activity: \(value.activityLevel.replacingOccurrences(of: "_", with: " "))")
                Text("Exercise: \(value.preferredExercises.isEmpty ? "no preference" : value.preferredExercises.joined(separator: ", ").replacingOccurrences(of: "_", with: " "))")
                Text("Diet: \(value.dietaryPreference)")
                Text("Food allergies: \(value.foodAllergies.isEmpty ? "none known, as selected" : value.foodAllergies.joined(separator: ", "))")
                Text("Goals: \(value.userGoals.isEmpty ? "none selected" : value.userGoals.joined(separator: ", ").replacingOccurrences(of: "_", with: " "))")
            case .summary(let value):
                Text("Recorded interval: \(value.cycleLength) days")
                Text("Recent recorded average: \(value.averageCycleLength.formatted()) days")
                Text("Confirmed bleeding duration: \(value.periodLength) days inclusive")
                ForEach(value.observations, id: \.self) { Text(verbatim: $0) }
            case .question(let value):
                let facts = value.facts
                if let count = facts.cyclesAnalyzed { Text("\(count) eligible recorded cycles/starts analyzed") }
                if let mean = facts.averageCycleLength {
                    Text("Mean interval: \(mean.formatted()) days")
                    Text("Range: \(facts.minimumCycleLength ?? 0)–\(facts.maximumCycleLength ?? 0) days")
                    if let deviation = facts.populationStandardDeviationDays { Text("Population standard deviation: \(deviation.formatted()) days") }
                }
                if let days = facts.recordedDays { Text("\(facts.symptom?.kind.title ?? "Symptom"): \(days) recorded days in the last \(facts.daysAnalyzed ?? 90) calendar days, including today") }
                if let count = facts.matchingStarts {
                    Text("\(facts.symptom?.kind.timingTitle ?? "Symptom"): logs matched \(count) eligible starts")
                    Text(verbatim: facts.timingWindow ?? "")
                    if let low = facts.minimumRecordedOffsetDays, let high = facts.maximumRecordedOffsetDays {
                        Text("Recorded offsets: \(low) to \(high) days from start")
                    }
                }
                Text(verbatim: facts.caveat)
            }
        }
        .font(.subheadline)
        .accessibilityIdentifier("aiLocalFacts")
    }
}
