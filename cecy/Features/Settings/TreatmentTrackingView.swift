import SwiftUI

struct TreatmentTrackingView: View {
    let session: TrackerSession
    @State private var editing: TreatmentRecord?
    @State private var adding = false

    var body: some View {
        List {
            Section {
                Text("Keep a dated record of contraception, medication and supplements. Cecy does not calculate effectiveness, interactions, or pregnancy risk.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(TreatmentCategory.allCases, id: \.self) { category in
                let values = session.snapshot.treatments.filter { $0.category == category }
                Section(category.title) {
                    if values.isEmpty { Text("None recorded").foregroundStyle(.secondary) }
                    ForEach(values) { value in
                        Button { editing = value } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(value.name).foregroundStyle(.primary)
                                Text(detail(value)).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Treatments")
        .toolbar { Button { adding = true } label: { Label("Add", systemImage: "plus") } }
        .sheet(isPresented: $adding) {
            TreatmentEditorView(session: session, treatment: nil)
        }
        .sheet(item: $editing) { TreatmentEditorView(session: session, treatment: $0) }
    }

    private func detail(_ value: TreatmentRecord) -> String {
        var parts = [value.category.title, value.cadence.title, TrackerExport.civilDate(value.start)]
        if let end = value.end { parts.append("ended \(TrackerExport.civilDate(end))") }
        if value.reminderEnabled { parts.append("reminder on") }
        return parts.joined(separator: " · ")
    }
}

private struct TreatmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let original: TreatmentRecord?
    @State private var value: TreatmentRecord
    @State private var hasEnd: Bool
    @State private var error: String?
    @State private var confirmDelete = false

    init(session: TrackerSession, treatment: TreatmentRecord?) {
        self.session = session
        original = treatment
        let day = session.today ?? (try! LocalDay(key: 20010101))
        let initial = treatment ?? TreatmentRecord(category: .medication, name: "", start: day)
        _value = State(initialValue: initial)
        _hasEnd = State(initialValue: initial.end != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Record") {
                    Picker("Type", selection: $value.category) {
                        ForEach(TreatmentCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    TextField(value.category == .contraception ? "Method name" : "Name", text: $value.name)
                        .textInputAutocapitalization(.words)
                    if value.category == .contraception {
                        Picker("Method", selection: contraceptionBinding) {
                            ForEach(ContraceptionType.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                    }
                    TextField("Dose or instructions (optional)", text: optionalText($value.dose))
                    Picker("Schedule", selection: $value.cadence) {
                        ForEach(TreatmentCadence.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                Section("Dates") {
                    DatePicker("Started", selection: dayBinding($value.start), in: ...Date(), displayedComponents: .date)
                    Toggle("Has an end date", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Ended", selection: endBinding, in: value.start.formattingDate...Date(), displayedComponents: .date)
                    }
                }
                Section {
                    Toggle("Private reminder", isOn: $value.reminderEnabled)
                    if value.reminderEnabled {
                        DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        Text("The lock-screen message stays discreet unless notification details are enabled in Reminders.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: { Text("Reminder") }
                footer: { Text("A reminder records no adherence automatically. You still choose Taken, Late, Missed, or Skipped.") }
                if value.category == .contraception {
                    Section {
                        Text("This also adds a dated cycle factor so affected intervals are explained. Cecy does not estimate contraceptive effectiveness or pregnancy risk.")
                    }
                }
                if let error { Section { InlineError(message: error) } }
                if original != nil {
                    Section { Button("Delete record", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(original == nil ? "Add treatment" : "Edit treatment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .confirmationDialog("Delete this treatment and its check-ins?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let original { error = session.deleteTreatment(id: original.id); if error == nil { dismiss() } }
                }
            }
            .onChange(of: value.category) { _, category in
                if category == .contraception { value.contraceptionType = value.contraceptionType ?? .pill }
                else { value.contraceptionType = nil }
            }
            .onChange(of: hasEnd) { _, enabled in if !enabled { value.end = nil } }
        }
    }

    private var contraceptionBinding: Binding<ContraceptionType> {
        Binding(get: { value.contraceptionType ?? .pill }, set: { value.contraceptionType = $0 })
    }
    private func optionalText(_ binding: Binding<String?>) -> Binding<String> {
        Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 })
    }
    private func dayBinding(_ binding: Binding<LocalDay>) -> Binding<Date> {
        Binding(get: { binding.wrappedValue.formattingDate }, set: {
            if let day = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) { binding.wrappedValue = day }
        })
    }
    private var endBinding: Binding<Date> {
        Binding(get: { (value.end ?? value.start).formattingDate }, set: {
            value.end = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone)
        })
    }
    private var timeBinding: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1,
                hour: value.reminderHour, minute: value.reminderMinute)) ?? Date()
        }, set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            value.reminderHour = parts.hour ?? 20; value.reminderMinute = parts.minute ?? 0
        })
    }
    private func save() {
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasEnd && value.end == nil { value.end = value.start }
        do {
            try P1RecordValidation.validate(factors: [], treatments: [value], adherence: [], asOf: session.today)
            error = session.saveTreatment(value)
            if error == nil {
                if value.reminderEnabled {
                    let preferences = session.privacy.preferences
                    Task {
                        _ = await session.privacy.setUsefulReminders(
                            periodFollowUp: preferences.periodFollowUpReminder == true,
                            symptomKinds: preferences.symptomReminderKinds ?? [],
                            missedLog: preferences.missedLogReminder == true)
                    }
                }
                dismiss()
            }
        } catch { self.error = error.localizedDescription }
    }
}

struct TreatmentCheckInView: View {
    let session: TrackerSession
    let day: LocalDay
    @State private var error: String?

    private var active: [TreatmentRecord] {
        session.snapshot.treatments.filter { $0.start <= day && ($0.end.map { day <= $0 } ?? true) }
    }

    var body: some View {
        List {
            Section {
                Text(DayText.full(day)).font(.headline)
                Text("Choose a state only when you want to create or correct a record. Cecy never treats an unlogged day as missed.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if active.isEmpty {
                ContentUnavailableView("No active treatments", systemImage: "pills", description: Text("Add medication or contraception in Settings."))
            }
            ForEach(active) { treatment in
                Section(treatment.name) {
                    let saved = session.snapshot.treatmentAdherence.first { $0.treatmentID == treatment.id && $0.day == day }
                    ForEach(AdherenceState.allCases, id: \.self) { state in
                        Button {
                            error = session.saveTreatmentAdherence(TreatmentAdherence(id: saved?.id ?? UUID(),
                                treatmentID: treatment.id, day: day, state: state,
                                notes: saved?.notes, createdAt: saved?.createdAt ?? Date()))
                        } label: {
                            HStack { Text(state.title); Spacer(); if saved?.state == state { Image(systemName: "checkmark") } }
                        }
                    }
                }
            }
            if let error { Section { InlineError(message: error) } }
        }
        .navigationTitle("Treatment check-in")
    }
}
