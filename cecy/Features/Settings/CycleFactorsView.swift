import SwiftUI

struct CycleFactorsView: View {
    let session: TrackerSession
    @State private var editing: CycleFactor?
    @State private var adding = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What are cycle factors?").font(.headline)
                    Text("Cycle factors are things that might affect the length or regularity of your cycle, such as illness, stress, travel, pregnancy, or starting or stopping contraception.")
                    Text("Adding one explains why a cycle looked different and can keep it out of forecast averages. Your period records are never changed or deleted.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Section("Timeline") {
                if session.snapshot.cycleFactors.isEmpty { Text("No dated factors").foregroundStyle(.secondary) }
                ForEach(session.snapshot.cycleFactors.reversed()) { factor in
                    Button { editing = factor } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(factor.kind.title).foregroundStyle(.primary)
                                Spacer()
                                if factor.excludesFromForecast {
                                    Label("Excluded", systemImage: "minus.circle").font(.caption)
                                }
                            }
                            Text(dateRange(factor)).font(.caption).foregroundStyle(.secondary)
                            let affected = affectedIntervals(factor)
                            Text(affected.isEmpty ? "No completed cycle intervals affected"
                                 : "Affects \(affected.count) completed interval\(affected.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            if !session.snapshot.cycleFactors.isEmpty {
                Section("Forecast evidence") {
                    Text("\(session.overview?.intervals.count ?? 0) intervals currently included")
                    Text("\(session.overview?.excludedIntervals.count ?? 0) intervals excluded with a visible factor reason")
                    ForEach(session.overview?.excludedIntervals ?? []) { interval in
                        VStack(alignment: .leading) {
                            Text("\(TrackerExport.civilDate(interval.start)) – \(TrackerExport.civilDate(interval.nextStart))")
                            Text(reasons(interval)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Missing logs are never labeled as biological irregularity. Add ‘Possible missed record’ only when you choose that explanation.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Cycle factors")
        .toolbar { Button { adding = true } label: { Label("Add", systemImage: "plus") } }
        .sheet(isPresented: $adding) { CycleFactorEditorView(session: session, factor: nil) }
        .sheet(item: $editing) { CycleFactorEditorView(session: session, factor: $0) }
    }

    private func affectedIntervals(_ factor: CycleFactor) -> [CycleInterval] {
        let periods = session.snapshot.periods.sorted { $0.start < $1.start }
        return zip(periods, periods.dropFirst()).map { CycleInterval(id: $0.id, start: $0.start, nextStart: $1.start) }
            .filter { factor.overlaps(start: $0.start, end: $0.nextStart) }
    }
    private func reasons(_ interval: CycleInterval) -> String {
        session.snapshot.cycleFactors.filter {
            $0.excludesFromForecast && $0.overlaps(start: interval.start, end: interval.nextStart)
        }.map(\.kind.title).joined(separator: ", ")
    }
    private func dateRange(_ factor: CycleFactor) -> String {
        "\(TrackerExport.civilDate(factor.start)) – \(factor.end.map(TrackerExport.civilDate) ?? "ongoing")"
    }
}

struct CycleFactorEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let original: CycleFactor?
    @State private var value: CycleFactor
    @State private var hasEnd: Bool
    @State private var notes: String
    @State private var error: String?
    @State private var confirmDelete = false

    /// `draft` pre-fills a new, unsaved factor (for example from a Today follow-up question).
    init(session: TrackerSession, factor: CycleFactor?, draft: CycleFactor? = nil) {
        self.session = session
        original = factor
        let day = session.today ?? (try! LocalDay(key: 20010101))
        let initial = factor ?? draft ?? CycleFactor(kind: .stress, start: day)
        _value = State(initialValue: initial)
        _hasEnd = State(initialValue: initial.end != nil)
        _notes = State(initialValue: initial.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ChipPicker(title: "What might affect your cycle?", options: CycleFactorKind.allCases,
                               selection: $value.kind, label: \.title)
                    DatePicker("Started", selection: dayBinding($value.start), in: ...Date(), displayedComponents: .date)
                    Toggle("Has an end date", isOn: $hasEnd)
                    if hasEnd { DatePicker("Ended", selection: endBinding, in: value.start.formattingDate...Date(), displayedComponents: .date) }
                    TextField("Private note (optional)", text: $notes, axis: .vertical).lineLimit(2...5)
                } header: { Text("Cycle factor") }
                footer: { Text("Something that might affect the length or regularity of your cycle during these dates.") }
                Section {
                    Toggle("Exclude affected intervals from forecasts", isOn: $value.excludesFromForecast)
                    Text("Your period records stay unchanged. Cecy will show affected intervals and this reason. Turn this off to include them again.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Forecast use") }
                if let error { Section { InlineError(message: error) } }
                if original != nil { Section { Button("Delete factor", role: .destructive) { confirmDelete = true } } }
            }
            .navigationTitle(original == nil ? "Add cycle factor" : "Edit cycle factor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .confirmationDialog("Delete this factor?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let original { error = session.deleteCycleFactor(id: original.id); if error == nil { dismiss() } }
                }
            }
            .onChange(of: value.kind) { old, new in
                if value.excludesFromForecast == old.defaultExcludesForecast { value.excludesFromForecast = new.defaultExcludesForecast }
            }
            .onChange(of: hasEnd) { _, enabled in if !enabled { value.end = nil } }
        }
    }

    private func dayBinding(_ binding: Binding<LocalDay>) -> Binding<Date> {
        Binding(get: { binding.wrappedValue.formattingDate }, set: {
            if let day = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) { binding.wrappedValue = day }
        })
    }
    private var endBinding: Binding<Date> {
        Binding(get: { (value.end ?? value.start).formattingDate }, set: { value.end = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) })
    }
    private func save() {
        value.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        if hasEnd && value.end == nil { value.end = value.start }
        do {
            try P1RecordValidation.validate(factors: [value], treatments: [], adherence: [], asOf: session.today)
            error = session.saveCycleFactor(value)
            if error == nil { dismiss() }
        } catch { self.error = error.localizedDescription }
    }
}
