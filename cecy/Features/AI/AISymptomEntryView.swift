import SwiftUI

struct AISymptomEntryView: View {
    let session: TrackerSession
    @Environment(\.dismiss) private var dismiss
    @State private var day: LocalDay
    @State private var text = ""
    @State private var keepNote = true
    @State private var selected: Set<SymptomKind> = []
    @State private var ratings: [SymptomKind: Int] = [:]
    @State private var identifiers: [SymptomKind: UUID] = [:]
    @State private var reviewed = false
    @State private var manual = false
    @State private var error: String?
    @State private var discard = false
    @FocusState private var typing: Bool

    init(session: TrackerSession, day: LocalDay) {
        self.session = session
        _day = State(initialValue: day)
    }
    private var entries: [SymptomEntry] {
        SymptomKind.allCases.filter { selected.contains($0) }.map { kind in
            SymptomEntry(id: identifiers[kind] ?? UUID(), day: day, kind: kind, value: ratings[kind],
                         notes: keepNote && !text.isEmpty ? text : nil)
        }
    }
    private var validation: String? {
        guard !selected.isEmpty else { return "Select at least one symptom to save." }
        do {
            try SymptomValidation.validate(session.snapshot.symptoms + entries, asOf: session.today)
            return nil
        } catch { return error.localizedDescription }
    }
    private var validText: Bool { (try? AIContextBuilder.validateText(text)) != nil }
    private var hasDraft: Bool { !text.isEmpty || !selected.isEmpty }

    var body: some View {
        Form {
            Section("Describe how you feel") {
                TextField("For example: I feel tired and bloated", text: $text, axis: .vertical)
                    .lineLimit(3...8).focused($typing).accessibilityIdentifier("aiSymptomText")
                    .disabled(session.ai.isLoading || reviewed)
                Text("\(text.count) / 2,000 characters").font(.footnote)
                Text("Only this description is sent. Leave out identifying details.")
                    .font(.footnote).foregroundStyle(.secondary)
                DatePicker("Date", selection: Binding(get: { day.formattingDate }, set: {
                    if let value = try? LocalDay(date: $0, timeZone: .gmt) { day = value }
                }), in: ...(session.today ?? day).formattingDate, displayedComponents: .date)
                .disabled(session.ai.isLoading)
                if !manual && !reviewed {
                    AIConsentControl(session: session)
                    Button("Find symptoms") {
                        typing = false
                        error = nil
                        do { session.performAI(try AIContextBuilder.normalization(text)) }
                        catch { self.error = error.localizedDescription }
                    }
                    .disabled(!validText || !session.canUseAI || session.ai.isLoading)
                    .accessibilityIdentifier("normalizeSymptoms")
                }
                AIRequestStatus(coordinator: session.ai, label: "Mapping your symptoms")
                if !reviewed {
                    Button("Choose symptoms manually instead") {
                        session.ai.cancel(); typing = false; manual = true; reviewed = true
                    }.accessibilityIdentifier("aiManualFallback")
                }
            }
            if reviewed {
                Section(manual ? "Choose symptoms" : "Review symptoms before saving") {
                    Text("Nothing saved yet. Check the symptoms and ratings, then save when you’re ready.")
                    SelectionFlowLayout {
                        ForEach(SymptomKind.allCases, id: \.self) { kind in
                            SelectionChip(title: kind.title, symbol: kind.symbol, selected: selected.contains(kind)) {
                                if selected.contains(kind) { selected.remove(kind); ratings[kind] = nil }
                                else { selected.insert(kind); identifiers[kind] = identifiers[kind] ?? UUID() }
                            }
                            .accessibilityIdentifier("aiSymptom_\(kind.rawValue)")
                        }
                    }
                    ForEach(SymptomKind.allCases.filter { selected.contains($0) }, id: \.self) { kind in
                        Picker(kind.title + " · " + kind.ratingTitle, selection: Binding(get: { ratings[kind] }, set: { ratings[kind] = $0 })) {
                            Text("Not rated").tag(Int?.none)
                            ForEach(1...3, id: \.self) { Text(kind.ratingLabels[$0 - 1]).tag(Int?.some($0)) }
                        }
                        if session.snapshot.symptoms.contains(where: { $0.day == day && $0.kind == kind }) {
                            Label("\(kind.title) is already recorded on this date. Deselect it here or edit the existing observation.", systemImage: "exclamationmark.circle")
                                .font(.footnote)
                        }
                    }
                    if selected.contains(.sleepQuality) || selected.contains(.energyLevel) {
                        Text("Choose your sleep or energy rating, or leave Not rated.")
                    }
                    Toggle("Keep description as a private note", isOn: $keepNote)
                    Text("Saves your description with each selected symptom. It won’t be sent again automatically.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Edit description") {
                        session.ai.cancel(); selected = []; ratings = [:]; reviewed = false; manual = false
                    }
                    if let validation { InlineError(message: validation) }
                    Button("Save confirmed symptoms") {
                        typing = false
                        guard validation == nil, manual || session.canUseAI else { return }
                        let values = entries
                        Task {
                            error = await session.withPredictionUpdate { session.addSymptoms(values) }
                            if error == nil { dismiss() }
                        }
                    }
                    .disabled(validation != nil || session.isSaving || (!manual && !session.canUseAI))
                    .accessibilityIdentifier("saveAISymptoms")
                }
            }
            if let error { InlineError(message: error) }
        }
        .trackerFormStyle()
        .environment(\.calendar, LocalDay.calendar)
        .environment(\.timeZone, LocalDay.calendar.timeZone)
        .navigationTitle("Describe symptoms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { if hasDraft { discard = true } else { dismiss() } }
            }
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Hide keyboard") { typing = false } }
        }
        .interactiveDismissDisabled(hasDraft || session.ai.isLoading)
        .alert("Discard this unsaved draft?", isPresented: $discard) {
            Button("Discard", role: .destructive) { session.ai.cancel(); dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .onChange(of: session.ai.output) { _, output in
            guard case .symptoms(let result) = output else { return }
            guard !result.symptoms.isEmpty else {
                error = "No supported symptoms were found. Edit your description or choose symptoms manually."
                return
            }
            selected = Set(result.symptoms.map { $0.type.kind })
            ratings = Dictionary(uniqueKeysWithValues: result.symptoms.compactMap { item in
                item.suggestedRating.map { (item.type.kind, $0) }
            })
            identifiers = Dictionary(uniqueKeysWithValues: selected.map { ($0, UUID()) })
            reviewed = true
        }
        .onChange(of: session.ai.revision) { _, _ in
            guard !session.isUpdatingPredictions else { return }
            text = ""; selected = []; ratings = [:]; identifiers = [:]; error = nil
            reviewed = false; manual = false; dismiss()
        }
        .onAppear { session.ai.cancel() }
        .onDisappear { session.ai.cancel() }
    }
}
