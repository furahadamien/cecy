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
                Text("Optional AI wording and suggestions. Cecy calculates your facts locally. No request is sent until you choose Generate.")
                if isWellness {
                    Text("Suggestions prioritize today’s logged symptoms, not an assumed cycle phase. Check all food suggestions against your allergies; AI cannot guarantee allergen safety.")
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
                    TextField("Your question", text: $question, axis: .vertical)
                        .lineLimit(2...6).focused($typing).accessibilityIdentifier("aiQuestionText")
                    Button("Use suggested question") { question = scope.suggestedQuestion(kind: kind) }
                    Text("\(question.count) / 2,000 characters. Only this question and the facts below are sent. Other topics stay local and ask you to choose a supported scope.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.disabled(session.ai.isLoading)
            }
            switch preparation {
            case .success(let request):
                Section("Locally calculated information to send") { AIContextPreview(request: request) }
                Section {
                    AIConsentControl(session: session)
                    Button(session.ai.output == nil ? "Generate" : "Generate again") {
                        typing = false
                        session.performAI(request)
                    }
                    .disabled(!session.canUseAI || session.ai.isLoading)
                    .accessibilityIdentifier("generateAI")
                    AIRequestStatus(coordinator: session.ai)
                } footer: {
                    Text("No names, exact dates, record identifiers, private notes, sexual activity or full history are included automatically. Free text is sent as typed. Results are not saved.")
                }
                if let output = session.ai.output, session.ai.request == request {
                    Section { AIOutputView(output: output) }
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
        .onChange(of: question) { _, _ in session.ai.cancel() }
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
