import SwiftUI
import Observation

@MainActor @Observable
final class PeriodDraft {
    let original: Period
    var start: LocalDay
    var end: LocalDay
    var includesEnd: Bool
    var flow: PeriodFlow?
    var notes: String

    init(period: Period) {
        original = period
        start = period.start
        end = period.end ?? period.start
        includesEnd = period.end != nil
        flow = period.flow
        notes = period.notes ?? ""
    }

    var period: Period {
        var value = original
        value.start = start
        value.end = includesEnd ? end : nil
        value.flow = flow
        value.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        return value
    }
    var hasChanges: Bool { period != original }

    func validationMessage(existing: [Period], today: LocalDay) -> String? {
        do {
            guard notes.count <= PeriodValidation.maximumNoteLength else { throw TrackingError.noteTooLong }
            try PeriodValidation.validate(existing.filter { $0.id != original.id } + [period], asOf: today)
            return nil
        } catch { return (error as? TrackingError)?.localizedDescription ?? "Review these dates before saving." }
    }
}

struct PeriodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PeriodDraft
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var confirmDiscard = false
    @AccessibilityFocusState private var errorFocused: Bool
    let today: LocalDay
    let existing: [Period]
    let isDraft: Bool
    let isEditing: Bool
    let onSave: (Period) -> String?

    init(period: Period, today: LocalDay, existing: [Period], isDraft: Bool = false,
         isEditing: Bool = false, onSave: @escaping (Period) -> String?) {
        _draft = State(initialValue: PeriodDraft(period: period))
        self.today = today
        self.existing = existing
        self.isDraft = isDraft
        self.isEditing = isEditing
        self.onSave = onSave
    }

    private var validationMessage: String? { draft.validationMessage(existing: existing, today: today) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start date", selection: dayBinding(\.start), in: ...today.formattingDate, displayedComponents: .date)
                        .accessibilityIdentifier("periodStartDate")
                    Toggle("Add an end date, if known", isOn: $draft.includesEnd)
                        .accessibilityIdentifier("includeEndDate")
                    if draft.includesEnd {
                        DatePicker("End date", selection: dayBinding(\.end), in: ...today.formattingDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Leaving the end blank records the start only. It does not mean bleeding continued after that day.")
                }
                Section {
                    Picker("Overall flow (optional)", selection: $draft.flow) {
                        Text("Not recorded").tag(PeriodFlow?.none)
                        ForEach(PeriodFlow.allCases, id: \.self) { flow in
                            Text(flow.title).tag(PeriodFlow?.some(flow))
                        }
                    }
                    .accessibilityIdentifier("periodFlow")
                } footer: {
                    Text("Your summary for this period, not a daily measurement or medical assessment.")
                }
                Section("Private note (optional)") {
                    TextField("Add a note", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("periodNotes")
                    Text("\(draft.notes.count) / \(PeriodValidation.maximumNoteLength) characters")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = saveError ?? validationMessage {
                    Section {
                        InlineError(message: message).accessibilityFocused($errorFocused)
                    }
                }
                if isDraft {
                    Section { Text("This date joins your draft. Save the full list when you continue.").foregroundStyle(.secondary) }
                }
            }
            // Picker dates are UTC anchors for civil days, never actual event timestamps.
            .environment(\.calendar, LocalDay.calendar)
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle(isEditing ? "Edit period" : (isDraft ? "Previous period" : "Record a period"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if draft.hasChanges { confirmDiscard = true } else { dismiss() }
                    }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save changes" : (isDraft ? "Add to list" : "Record start")) {
                        isSaving = true
                        saveError = onSave(draft.period)
                        isSaving = false
                        if saveError == nil { dismiss() } else { errorFocused = true }
                    }
                    .disabled(validationMessage != nil || isSaving || (isEditing && !draft.hasChanges))
                    .accessibilityIdentifier("savePeriod")
                }
            }
            .interactiveDismissDisabled(draft.hasChanges || isSaving)
            .confirmationDialog("Discard these unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .onChange(of: draft.start) { _, _ in saveError = nil }
            .onChange(of: draft.end) { _, _ in saveError = nil }
            .onChange(of: draft.includesEnd) { _, _ in saveError = nil }
            .onChange(of: draft.flow) { _, _ in saveError = nil }
            .onChange(of: draft.notes) { _, _ in saveError = nil }
        }
    }

    private func dayBinding(_ keyPath: ReferenceWritableKeyPath<PeriodDraft, LocalDay>) -> Binding<Date> {
        Binding(get: { draft[keyPath: keyPath].formattingDate }, set: { value in
            if let day = try? LocalDay(date: value, timeZone: LocalDay.calendar.timeZone) { draft[keyPath: keyPath] = day }
        })
    }
}
