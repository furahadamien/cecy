import SwiftUI

struct PeriodRecordActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendarRecordStyle) private var calendarStyle
    let session: TrackerSession
    let period: Period
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var deletionReview: BleedingReconciliation?
    @State private var error: String?
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let layout = !calendarStyle && dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: calendarStyle ? 6 : 20))
            layout {
            Button { editing = true } label: { Label(calendarStyle ? "Edit" : "Edit period range", systemImage: "pencil") }
                .frame(minHeight: 44).accessibilityIdentifier("editPeriod")
                .accessibilityLabel("Edit period range")
                .accessibilityHint(period.end == nil ? "Edit details or add an end date." : "Edit recorded details.")
            Button(role: .destructive) {
                do {
                    deletionReview = try BleedingReconciliation.retainingDailyRecordsWhenDeleting(period.id, from: session.snapshot)
                    confirmDelete = true
                } catch { self.error = error.localizedDescription; errorFocused = true }
            } label: { Label(calendarStyle ? "Delete" : "Delete entire period", systemImage: "trash") }
                .frame(minHeight: 44).accessibilityIdentifier("deletePeriod")
                .accessibilityLabel("Delete entire period")
            }.buttonStyle(RecordActionButtonStyle())
            if let error { InlineError(message: error).accessibilityFocused($errorFocused) }
        }
        .disabled(session.isSaving)
        .sheet(isPresented: $editing) {
            if let current = session.snapshot.periods.first(where: { $0.id == period.id }), let today = session.today {
                PeriodEntryView(period: current, today: today, existing: session.snapshot.periods, isEditing: true, session: session) { period in
                    await session.withPredictionUpdate { session.update(period) }
                }
            }
        }
        .alert("Delete this period?", isPresented: $confirmDelete) {
            Button("Delete recorded period", role: .destructive) {
                Task {
                    guard let review = deletionReview else { return }
                    error = await session.withPredictionUpdate { session.reconcileBleeding(review) }
                    errorFocused = error != nil
                }
            }
            Button("Keep period", role: .cancel) { }
        } message: {
            Text("Remove the entire period \(DayText.range(period.start, period.end ?? period.start))—not just the selected day—including its flow and note. Daily answers stay saved without a period link. Cycle calculations may change. This cannot be undone.")
        }
    }
}

struct PeriodRecordSummary: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendarRecordStyle) private var calendarStyle
    let session: TrackerSession
    let period: Period
    var title = "Recorded period"

    var body: some View {
        let accent = TrackerPalette(scheme: colorScheme).recorded
        RecordedEntryCard(accent: accent) {
            if calendarStyle {
                CalendarRecordRow(actions: { periodActions }) {
                    VStack(alignment: .leading, spacing: 8) { details }
                }
            } else {
                details
                periodActions
            }
        }
    }

    private var periodActions: some View {
        PeriodRecordActions(session: session, period: period).id(period.id)
    }

    @ViewBuilder private var details: some View {
            let accent = TrackerPalette(scheme: colorScheme).recorded
            RecordHeader(title: title, date: period.end.map { DayText.range(period.start, $0) } ?? DayText.full(period.start),
                         symbol: "drop.fill", accent: accent)
            SelectionFlowLayout {
                RecordBadge(title: period.duration.map { "\($0) days · confirmed" } ?? "End not recorded",
                            symbol: period.end == nil ? "calendar.badge.questionmark" : "checkmark.circle", accent: accent)
                if let flow = period.flow { RecordBadge(title: flow.title + " flow", symbol: flow.symbol, accent: accent) }
            }
            if let note = period.notes { DisclosureGroup("Private note") { Text(note) }.font(.subheadline) }
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
