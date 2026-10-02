import Observation
import SwiftUI

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
    @State private var addingBleeding = false
    @State private var entryKindChosen: Bool
    @AccessibilityFocusState private var errorFocused: Bool
    let today: LocalDay
    let existing: [Period]
    let isDraft: Bool
    let isEditing: Bool
    let continuation: Period?
    let newPeriod: Period
    let onSave: (Period) async -> String?

    init(period: Period, today: LocalDay, existing: [Period], isDraft: Bool = false,
         isEditing: Bool = false, continuation: Period? = nil, onSave: @escaping (Period) async -> String?) {
        _draft = State(initialValue: PeriodDraft(period: period))
        _entryKindChosen = State(initialValue: continuation == nil)
        self.continuation = continuation
        self.newPeriod = period
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
                if let continuation {
                    Section {
                        Text("Is this a new period or more bleeding days?").font(.headline)
                        SelectionFlowLayout {
                            SelectionChip(title: "New period", symbol: "calendar.badge.plus", selected: entryKindChosen && !addingBleeding) {
                                addingBleeding = false
                                entryKindChosen = true
                                draft = PeriodDraft(period: newPeriod)
                            }.accessibilityIdentifier("newPeriodEntry")
                            SelectionChip(title: "Add bleeding days", symbol: "drop.fill", selected: addingBleeding) {
                                addingBleeding = true
                                entryKindChosen = true
                                draft = PeriodDraft(period: continuation)
                                draft.end = newPeriod.start
                                draft.includesEnd = true
                            }.accessibilityIdentifier("continuePeriodEntry")
                        }
                        Text("Existing period started \(DayText.short(continuation.start)).")
                            .font(.footnote)
                    }
                }
                Section {
                    DatePicker("Start date", selection: dayBinding(\.start), in: ...today.formattingDate, displayedComponents: .date)
                        .accessibilityIdentifier("periodStartDate")
                    Toggle("Include confirmed bleeding days", isOn: $draft.includesEnd)
                        .accessibilityIdentifier("includeEndDate")
                    if draft.includesEnd {
                        DatePicker("Last bleeding day", selection: dayBinding(\.end), in: min(draft.start, today).formattingDate...today.formattingDate, displayedComponents: .date)
                            .accessibilityIdentifier("periodEndDate")
                        Text("\(draft.start.days(until: draft.end) + 1) confirmed bleeding day(s)")
                            .font(.footnote).accessibilityIdentifier("confirmedBleedingDays")
                    }
                } footer: {
                    Text("Include only days you actually bled, from the start through the last bleeding day. Turn this off if you only know the start. Future days cannot be logged.")
                }
                Section {
                    Text("Overall flow · Optional").font(.headline)
                    SelectionFlowLayout {
                        SelectionChip(title: "Not recorded", symbol: "minus.circle", selected: draft.flow == nil) { draft.flow = nil }
                            .accessibilityIdentifier("periodFlow_none")
                        ForEach(PeriodFlow.allCases, id: \.self) { flow in
                            SelectionChip(title: flow.title, symbol: flow.symbol, selected: draft.flow == flow) { draft.flow = flow }
                                .accessibilityIdentifier("periodFlow_\(flow.rawValue)")
                        }
                    }
                    .accessibilityElement(children: .contain)
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
            .trackerFormStyle()
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
                    Button(isEditing ? "Save changes" : (isDraft ? "Add to list" : addingBleeding ? "Save bleeding" : "Save period")) {
                        guard !isSaving else { return }
                        let period = draft.period
                        isSaving = true
                        Task {
                            saveError = await onSave(period)
                            isSaving = false
                            if saveError == nil { dismiss() } else { errorFocused = true }
                        }
                    }
                    .disabled(!entryKindChosen || validationMessage != nil || isSaving || (isEditing && !draft.hasChanges))
                    .accessibilityIdentifier("savePeriod")
                }
            }
            .interactiveDismissDisabled(draft.hasChanges || isSaving)
            .confirmationDialog("Discard these unsaved changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .onChange(of: draft.start) { _, start in
                if draft.end < start { draft.end = start }
                saveError = nil
            }
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
