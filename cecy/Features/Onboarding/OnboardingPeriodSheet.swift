import SwiftUI

struct OnboardingPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PeriodDraft
    let today: LocalDay
    let existing: [Period]
    let onSave: (Period) -> Void

    init(period: Period, today: LocalDay, existing: [Period], onSave: @escaping (Period) -> Void) {
        _draft = State(initialValue: PeriodDraft(period: period))
        self.today = today
        self.existing = existing
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Start date") {
                    DatePicker("Start date", selection: dayBinding(\.start), in: ...today.formattingDate, displayedComponents: .date)
                        .datePickerStyle(.wheel).labelsHidden().accessibilityIdentifier("onboardingStartPicker")
                }
                Section {
                    Toggle("I remember the end date", isOn: $draft.includesEnd)
                    if draft.includesEnd {
                        DatePicker("End date", selection: dayBinding(\.end), in: ...today.formattingDate, displayedComponents: .date)
                    }
                } footer: { Text("End date is optional. Estimates are okay.") }
                if let message = draft.validationMessage(existing: existing, today: today) {
                    Section { InlineError(message: message) }
                }
            }
            .trackerFormStyle()
            .environment(\.calendar, LocalDay.calendar)
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle("Period dates").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use dates") { onSave(draft.period); dismiss() }
                        .disabled(draft.validationMessage(existing: existing, today: today) != nil)
                        .accessibilityIdentifier("saveOnboardingPeriod")
                }
            }
        }
    }

    private func dayBinding(_ key: ReferenceWritableKeyPath<PeriodDraft, LocalDay>) -> Binding<Date> {
        Binding(get: { draft[keyPath: key].formattingDate }, set: {
            if let day = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) { draft[keyPath: key] = day }
        })
    }
}
