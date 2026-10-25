import SwiftUI

/// What Today should open after the pop-up closes, when an answer needs a full screen.
enum FollowUpHandoff: Equatable {
    case logPeriod(LocalDay)
    case checkIn
}

/// The half-height follow-up question shown on Today. One question at a time; every answer
/// saves through the same session APIs as Settings, and every question can be skipped or turned off.
struct FollowUpSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let prompt: FollowUpPrompt
    /// Called once the question is answered, skipped or turned off. `nil` means just close.
    let onFinish: (FollowUpHandoff?) -> Void

    @State private var selectedFactors: Set<CycleFactorKind> = []
    @State private var excludeFromForecast = false
    @State private var excludeTouched = false
    @State private var showingEndDate = false
    @State private var endDay: LocalDay
    @State private var editor: Editor?
    @State private var editorBaseline: TrackerSnapshot?
    @State private var saving = false
    @State private var saved: String?
    @State private var error: String?
    @State private var confirmTurnOff = false

    enum Editor: Identifiable {
        case factor(CycleFactor)
        case treatment(TreatmentRecord)
        case lifeStage(LifeStageEpisode)
        case biomarker(BiomarkerKind)
        var id: String {
            switch self {
            case .factor: "factor"
            case .treatment: "treatment"
            case .lifeStage: "lifeStage"
            case .biomarker: "biomarker"
            }
        }
    }

    init(session: TrackerSession, prompt: FollowUpPrompt, onFinish: @escaping (FollowUpHandoff?) -> Void) {
        self.session = session
        self.prompt = prompt
        self.onFinish = onFinish
        _endDay = State(initialValue: session.today ?? (try! LocalDay(key: 20010101)))
    }

    private var today: LocalDay { session.today ?? endDay }
    private var palette: TrackerPalette { TrackerPalette(scheme: colorScheme) }

    /// Each question type has its own color so the pop-up feels distinct but stays readable.
    private var tint: Color {
        switch prompt.kind {
        case .periodToday, .windowPassed: palette.recorded
        case .unusualCycle, .newCycle, .openFactor, .cycleContext: .orange
        case .treatmentDose, .treatmentReview: .indigo
        case .lifeStageReview: .teal
        case .biomarker: .blue
        case .dailyCheckIn: .pink
        }
    }

    private var symbol: String {
        switch prompt.kind {
        case .periodToday: "drop.fill"
        case .windowPassed: "calendar.badge.clock"
        case .unusualCycle: "arrow.left.and.right.circle.fill"
        case .newCycle: "sparkles"
        case .openFactor: "hourglass"
        case .treatmentDose: "pills.fill"
        case .treatmentReview: "cross.case.fill"
        case .lifeStageReview: "leaf.fill"
        case .biomarker: "thermometer.medium"
        case .cycleContext: "cloud.sun.fill"
        case .dailyCheckIn: "heart.text.square.fill"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let saved {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(palette.action, in: Circle())
                                .accessibilityHidden(true)
                            Text(saved).font(.headline).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.sage, in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("followUpSaved")
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    } else {
                        answers
                        if let error { InlineError(message: error) }
                        explainer
                        footer
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
                .animation(.snappy, value: saved)
            }
            .background(alignment: .top) {
                LinearGradient(colors: [tint.opacity(colorScheme == .dark ? 0.30 : 0.18), tint.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 260).ignoresSafeArea().accessibilityHidden(true)
            }
            .background(palette.background)
            .disabled(saving)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if saved == nil {
                        Button("Not now") { skip() }.accessibilityIdentifier("followUpNotNow")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // While saving or showing the confirmation, a swipe must not count as "Not now".
        .interactiveDismissDisabled(saving || saved != nil)
        .accessibilityIdentifier("followUpSheet")
        .sheet(item: $editor, onDismiss: editorClosed) { editor in
            switch editor {
            case .factor(let draft): CycleFactorEditorView(session: session, factor: nil, draft: draft)
            case .treatment(let value): TreatmentEditorView(session: session, treatment: value)
            case .lifeStage(let value): LifeStageEditor(session: session, episode: value)
            case .biomarker(let kind):
                BiomarkerEditor(session: session, entry: nil,
                                system: session.snapshot.profile?.measurementSystem ?? .metric, initialKind: kind)
            }
        }
        .confirmationDialog("Stop asking this type of question?", isPresented: $confirmTurnOff, titleVisibility: .visible) {
            Button("Don't ask about this") { turnOff() }
        } message: {
            Text("You can turn it back on in Settings → Check-in questions.")
        }
        .onAppear { AccessibilityNotification.Announcement(prompt.title).post() }
    }

    // MARK: Layout

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle())
                .shadow(color: tint.opacity(0.35), radius: 8, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick question")
                    .font(.caption.weight(.bold)).textCase(.uppercase).tracking(0.6)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
                    .accessibilityHidden(true)
                Text(prompt.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("followUpTitle")
                Text(prompt.message).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label { Text(prompt.explainer) } icon: { Image(systemName: "lightbulb.fill").foregroundStyle(tint) }
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Why am I seeing this?") {
                Text(prompt.reason).font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
            }
            .font(.footnote.weight(.semibold))
            .tint(tint)
            .accessibilityIdentifier("followUpWhy")
        }
        .padding(14)
        .background(tint.opacity(colorScheme == .dark ? 0.16 : 0.08),
                    in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
    }

    private var footer: some View {
        Button("Don't ask about this") { confirmTurnOff = true }
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget)
            .accessibilityIdentifier("followUpDontAsk")
    }

    // MARK: Answers

    @ViewBuilder private var answers: some View {
        switch prompt.context {
        case .periodStarted(let day):
            answerStack {
                answer("Yes, it started", symbol: "drop.fill", id: "started") { finish(.logPeriod(day)) }
                answer("Spotting only", symbol: "drop", id: "spotting") { saveBleeding(.spotting, day: day) }
                answer("No", symbol: "xmark", id: "no") { saveBleeding(.noBleeding, day: day) }
                answer("Not sure", symbol: "questionmark", id: "unsure") { saveBleeding(.unsure, day: day) }
            }
        case .periodContinuing(let day):
            answerStack {
                answer("Yes, still bleeding", symbol: "drop.fill", id: "bleeding") { finish(.checkIn) }
                answer("Spotting only", symbol: "drop", id: "spotting") { saveBleeding(.spotting, day: day) }
                answer("It's stopped", symbol: "checkmark", id: "stopped") { saveBleeding(.noBleeding, day: day) }
                answer("Not sure", symbol: "questionmark", id: "unsure") { saveBleeding(.unsure, day: day) }
            }
        case .windowPassed(_, let latestStart):
            answerStack {
                answer("My period started", symbol: "drop.fill", id: "started") { finish(.logPeriod(today)) }
                answer("Add a cycle factor", symbol: "timeline.selection", id: "factor") {
                    openEditor(.factor(CycleFactor(kind: .stress, start: latestStart ?? today)))
                }
                answer("Not yet", symbol: "clock", id: "notYet") { skip() }
            }
        case .unusualCycle(let interval, let usual):
            let longer = interval.length > usual
            let end = (try? interval.nextStart.adding(days: -1)) ?? interval.start
            factorChoices(longer ? [.illness, .stress, .travel, .possibleMissedRecord] : [.illness, .stress, .travel],
                          nothing: "Nothing I can think of",
                          build: { selectedFactors.sorted { $0.rawValue < $1.rawValue }.map {
                              CycleFactor(kind: $0, start: interval.start, end: end, excludesFromForecast: excludeFromForecast)
                          } },
                          other: { CycleFactor(kind: .stress, start: interval.start, end: end) })
        case .newCycle(let start):
            factorChoices([.illness, .stress, .travel], nothing: "Nothing new",
                          build: { selectedFactors.sorted { $0.rawValue < $1.rawValue }.map {
                              CycleFactor(kind: $0, start: start, excludesFromForecast: excludeFromForecast)
                          } },
                          other: { CycleFactor(kind: .stress, start: start) })
        case .openFactor(let factor):
            endChoices(stillLabel: "Still going", endLabel: "It ended", start: factor.start) {
                var value = factor
                value.end = endDay
                return await session.withPredictionUpdate { session.saveCycleFactor(value) }
            } more: { EmptyView() }
        case .treatmentDose(let treatment, let day):
            answerStack { doseAnswers(treatment, day: day) }
        case .treatmentReview(let treatment):
            let style = FollowUpEngine.reviewStyle(treatment)
            endChoices(stillLabel: style == .inPlace ? "Yes, still in place" : style == .taking ? "Yes, still taking it" : "Yes, still using it",
                       endLabel: style == .inPlace ? "It was removed" : "I stopped",
                       start: treatment.start) {
                var value = treatment
                value.end = endDay
                return await session.withPredictionUpdate { session.saveTreatment(value) }
            } more: {
                answer("Something changed…", symbol: "pencil", id: "edit") { openEditor(.treatment(treatment)) }
            }
        case .lifeStage(let episode):
            endChoices(stillLabel: "Yes", endLabel: "It ended", start: episode.start) {
                await session.withPredictionUpdate { session.endLifeStage(episode, on: endDay) }
            } more: {
                answer("Edit details…", symbol: "pencil", id: "edit") { openEditor(.lifeStage(episode)) }
            }
        case .biomarker(let kind):
            answerStack {
                answer("Add a reading", symbol: "plus.circle", id: "add") { openEditor(.biomarker(kind)) }
                answer("Not today", symbol: "clock", id: "notToday") { skip() }
            }
        case .cycleContext(let day):
            factorChoices([.illness, .stress, .travel], nothing: "Nothing right now", nothingIsWeekly: true,
                          build: { selectedFactors.sorted { $0.rawValue < $1.rawValue }.map {
                              CycleFactor(kind: $0, start: day, excludesFromForecast: excludeFromForecast)
                          } },
                          other: { CycleFactor(kind: .stress, start: day) })
        case .dailyCheckIn:
            answerStack {
                answer("Log how I'm feeling", symbol: "square.and.pencil", id: "checkIn") { finish(.checkIn) }
                answer("Nothing to log today", symbol: "checkmark", id: "nothing") {
                    session.resolveFollowUp(prompt)
                    show(String(localized: "Got it. Cecy won't ask again today."))
                }
            }
        }
    }

    private func answerStack<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
    }

    private func answer(_ title: LocalizedStringKey, symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(tint)
                    .frame(width: 34, height: 34).background(tint.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                Text(title).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(tint.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .font(.body.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget + 6, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1)
            }
            .shadow(color: tint.opacity(colorScheme == .dark ? 0 : 0.08), radius: 6, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("followUpAnswer.\(id)")
    }

    private func factorTitle(_ kind: CycleFactorKind) -> String {
        kind == .possibleMissedRecord ? String(localized: "I may have missed logging a period") : kind.title
    }

    /// Multi-select factor chips with an explicit Save, so several things can be noted at once.
    /// `nothingIsWeekly`: "nothing" restarts a weekly check instead of never asking again.
    private func factorChoices(_ options: [CycleFactorKind], nothing: LocalizedStringKey, nothingIsWeekly: Bool = false,
                               build: @escaping () -> [CycleFactor],
                               other: @escaping () -> CycleFactor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SelectionFlowLayout {
                ForEach(options, id: \.self) { kind in
                    SelectionChip(title: factorTitle(kind), selected: selectedFactors.contains(kind)) {
                        if selectedFactors.contains(kind) { selectedFactors.remove(kind) } else { selectedFactors.insert(kind) }
                        if !excludeTouched { excludeFromForecast = selectedFactors.contains { $0.defaultExcludesForecast } }
                    }
                    .accessibilityIdentifier("followUpFactor.\(kind.rawValue)")
                }
            }
            if !selectedFactors.isEmpty {
                Toggle("Leave this time out of my estimate", isOn: Binding(get: { excludeFromForecast }, set: {
                    excludeFromForecast = $0; excludeTouched = true
                }))
                .font(.subheadline)
                Button {
                    let factors = build()
                    Task {
                        await run(success: excludeFromForecast
                                  ? String(localized: "Saved. Cecy will leave this time out of your estimate.")
                                  : String(localized: "Saved. Your period records are unchanged.")) {
                            await session.withPredictionUpdate { session.saveCycleFactors(factors) }
                        }
                    }
                } label: { Text("Save").frame(maxWidth: .infinity) }
                .buttonStyle(TrackerPrimaryButtonStyle())
                .accessibilityIdentifier("followUpSave")
            }
            answer("Something else…", symbol: "plus.circle", id: "other") { openEditor(.factor(other())) }
            answer(nothing, symbol: "checkmark", id: "nothing") {
                if nothingIsWeekly {
                    session.confirmFollowUp(prompt)
                    show(String(localized: "Thanks. Cecy will check in again next week."))
                } else {
                    session.resolveFollowUp(prompt)
                    show(String(localized: "Got it. Cecy won't ask about this again."))
                }
            }
        }
    }

    /// Answers worded for the method: you take a pill, change a patch or ring, get a shot.
    @ViewBuilder private func doseAnswers(_ treatment: TreatmentRecord, day: LocalDay) -> some View {
        switch FollowUpEngine.doseStyle(treatment) ?? .take {
        case .take:
            answer("Taken", symbol: "checkmark.circle", id: "taken") { saveDose(treatment, day: day, state: .taken) }
            answer("Taken late", symbol: "clock", id: "late") { saveDose(treatment, day: day, state: .late) }
            answer("Skipped", symbol: "forward", id: "skipped") { saveDose(treatment, day: day, state: .skipped) }
        case .changePatch, .changeRing:
            answer("Yes, changed it", symbol: "checkmark.circle", id: "taken") { saveDose(treatment, day: day, state: .taken) }
            answer("Changed it late", symbol: "clock", id: "late") { saveDose(treatment, day: day, state: .late) }
            answer("Not this time", symbol: "forward", id: "skipped") { saveDose(treatment, day: day, state: .skipped) }
        case .shot:
            answer("Yes, I got it", symbol: "checkmark.circle", id: "taken") { saveDose(treatment, day: day, state: .taken) }
            // Leaves today unknown instead of recording a skip; Cecy never assumes a missed dose.
            answer("Not yet", symbol: "clock", id: "notYet") { skip() }
        case .use:
            answer("Yes", symbol: "checkmark.circle", id: "taken") { saveDose(treatment, day: day, state: .taken) }
            answer("Yes, but late", symbol: "clock", id: "late") { saveDose(treatment, day: day, state: .late) }
            answer("Skipped", symbol: "forward", id: "skipped") { saveDose(treatment, day: day, state: .skipped) }
        }
    }

    /// "Still going" confirms and waits before asking again; the end answer asks for the date.
    private func endChoices<More: View>(stillLabel: LocalizedStringKey, endLabel: LocalizedStringKey, start: LocalDay,
                                        save: @escaping () async -> String?, @ViewBuilder more: () -> More) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            answer(stillLabel, symbol: "arrow.clockwise", id: "still") {
                session.confirmFollowUp(prompt)
                show(String(localized: "Thanks. Cecy will check again later."))
            }
            if showingEndDate {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("Ended", selection: Binding(get: { endDay.formattingDate }, set: {
                        if let day = try? LocalDay(date: $0, timeZone: LocalDay.calendar.timeZone) { endDay = day }
                    }), in: start.formattingDate...today.formattingDate, displayedComponents: .date)
                    Button {
                        Task { await run(success: String(localized: "Updated.")) { await save() } }
                    } label: { Text("Save end date").frame(maxWidth: .infinity) }
                    .buttonStyle(TrackerPrimaryButtonStyle())
                    .accessibilityIdentifier("followUpSave")
                }
                .padding(14)
                .background(tint.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
            } else {
                answer(endLabel, symbol: "flag.checkered", id: "ended") { showingEndDate = true }
            }
            more()
        }
    }

    // MARK: Actions

    private func saveBleeding(_ state: DailyBleedingState, day: LocalDay) {
        Task {
            await run(success: String(localized: "Saved for today.")) {
                await session.withPredictionUpdate { session.saveDailyBleeding(DailyBleedingObservation(day: day, state: state)) }
            }
        }
    }

    private func saveDose(_ treatment: TreatmentRecord, day: LocalDay, state: AdherenceState) {
        Task {
            await run(success: String(localized: "Saved on this device.")) {
                session.saveTreatmentAdherence(TreatmentAdherence(treatmentID: treatment.id, day: day, state: state))
            }
        }
    }

    private func run(success: String, _ operation: () async -> String?) async {
        guard !saving else { return }
        saving = true
        error = nil
        let result = await operation()
        saving = false
        if let result { error = result; return }
        session.followUpAnswered(prompt)
        show(success)
    }

    /// Shows the confirmation briefly, then closes.
    private func show(_ message: String) {
        saved = message
        AccessibilityNotification.Announcement(message).post()
        Task {
            try? await Task.sleep(for: .milliseconds(1_400))
            finish(nil)
        }
    }

    private func skip() {
        session.snoozeFollowUp(prompt)
        finish(nil)
    }

    private func turnOff() {
        session.disableFollowUpKind(prompt.kind)
        finish(nil)
    }

    private func finish(_ handoff: FollowUpHandoff?) {
        if handoff != nil { session.followUpAnswered(prompt) }
        onFinish(handoff)
    }

    private func openEditor(_ value: Editor) {
        editorBaseline = session.snapshot
        editor = value
    }

    /// An editor that saved something counts as an answer; cancelling leaves the question open.
    private func editorClosed() {
        guard let baseline = editorBaseline else { return }
        editorBaseline = nil
        if session.snapshot != baseline {
            session.followUpAnswered(prompt)
            show(String(localized: "Saved."))
        }
    }
}
