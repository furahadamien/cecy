import SwiftUI

struct CalendarSymptomGroup: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let day: LocalDay
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?

    private var entries: [SymptomEntry] {
        session.snapshot.symptoms.filter { $0.day == day }
    }

    var body: some View {
        if !entries.isEmpty {
            let palette = TrackerPalette(scheme: colorScheme)
            VStack(alignment: .leading, spacing: 12) {
                Text("Symptoms").font(.headline).accessibilityAddTraits(.isHeader)
                SelectionFlowLayout {
                    ForEach(entries) { entry in
                        Label(entry.kind.title, systemImage: entry.kind.symbol)
                            .font(.subheadline)
                            .foregroundStyle(palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(palette.sage, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(entry.ratingLabel ?? "Not rated")
                            .accessibilityIdentifier("calendarSymptom_\(entry.kind.rawValue)")
                    }
                }
                SelectionFlowLayout {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                        .frame(minHeight: 44)
                        .accessibilityLabel("Edit symptoms for \(DayText.full(day))")
                        .accessibilityIdentifier("editDaySymptoms")
                    Button(role: .destructive) { deleting = true } label: { Label("Delete", systemImage: "trash") }
                        .frame(minHeight: 44)
                        .accessibilityLabel("Delete all symptoms for \(DayText.full(day))")
                        .accessibilityIdentifier("deleteDaySymptoms")
                }
                .buttonStyle(RecordActionButtonStyle())
                .disabled(session.isSaving)
                if let error { InlineError(message: error) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("calendarDaySymptoms")
            .sheet(isPresented: $editing) { CalendarSymptomEditor(session: session, day: day) }
            .alert("Delete all symptoms for \(DayText.full(day))?", isPresented: $deleting) {
                Button("Delete all symptoms", role: .destructive) {
                    Task { error = await session.withPredictionUpdate { session.deleteSymptoms(on: day) } }
                }
                Button("Keep symptoms", role: .cancel) { }
            } message: {
                Text("This removes this day’s symptoms, ratings, and private notes. Periods, sexual activity, and other days are kept. This cannot be undone.")
            }
            .onChange(of: error) { _, message in
                if let message { AccessibilityNotification.Announcement(message).post() }
            }
        }
    }
}

private struct CalendarSymptomEditor: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let day: LocalDay
    @State private var selectedEntry: SymptomEntry?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(session.snapshot.symptoms.filter { $0.day == day }) { entry in
                        Button { selectedEntry = entry } label: {
                            HStack {
                                Label(entry.kind.title, systemImage: entry.kind.symbol)
                                Spacer()
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }.frame(minHeight: 44)
                        }
                        .accessibilityLabel("Edit \(entry.kind.title)")
                        .accessibilityIdentifier("chooseDaySymptom_\(entry.kind.rawValue)")
                    }
                } header: { Text(DayText.full(day)) }
                footer: { Text("Choose a symptom to edit its details, rating, or private note.") }
            }
            .trackerFormStyle()
            .navigationTitle("Edit symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selectedEntry) { entry in
                SymptomEntryView(session: session, day: day, entry: entry)
            }
        }
    }
}