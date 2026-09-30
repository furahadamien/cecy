import SwiftUI

struct HistoryEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let today: LocalDay
    var isOnboarding = true
    @State private var drafts: [Period] = []
    @State private var editing: Period?
    @State private var error: String?
    @State private var confirmDiscard = false
    @AccessibilityFocusState private var errorFocused: Bool

    var body: some View {
        TrackerPage(title: isOnboarding ? "A clearer view of your cycle" : "Add previous periods",
                    subtitle: "Start with dates you remember. No account needed.") {
            DisclosureGroup("About your privacy") { PrivacyDetails().padding(.top, 8) }
            TrackerCard {
                Text("Previous period starts").font(.headline).accessibilityAddTraits(.isHeader)
                Text("Add the first day of each period. Four recorded starts allow an initial estimate. You can start with fewer.")
                    .foregroundStyle(.secondary)
                ForEach(drafts.sorted { $0.start < $1.start }) { period in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DayText.full(period.start)).font(.headline)
                        Text(period.end.map { "Ends \(DayText.full($0))" } ?? "End not recorded")
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button("Edit") { editing = period }.frame(minWidth: 44, minHeight: 44)
                            Button("Remove", role: .destructive) { drafts.removeAll { $0.id == period.id }; error = nil }
                                .frame(minHeight: 44)
                        }
                        Divider()
                    }
                }
                Button {
                    editing = Period(start: today)
                } label: {
                    Label("Add a previous period", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("addHistoryDate")
                Text("Dates in this list are not saved until you continue.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let error { InlineError(message: error).accessibilityFocused($errorFocused) }
            Button {
                error = session.save(drafts, completingOnboarding: isOnboarding)
                if error == nil {
                    drafts = []
                    if !isOnboarding { dismiss() }
                } else { errorFocused = true }
            } label: {
                Text(drafts.isEmpty && isOnboarding ? "Continue without history" : "Save and continue")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.isSaving || (!isOnboarding && drafts.isEmpty))
            .accessibilityIdentifier("finishHistory")
            Text("Predictions are rough estimates, not medical advice or contraceptive guidance. You can correct saved entries later from Calendar or Insights.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .toolbar {
            if !isOnboarding {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if drafts.isEmpty { dismiss() } else { confirmDiscard = true } }
                }
            }
        }
        .sheet(item: $editing) { period in
            PeriodEntryView(period: period, today: session.today ?? today,
                            existing: session.snapshot.periods + drafts, isDraft: true) { result in
                drafts.removeAll { $0.id == result.id }
                drafts.append(result)
                error = nil
                return nil
            }
        }
        .interactiveDismissDisabled(!drafts.isEmpty || session.isSaving)
        .confirmationDialog("Discard your unsaved dates?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard dates", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        }
    }
}
