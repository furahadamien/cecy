import SwiftUI

struct PeriodRecordActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: TrackerSession
    let period: Period
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var error: String?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 20))
            layout {
            Button { editing = true } label: { Label("Edit period", systemImage: "pencil") }
                .frame(minHeight: 44).accessibilityIdentifier("editPeriod")
                .accessibilityHint(period.end == nil ? "Edit details or add an end date." : "Edit recorded details.")
            Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                .frame(minHeight: 44).accessibilityIdentifier("deletePeriod")
                .accessibilityLabel("Delete period")
            }.font(.subheadline)
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

struct PeriodRecordSummary: View {
    let session: TrackerSession
    let period: Period
    var title = "Recorded period"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "drop.fill").font(.subheadline.weight(.semibold))
            Text(DayText.short(period.start)).font(.headline)
            Text(period.end.map { "To \(DayText.short($0)) · \(period.duration ?? 0) days" } ?? "End not recorded")
                .font(.footnote).foregroundStyle(.secondary)
            PeriodExtraDetails(period: period).font(.footnote)
            PeriodRecordActions(session: session, period: period).id(period.id)
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
