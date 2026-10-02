import SwiftUI

struct SexualActivityEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let original: SexualActivityEntry?
    private let initialDay: LocalDay
    private let entryID: UUID
    @State private var day: LocalDay
    @State private var activities: Set<SexualActivityKind>
    @State private var notes: String
    @State private var saveError: String?
    @State private var discard = false
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, day: LocalDay, entry: SexualActivityEntry? = nil) {
        self.session = session
        original = entry
        initialDay = entry?.day ?? day
        entryID = entry?.id ?? UUID()
        _day = State(initialValue: entry?.day ?? day)
        _activities = State(initialValue: entry?.activities ?? [])
        _notes = State(initialValue: entry?.notes ?? "")
    }

    private var changed: Bool {
        day != initialDay || activities != (original?.activities ?? []) || notes != (original?.notes ?? "")
    }
    private var entry: SexualActivityEntry {
        SexualActivityEntry(id: entryID, day: day, activities: activities, notes: notes,
                            createdAt: original?.createdAt ?? Date(), updatedAt: original?.updatedAt)
    }
    private var validation: String? {
        do {
            try SexualActivityValidation.validate(session.snapshot.sexualActivities.filter { $0.id != original?.id } + [entry], asOf: session.today)
            return nil
        } catch { return error.localizedDescription }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SelectionFlowLayout {
                        ForEach(SexualActivityKind.allCases, id: \.self) { kind in
                            SelectionChip(title: kind.title, symbol: "heart.fill", selected: activities.contains(kind),
                                          iconTint: TrackerPalette(scheme: colorScheme).sexualActivity) {
                                if activities.remove(kind) == nil { activities.insert(kind) }
                            }
                            .accessibilityIdentifier("sexualActivityKind_\(kind.rawValue)")
                        }
                    }
                } header: {
                    Text("Activities")
                } footer: {
                    Text("Choose all that apply. One record per day; you can edit it later to add or remove activities.")
                }
                Section {
                    DatePicker("Date", selection: Binding(get: { day.formattingDate }, set: {
                        if let value = try? LocalDay(date: $0, timeZone: .gmt) { day = value }
                    }), in: ...(session.today ?? initialDay).formattingDate, displayedComponents: .date)
                    .accessibilityIdentifier("sexualActivityDate")
                }
                Section("Private note (optional)") {
                    TextField("Add a note", text: $notes, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("sexualActivityNotes")
                    Text("\(notes.count) / 2,000 characters").font(.footnote)
                }
                Section {
                    Text("Stored on this device with your other private records. Sexual activity is not used for cycle predictions or pregnancy-risk estimates. Unlogged days are unknown, not days without activity.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = saveError ?? validation {
                    InlineError(message: message).accessibilityFocused($errorFocused)
                }
            }
            .trackerFormStyle()
            .environment(\.calendar, LocalDay.calendar)
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle(original == nil ? "Log sex" : "Edit sexual activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { if changed { discard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard validation == nil else { return }
                        saveError = session.saveSexualActivity(entry, editing: original != nil)
                        if saveError == nil { dismiss() } else { errorFocused = true }
                    }
                    .disabled(validation != nil || session.isSaving || (original != nil && !changed))
                    .accessibilityIdentifier("saveSexualActivity")
                }
            }
            .interactiveDismissDisabled(changed || session.isSaving)
            .alert("Discard unsaved changes?", isPresented: $discard) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .onChange(of: day) { _, _ in saveError = nil }
            .onChange(of: activities) { _, _ in saveError = nil }
            .onChange(of: notes) { _, _ in saveError = nil }
        }
    }
}

struct SexualActivityLogButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let day: LocalDay
    var compact = false
    @State private var showEntry = false

    var body: some View {
        Group {
            if compact {
                entryButton.buttonStyle(TrackerCompactLogButtonStyle())
            } else {
                entryButton.buttonStyle(.bordered)
            }
        }
        .accessibilityIdentifier("logSexualActivity")
        .sheet(isPresented: $showEntry) {
            SexualActivityEntryView(session: session, day: day,
                                    entry: session.snapshot.sexualActivities.first { $0.day == day })
        }
    }

    private var entryButton: some View {
        Button { showEntry = true } label: {
            Label { Text("Log sex") } icon: {
                Image(systemName: "heart.fill").foregroundStyle(TrackerPalette(scheme: colorScheme).sexualActivity)
            }
            .frame(maxWidth: compact ? nil : .infinity,
                   minHeight: compact ? nil : TrackerLayout.minimumTarget)
        }
    }
}

struct SexualActivityRecordView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: TrackerSession
    let entry: SexualActivityEntry
    @State private var editing = false
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecordHeader(title: "Sexual activity", date: DayText.full(entry.day), symbol: "heart.fill",
                         accent: TrackerPalette(scheme: colorScheme).sexualActivity)
            Text(entry.summary).font(.subheadline).accessibilityIdentifier("sexualActivitySummary_\(entry.day.key)")
            if let notes = entry.notes { DisclosureGroup("Private note") { Text(notes) }.font(.footnote) }
            Divider()
            let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 16))
            layout {
            Button("Edit activity") { editing = true }.frame(minHeight: 44)
                .accessibilityIdentifier("editSexualActivity_\(entry.day.key)")
            Button("Delete activity", role: .destructive) { deleting = true }.frame(minHeight: 44)
                .accessibilityIdentifier("deleteSexualActivity_\(entry.day.key)")
            }.font(.subheadline).buttonStyle(.bordered).buttonBorderShape(.capsule)
            if let error { InlineError(message: error) }
        }
        .sheet(isPresented: $editing) { SexualActivityEntryView(session: session, day: entry.day, entry: entry) }
        .alert("Delete this activity record?", isPresented: $deleting) {
            Button("Delete activity record", role: .destructive) { error = session.deleteSexualActivity(id: entry.id) }
            Button("Keep record", role: .cancel) { }
        } message: { Text("All activities and the private note for this day will be removed. This cannot be undone.") }
        .onChange(of: error) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
    }
}

struct SexualActivityHistoryView: View {
    let session: TrackerSession

    var body: some View {
        TrackerPage(title: "Sexual activity", subtitle: "Only what you choose to record.") {
            if let today = session.today { SexualActivityLogButton(session: session, day: today) }
            if session.snapshot.sexualActivities.isEmpty {
                Text("No sexual activity recorded yet.")
            }
            ForEach(session.snapshot.sexualActivities.reversed()) { entry in
                TrackerCard { SexualActivityRecordView(session: session, entry: entry) }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
