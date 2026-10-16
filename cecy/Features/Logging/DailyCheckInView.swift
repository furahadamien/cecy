import SwiftUI

struct DailyCheckInButton: View {
    let session: TrackerSession
    let day: LocalDay
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Label("Daily check-in", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle)
        .disabled(session.isSaving || session.today.map { day > $0 } != false)
        .accessibilityHint("Record bleeding, symptoms, mood, and energy in one place.")
        .accessibilityIdentifier("dailyCheckIn")
        .sheet(isPresented: $showing) { DailyCheckInView(session: session, day: day) }
    }
}

struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let day: LocalDay
    @State private var update: DailyCheckInUpdate
    @State private var saveError: String?
    @State private var confirmDiscard = false
    @State private var saving = false
    @State private var showingCustomization = false
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, day: LocalDay) {
        self.session = session
        self.day = day
        _update = State(initialValue: DailyCheckInUpdate(day: day, snapshot: session.snapshot))
    }

    private var suggested: [SymptomKind] {
        DailyCheckInSuggestions.symptoms(profile: session.snapshot.profile, existing: update.expectedSymptoms,
            recent: recentSymptoms, preferences: session.privacy.preferences.checkInPreferences,
            lifeStage: LifeStageCheckIn.symptoms(for: session.snapshot.p2, on: day))
    }

    private var recentSymptoms: [SymptomEntry] {
        guard let start = try? day.adding(days: -7) else { return [] }
        return session.snapshot.symptoms.filter { $0.day >= start && $0.day < day }
    }

    private var previousDay: LocalDay? { try? day.adding(days: -1) }
    private var hasPreviousAnswers: Bool {
        guard let previousDay else { return false }
        return session.snapshot.dailyBleeding.contains { $0.day == previousDay }
            || session.snapshot.symptoms.contains { $0.day == previousDay }
    }

    private var selectedKinds: [SymptomKind] {
        SymptomKind.allCases.filter { kind in update.symptoms.contains { $0.kind == kind } }
    }

    private var isInsideRecordedPeriod: Bool {
        session.snapshot.periods.contains { $0.contains(day) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(DayText.full(day)).font(.headline)
                    Text("A check-in records this day only. To start a period or change its dates, use Log period.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if hasPreviousAnswers, let previousDay {
                        Button {
                            update.copyAnswers(from: session.snapshot, previousDay: previousDay)
                        } label: {
                            Label("Review same as yesterday", systemImage: "arrow.uturn.forward.circle")
                        }
                        .accessibilityHint("Copies yesterday’s answers into this draft. Nothing is saved until you choose Save.")
                        .accessibilityIdentifier("sameAsYesterday")
                    }
                }

                Section {
                    bleedingChoice(nil)
                    ForEach(DailyBleedingState.allCases, id: \.self) { bleedingChoice($0) }
                    if update.bleeding?.state == .bleeding {
                        Text("Flow · Optional").font(.subheadline.weight(.semibold))
                        SelectionFlowLayout {
                            SelectionChip(title: "Not recorded", symbol: "minus.circle", selected: update.bleeding?.flow == nil) {
                                update.setBleeding(.bleeding)
                            }
                            ForEach(PeriodFlow.allCases, id: \.self) { choice in
                                SelectionChip(title: choice.title, symbol: choice.symbol, selected: update.bleeding?.flow == choice) {
                                    update.setBleeding(.bleeding, flow: choice)
                                }
                            }
                        }
                        .accessibilityIdentifier("checkInFlow")
                    }
                    if isInsideRecordedPeriod {
                        Text("Spotting and no bleeding can’t be saved inside confirmed period dates. Use Log period to correct those dates.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Bleeding today")
                } footer: {
                    Text("Skipping this question is different from recording no bleeding.")
                }

                let preferences = session.privacy.preferences.checkInPreferences ?? CheckInPreferences()
                if preferences.showSexualActivity || preferences.showTreatments {
                    Section("Other records") {
                        if preferences.showSexualActivity {
                            NavigationLink {
                                SexualActivityEntryView(session: session, day: day,
                                    entry: session.snapshot.sexualActivities.first { $0.day == day })
                            } label: { Label("Sexual activity", systemImage: "heart.circle") }
                        }
                        if preferences.showTreatments {
                            NavigationLink {
                                TreatmentCheckInView(session: session, day: day)
                            } label: { Label("Medication and contraception", systemImage: "pills") }
                        }
                        Text("These sensitive records open their own review and Save step. They are never inferred from an unselected choice.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    SelectionFlowLayout {
                        ForEach(suggested, id: \.self) { symptomChoice($0) }
                    }
                    if suggested.isEmpty {
                        Text("Choose from more symptoms below.").foregroundStyle(.secondary)
                    }
                } header: {
                    Text(session.snapshot.profile?.commonSymptoms.compactMap(\.symptomKind).isEmpty == false
                         ? "Your common symptoms" : "Common symptoms")
                } footer: {
                    Text("Your onboarding choices appear first. Not selecting a symptom does not mean it was absent.")
                }

                Section {
                    DisclosureGroup("More symptoms") {
                        ForEach(SymptomCategory.allCases, id: \.self) { category in
                            let choices = category.kinds.filter { !suggested.contains($0) }
                            if !choices.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label(category.rawValue, systemImage: category.symbol).font(.subheadline.weight(.semibold))
                                    SelectionFlowLayout {
                                        ForEach(choices, id: \.self) { symptomChoice($0) }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .accessibilityIdentifier("moreCheckInSymptoms")
                }

                if !selectedKinds.isEmpty {
                    Section("Optional ratings") {
                        ForEach(selectedKinds, id: \.self) { kind in
                            Picker(selection: rating(for: kind)) {
                                Text("Not rated").tag(Int?.none)
                                ForEach(1...3, id: \.self) { value in
                                    Text(kind.ratingLabels[value - 1]).tag(Int?.some(value))
                                }
                            } label: {
                                Label(kind.title, systemImage: kind.symbol)
                            }
                            .accessibilityIdentifier("checkInRating_\(kind.rawValue)")
                        }
                    }
                }

                if let saveError {
                    Section { InlineError(message: saveError).accessibilityFocused($errorFocused) }
                }
            }
            .trackerFormStyle()
            .navigationTitle(update.expectedBleeding == nil && update.expectedSymptoms.isEmpty ? "Daily check-in" : "Edit check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { update.hasChanges ? (confirmDiscard = true) : dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!update.hasAnswer || !update.hasChanges || saving || session.isSaving)
                        .accessibilityIdentifier("saveDailyCheckIn")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Customize check-in") { showingCustomization = true }
                }
            }
            .interactiveDismissDisabled(update.hasChanges || saving)
            .confirmationDialog("Discard this check-in?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .onChange(of: update) { _, _ in saveError = nil }
            .sheet(isPresented: $showingCustomization) {
                CheckInCustomizationView(privacy: session.privacy)
            }
        }
    }

    private func bleedingChoice(_ choice: DailyBleedingState?) -> some View {
        let selected = update.bleeding?.state == choice && (choice != nil || update.bleeding == nil)
        let conflicting = isInsideRecordedPeriod && (choice == .spotting || choice == .noBleeding)
        return Button {
            update.setBleeding(choice, flow: choice == .bleeding ? update.bleeding?.flow : nil)
        } label: {
            HStack {
                Label(choice?.title ?? "Skip bleeding question", systemImage: choice?.symbol ?? "forward")
                Spacer()
                if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .frame(minHeight: TrackerLayout.minimumTarget)
        }
        .disabled(conflicting)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier("checkInBleeding_\(choice?.rawValue ?? "skip")")
    }

    private func symptomChoice(_ kind: SymptomKind) -> some View {
        let selected = update.symptoms.contains { $0.kind == kind }
        return SelectionChip(title: kind.title, symbol: kind.symbol, selected: selected) {
            update.setSymptom(kind, selected: !selected)
        }
        .accessibilityIdentifier("checkInSymptom_\(kind.rawValue)")
    }

    private func rating(for kind: SymptomKind) -> Binding<Int?> {
        Binding(
            get: { update.symptoms.first(where: { $0.kind == kind })?.value },
            set: { update.setRating($0, for: kind) }
        )
    }

    private func save() {
        guard !saving else { return }
        saving = true
        Task {
            saveError = await session.withPredictionUpdate { session.saveDailyCheckIn(update) }
            saving = false
            if saveError == nil { dismiss() } else { errorFocused = true }
        }
    }
}

private struct CheckInCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    let privacy: TrackerPrivacy
    @State private var preferences: CheckInPreferences
    @State private var error: String?

    init(privacy: TrackerPrivacy) {
        self.privacy = privacy
        _preferences = State(initialValue: privacy.preferences.checkInPreferences ?? CheckInPreferences())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pinned symptoms") {
                    ForEach(preferences.pinnedSymptoms, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol)
                    }
                    .onMove { preferences.pinnedSymptoms.move(fromOffsets: $0, toOffset: $1) }
                    if preferences.pinnedSymptoms.isEmpty { Text("No pinned symptoms yet.").foregroundStyle(.secondary) }
                }
                Section {
                    ForEach(SymptomKind.allCases, id: \.self) { kind in
                        Toggle(isOn: pinBinding(kind)) { Label(kind.title, systemImage: kind.symbol) }
                    }
                } header: { Text("Choose favorites") }
                footer: { Text("Favorites appear first. Use Edit above to reorder them.") }
                Section("Hidden symptoms") {
                    ForEach(SymptomKind.allCases, id: \.self) { kind in
                        Toggle(kind.title, isOn: hiddenBinding(kind))
                    }
                }
                Section("Sensitive categories") {
                    Toggle("Sexual activity", isOn: $preferences.showSexualActivity)
                    Toggle("Medication and contraception", isOn: $preferences.showTreatments)
                    Text("Hiding a category changes only this check-in. Existing records and direct shortcuts remain available.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { InlineError(message: error) } }
            }
            .navigationTitle("Customize check-in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        error = privacy.setCheckInPreferences(preferences)
                        if error == nil { dismiss() }
                    }
                }
            }
        }
    }

    private func pinBinding(_ kind: SymptomKind) -> Binding<Bool> {
        Binding(get: { preferences.pinnedSymptoms.contains(kind) }, set: { selected in
            preferences.pinnedSymptoms.removeAll { $0 == kind }
            if selected { preferences.hiddenSymptoms.remove(kind); preferences.pinnedSymptoms.append(kind) }
        })
    }

    private func hiddenBinding(_ kind: SymptomKind) -> Binding<Bool> {
        Binding(get: { preferences.hiddenSymptoms.contains(kind) }, set: { hidden in
            if hidden { preferences.hiddenSymptoms.insert(kind); preferences.pinnedSymptoms.removeAll { $0 == kind } }
            else { preferences.hiddenSymptoms.remove(kind) }
        })
    }
}
