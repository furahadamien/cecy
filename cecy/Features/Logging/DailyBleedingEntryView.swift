import SwiftUI

struct DailyBleedingLogButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let day: LocalDay
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Label("Other bleeding", systemImage: "drop.circle.fill")
                .foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
        }
            .buttonStyle(TrackerCompactLogButtonStyle())
            .accessibilityHint("Record spotting or a daily bleeding check-in. Does not start a cycle.")
            .accessibilityIdentifier("logDailyBleeding")
            .disabled(session.isSaving || session.today.map { day > $0 } != false)
            .sheet(isPresented: $showing) { DailyBleedingEntryView(session: session, day: day) }
    }
}

struct DailyBleedingEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let day: LocalDay
    private let original: DailyBleedingObservation?
    private let answerID: UUID
    @State private var state: DailyBleedingState?
    @State private var flow: PeriodFlow?
    @State private var periodID: UUID?
    @State private var review: BleedingReconciliation
    @State private var correcting: Period?
    @State private var error: String?
    @State private var confirmSave = false
    @State private var confirmDiscard = false
    @State private var saving = false
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, day: LocalDay) {
        self.session = session
        self.day = day
        let original = session.snapshot.dailyBleeding.first { $0.day == day }
        self.original = original
        answerID = original?.id ?? UUID()
        _state = State(initialValue: original?.state)
        _flow = State(initialValue: original?.flow)
        _periodID = State(initialValue: original?.periodID)
        _review = State(initialValue: BleedingReconciliation(snapshot: session.snapshot))
    }

    private var changed: Bool {
        state != original?.state || flow != original?.flow || periodID != original?.periodID || !review.changedPeriods.isEmpty
    }

    private var proposed: BleedingReconciliation? {
        guard let state else { return nil }
        var value = review
        var answer = original ?? DailyBleedingObservation(id: answerID, day: day, state: state)
        answer.state = state
        answer.flow = state == .bleeding ? flow : nil
        answer.periodID = state == .bleeding ? periodID : nil
        value.observations.removeAll { $0.id == answerID }
        value.observations.append(answer)
        return value
    }

    private var conflictingPeriod: Period? {
        guard state == .spotting || state == .noBleeding else { return nil }
        return review.periods.first { $0.contains(day) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(DayText.full(day)).font(.headline)
                    Text("Log spotting or a daily check-in. To start a cycle or change period dates, use Period.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(DailyBleedingState.allCases, id: \.self) { choice in
                        Button {
                            state = choice
                            if choice != .bleeding { flow = nil; periodID = nil }
                            error = nil
                        } label: {
                            HStack {
                                Label(choice.title, systemImage: choice.symbol)
                                Spacer()
                                if state == choice { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }.frame(minHeight: 44)
                        }
                        .accessibilityValue(state == choice ? "Selected" : "Not selected")
                        .accessibilityIdentifier("dailyState_\(choice.rawValue)")
                    }
                } footer: { Text("One day's answer. Does not start a period.") }
                if state == .bleeding {
                    Section {
                        Text("Flow · Optional").font(.headline)
                        SelectionFlowLayout {
                            SelectionChip(title: "Not recorded", symbol: "minus.circle", selected: flow == nil) { flow = nil }
                                .accessibilityIdentifier("dailyFlow_none")
                            ForEach(PeriodFlow.allCases, id: \.self) { choice in
                                SelectionChip(title: choice.title, symbol: choice.symbol, selected: flow == choice) { flow = choice }
                                    .accessibilityIdentifier("dailyFlow_\(choice.rawValue)")
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("dailyFlow")
                        if let period = review.periods.first(where: { $0.contains(day) }) {
                            Toggle("Link to period starting \(DayText.short(period.start))", isOn: Binding(
                                get: { periodID == period.id }, set: { periodID = $0 ? period.id : nil }))
                                .accessibilityIdentifier("dailyPeriodLink")
                        }
                    }
                }
                if let period = conflictingPeriod {
                    Section {
                        Text("This day is in a recorded period.")
                        Button("Correct period dates") { correcting = period }
                            .accessibilityIdentifier("correctDailyPeriod")
                    } footer: { Text("Review the dates, or keep the existing record.") }
                }
                if !review.changedPeriods.isEmpty {
                    Section("Pending changes") {
                        ForEach(review.changedPeriods) { period in
                            Text(periodChangeText(period))
                        }
                        if let count = proposed?.detachedAnswers.count, count > 0 {
                            Text("\(count) daily answers kept without a period link.").font(.footnote)
                        }
                    }
                }
                if let error { Section { InlineError(message: error).accessibilityFocused($errorFocused) } }
            }
            .trackerFormStyle()
            .navigationTitle(original == nil ? "Daily bleeding" : "Edit daily answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { confirmDiscard = true } else { dismiss() } }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(review.changedPeriods.isEmpty ? "Save" : "Review changes") {
                        if review.changedPeriods.isEmpty { save() } else { confirmSave = true }
                    }
                    .accessibilityIdentifier("saveDailyBleeding")
                    .disabled(state == nil || conflictingPeriod != nil || saving || session.isSaving || (original != nil && !changed))
                }
            }
            .interactiveDismissDisabled(changed || saving)
            .confirmationDialog("Discard this draft?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .alert("Save reviewed changes?", isPresented: $confirmSave) {
                Button("Save changes") { save() }
                Button("Keep editing", role: .cancel) { }
            } message: {
                Text(review.changedPeriods.map { periodChangeText($0) }.joined(separator: "\n")
                     + "\nDaily answer: \(state?.title ?? "Not selected")."
                     + ((proposed?.detachedAnswers.isEmpty == false) ? "\nAffected daily answers stay saved without a period link." : ""))
            }
            .sheet(item: $correcting) { period in
                if let today = session.today {
                    PeriodEntryView(period: period, today: today, existing: review.periods, isEditing: true) { corrected in
                        review.replacePeriod(corrected)
                        if periodID == corrected.id && !corrected.contains(day) { periodID = nil }
                        error = nil
                        return nil
                    }
                }
            }
        }
    }

    private func periodChangeText(_ period: Period) -> String {
        if let end = period.end { return "Period: \(DayText.range(period.start, end))" }
        return "Period start: \(DayText.full(period.start)) · End not recorded"
    }

    private func save() {
        guard !saving, let proposed else { return }
        saving = true
        Task {
            error = await session.withPredictionUpdate { session.reconcileBleeding(proposed) }
            saving = false
            if error == nil { dismiss() } else { errorFocused = true }
        }
    }
}

struct DailyBleedingRecordView: View {
    let session: TrackerSession
    let observation: DailyBleedingObservation
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(observation.state.title, systemImage: observation.state.symbol).font(.headline)
                .accessibilityIdentifier("dailyAnswer_\(observation.day.key)")
            if let flow = observation.flow { Text("\(flow.title) flow").font(.subheadline) }
            if observation.periodID != nil { Text("Linked to recorded period").font(.caption).foregroundStyle(.secondary) }
            SelectionFlowLayout {
                Button("Edit daily answer") { editing = true }.accessibilityIdentifier("editDailyBleeding")
                Button("Delete daily answer", role: .destructive) { deleting = true }.accessibilityIdentifier("deleteDailyBleeding")
            }.buttonStyle(RecordActionButtonStyle()).disabled(session.isSaving)
            if let error { InlineError(message: error) }
        }
        .sheet(isPresented: $editing) { DailyBleedingEntryView(session: session, day: observation.day) }
        .alert("Delete this daily answer?", isPresented: $deleting) {
            Button("Delete answer", role: .destructive) { error = session.deleteDailyBleeding(id: observation.id) }
            Button("Keep answer", role: .cancel) { }
        } message: { Text("Period dates and other records stay unchanged.") }
    }
}
