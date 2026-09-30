import SwiftUI

struct PeriodRecordActions: View {
    let session: TrackerSession
    let period: Period
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var error: String?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(period.end == nil ? "Edit period / add end date" : "Edit period") { editing = true }
                .frame(minHeight: 44).accessibilityIdentifier("editPeriod")
            Button("Delete period", role: .destructive) { confirmDelete = true }
                .frame(minHeight: 44).accessibilityIdentifier("deletePeriod")
            if let error { InlineError(message: error).accessibilityFocused($errorFocused) }
        }
        .disabled(session.isSaving)
        .sheet(isPresented: $editing) {
            if let current = session.snapshot.periods.first(where: { $0.id == period.id }), let today = session.today {
                PeriodEntryView(period: current, today: today, existing: session.snapshot.periods, isEditing: true) {
                    session.update($0)
                }
            }
        }
        .alert("Delete this period?", isPresented: $confirmDelete) {
            Button("Delete recorded period", role: .destructive) {
                error = session.delete(id: period.id)
                errorFocused = error != nil
            }
            Button("Keep period", role: .cancel) { }
        } message: {
            Text("The period starting \(DayText.full(period.start)), including its flow and note, will be removed. Cycle calculations will change. This cannot be undone.")
        }
    }
}

struct PeriodExtraDetails: View {
    let period: Period
    var body: some View {
        if let flow = period.flow { Text("Overall flow: \(flow.title)") }
        if let notes = period.notes {
            DisclosureGroup("Private note") { Text(notes).frame(maxWidth: .infinity, alignment: .leading) }
        }
    }
}
