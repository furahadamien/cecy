import SwiftUI

struct SymptomEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let original: SymptomEntry?
    private let initialDay: LocalDay
    @State private var day: LocalDay
    @State private var selectedKinds: Set<SymptomKind>
    @State private var ratings: [SymptomKind: Int]
    @State private var notes: String
    @State private var saveError: String?
    @State private var discard = false
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, day: LocalDay, entry: SymptomEntry? = nil) {
        self.session = session
        original = entry
        initialDay = entry?.day ?? day
        _day = State(initialValue: entry?.day ?? day)
        _selectedKinds = State(initialValue: entry.map { [$0.kind] } ?? [])
        _ratings = State(initialValue: entry.flatMap { entry in entry.value.map { [entry.kind: $0] } } ?? [:])
        _notes = State(initialValue: entry?.notes ?? "")
    }

    private var changed: Bool {
        day != initialDay || selectedKinds != (original.map { Set([$0.kind]) } ?? [])
            || ratings != (original.flatMap { entry in entry.value.map { [entry.kind: $0] } } ?? [:])
            || notes != (original?.notes ?? "")
    }
    private var orderedKinds: [SymptomKind] { SymptomKind.allCases.filter { selectedKinds.contains($0) } }
    private var entries: [SymptomEntry] {
        orderedKinds.map { kind in
            SymptomEntry(id: original?.id ?? UUID(), day: day, kind: kind, value: ratings[kind], notes: notes,
                         createdAt: original?.createdAt ?? Date(), updatedAt: original?.updatedAt)
        }
    }
    private var validation: String? {
        guard !selectedKinds.isEmpty else { return "Choose at least one symptom." }
        do {
            try SymptomValidation.validate(session.snapshot.symptoms.filter { $0.id != original?.id } + entries, asOf: session.today)
            return nil
        } catch { return (error as? TrackingError)?.localizedDescription ?? "Review your observation." }
    }

    var body: some View {
        NavigationStack {
            Form {
                if original == nil {
                    Section {
                        Text("Pick your symptoms below, or describe how you feel.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        NavigationLink {
                            AISymptomEntryView(session: session, day: day)
                        } label: {
                            Label("Describe how you feel", systemImage: "sparkles")
                        }
                        .accessibilityIdentifier("describeSymptoms")
                    } footer: { Text("Review your symptoms before saving.") }
                }
                Section {
                    SelectionFlowLayout {
                        ForEach(SymptomKind.allCases, id: \.self) { kind in
                            symptomButton(kind)
                        }
                    }
                    .accessibilityIdentifier("symptomKinds")
                } header: {
                    Text("Symptoms")
                } footer: {
                    Text(original == nil ? "Choose all that apply. Tap again to deselect." : "Choose a type for this observation.")
                }
                Section {
                    DatePicker("Date", selection: Binding(get: { day.formattingDate }, set: {
                        if let value = try? LocalDay(date: $0, timeZone: .gmt) { day = value }
                    }), in: ...(session.today ?? initialDay).formattingDate, displayedComponents: .date)
                    .accessibilityIdentifier("symptomDate")
                    ForEach(orderedKinds, id: \.self) { kind in
                        Picker(selection: Binding(get: { ratings[kind] }, set: { ratings[kind] = $0 })) {
                            Text("Not rated").tag(Int?.none)
                            ForEach(1...3, id: \.self) { Text(kind.ratingLabels[$0 - 1]).tag(Int?.some($0)) }
                        } label: {
                            VStack(alignment: .leading) {
                                Label(kind.title, systemImage: kind.symbol)
                                Text(kind.ratingTitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("symptomRating_\(kind.rawValue)")
                    }
                } footer: {
                    Text("One observation of each type per day. Not logging something does not mean it was absent.")
                }
                Section {
                    TextField("Add a note", text: $notes, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("symptomNotes")
                    Text("\(notes.count) / 2,000 characters").font(.footnote)
                } header: {
                    Text("Private note (optional)")
                } footer: {
                    if selectedKinds.count > 1 { Text("This note is saved with each selected symptom.") }
                }
                if let message = saveError ?? validation {
                    InlineError(message: message).accessibilityFocused($errorFocused)
                }
            }
            .trackerFormStyle()
            .environment(\.calendar, LocalDay.calendar)
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle(original == nil ? "Log symptoms" : "Edit observation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { discard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard validation == nil else { return }
                        let values = entries
                        if original != nil, let entry = values.first {
                            saveError = session.saveSymptom(entry, editing: true)
                        } else {
                            saveError = session.addSymptoms(values)
                        }
                        if saveError == nil { dismiss() } else { errorFocused = true }
                    }
                    .disabled(validation != nil || session.isSaving || (original != nil && !changed))
                    .accessibilityIdentifier("saveSymptom")
                }
            }
            .interactiveDismissDisabled(changed || session.isSaving)
            .alert("Discard unsaved changes?", isPresented: $discard) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .onChange(of: day) { _, _ in saveError = nil }
            .onChange(of: selectedKinds) { _, _ in saveError = nil }
            .onChange(of: ratings) { _, _ in saveError = nil }
            .onChange(of: notes) { _, _ in saveError = nil }
            .onChange(of: validation) { _, message in
                if let message { AccessibilityNotification.Announcement(message).post() }
            }
        }
    }

    private func symptomButton(_ kind: SymptomKind) -> some View {
        let selected = selectedKinds.contains(kind)
        return SelectionChip(title: kind.title, symbol: kind.symbol, selected: selected) {
            if selected {
                selectedKinds.remove(kind)
                ratings[kind] = nil
            } else {
                if original != nil { selectedKinds.removeAll(); ratings.removeAll() }
                selectedKinds.insert(kind)
            }
        }
        .accessibilityIdentifier("symptomKind_\(kind.rawValue)")
    }
}

struct SymptomLogButton: View {
    let session: TrackerSession
    let day: LocalDay
    @State private var showEntry = false
    var body: some View {
        Button { showEntry = true } label: {
            Label("Log symptoms", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget)
        }
        .buttonStyle(.bordered).accessibilityIdentifier("logSymptoms")
        .sheet(isPresented: $showEntry) { SymptomEntryView(session: session, day: day) }
    }
}

struct SymptomRecordView: View {
    let session: TrackerSession
    let entry: SymptomEntry
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(entry.kind.title, systemImage: entry.kind.symbol).font(.headline)
            Text(DayText.full(entry.day))
            Text(entry.ratingLabel ?? "Not rated").foregroundStyle(.secondary)
            if let notes = entry.notes { Text(notes) }
            Button("Edit observation") { editing = true }.frame(minHeight: 44)
                .accessibilityIdentifier("editSymptom_\(entry.kind.rawValue)")
            Button("Delete observation", role: .destructive) { deleting = true }.frame(minHeight: 44)
                .accessibilityIdentifier("deleteSymptom_\(entry.kind.rawValue)")
            if let error { InlineError(message: error) }
        }
        .sheet(isPresented: $editing) { SymptomEntryView(session: session, day: entry.day, entry: entry) }
        .alert("Delete this observation?", isPresented: $deleting) {
            Button("Delete recorded observation", role: .destructive) { error = session.deleteSymptom(id: entry.id) }
            Button("Keep observation", role: .cancel) { }
        } message: { Text("Its rating and private note will also be removed. This cannot be undone.") }
        .onChange(of: error) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
    }
}
