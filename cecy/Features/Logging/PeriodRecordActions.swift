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
            }.font(.subheadline).buttonStyle(.bordered).buttonBorderShape(.capsule)
            if let error { InlineError(message: error).accessibilityFocused($errorFocused) }
        }
        .disabled(session.isSaving)
        .sheet(isPresented: $editing) {
            if let current = session.snapshot.periods.first(where: { $0.id == period.id }), let today = session.today {
                PeriodEntryView(period: current, today: today, existing: session.snapshot.periods, isEditing: true) { period in
                    await session.withPredictionUpdate { session.update(period) }
                }
            }
        }
        .alert("Delete this period?", isPresented: $confirmDelete) {
            Button("Delete recorded period", role: .destructive) {
                Task {
                    error = await session.withPredictionUpdate { session.delete(id: period.id) }
                    errorFocused = error != nil
                }
            }
            Button("Keep period", role: .cancel) { }
        } message: {
            Text("The period starting \(DayText.full(period.start)), including its flow and note, will be removed. Cycle calculations will change. This cannot be undone.")
        }
    }
}

struct PeriodRecordSummary: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let period: Period
    var title = "Recorded period"

    var body: some View {
        let accent = TrackerPalette(scheme: colorScheme).recorded
        VStack(alignment: .leading, spacing: 12) {
            RecordHeader(title: title, date: period.end.map { DayText.range(period.start, $0) } ?? DayText.full(period.start),
                         symbol: "drop.fill", accent: accent)
            SelectionFlowLayout {
                RecordBadge(title: period.duration.map { "\($0) days · confirmed" } ?? "End not recorded",
                            symbol: period.end == nil ? "calendar.badge.questionmark" : "checkmark.circle", accent: accent)
                if let flow = period.flow { RecordBadge(title: flow.title + " flow", symbol: flow.symbol, accent: accent) }
            }
            if let note = period.notes { DisclosureGroup("Private note") { Text(note) }.font(.subheadline) }
            Divider()
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
