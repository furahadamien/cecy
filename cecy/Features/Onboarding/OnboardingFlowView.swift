import SwiftUI

struct OnboardingFlowView: View {
    enum Step: Int, CaseIterable {
        case welcome, about, measurements, cycle, history, symptoms, context, goals, notifications, review, apple
        var title: String {
            switch self {
            case .welcome: "Understand your cycle."
            case .about: "About you"
            case .measurements: "Height and weight"
            case .cycle: "Cycle basics"
            case .history: "Add your last 4 periods"
            case .symptoms: "Common symptoms"
            case .context: "Cycle context"
            case .goals: "Your goals"
            case .notifications: "Your reminders"
            case .review: "Review your profile"
            case .apple: "Save your Cecy profile"
            }
        }
        var optional: Bool { [.measurements, .symptoms, .context, .goals, .notifications].contains(self) }
    }

    let session: TrackerSession
    let today: LocalDay
    @State private var draft: OnboardingDraft
    @State private var step: Step
    @State private var editingReview = false
    @State private var editingPeriod: Period?
    @State private var error: String?
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, today: LocalDay) {
        self.session = session
        self.today = today
        var value = OnboardingDraft()
        value.profile = session.snapshot.profile ?? LocalProfile()
        value.periods = session.snapshot.periods
        value.dailyReminder = session.privacy.preferences.dailyReminder
        value.windowReminder = session.privacy.preferences.windowReminder
        value.reminderHour = session.privacy.preferences.reminderHour
        value.reminderMinute = session.privacy.preferences.reminderMinute
        _draft = State(initialValue: value)
        // A process interruption after the staged save resumes at review, not an empty form.
        _step = State(initialValue: session.snapshot.profile == nil ? .welcome : .review)
    }

    var body: some View {
        Group {
            if let stage = session.setupStage {
                VStack(spacing: 20) {
                    Text("Setting up Cecy").font(.largeTitle.weight(.semibold))
                    ProgressView(stage.rawValue).accessibilityIdentifier("setupStatus")
                    Text("Step 12 of 12").font(.subheadline).foregroundStyle(.secondary)
                    Text("Your health data stays on your device.").font(.footnote)
                }
                .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SettingsForm(title: step.title) {
                    Section {
                        ProgressView(value: Double(step.rawValue + 1), total: 12)
                            .accessibilityLabel("Onboarding progress")
                            .accessibilityValue("Step \(step.rawValue + 1) of 12")
                        Text("Step \(step.rawValue + 1) of 12\(step.optional ? " · Optional" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    fields
                    if let error { Section { InlineError(message: error).accessibilityFocused($errorFocused) } }
                }
                .id(step)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        if step != .apple {
                            HStack(spacing: 16) {
                                if step.optional {
                                    Button("Skip") { skip(); advance() }.frame(minWidth: 44, minHeight: 44)
                                        .accessibilityIdentifier("onboardingSkip")
                                }
                                Button(editingReview ? "Back to review" : "Continue") { advance() }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .buttonStyle(.borderedProminent).accessibilityIdentifier("onboardingContinue")
                            }
                        }
                        Label("Your health data stays on your device.", systemImage: "iphone")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal).padding(.vertical, 8).background(.regularMaterial)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if step != .welcome {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") {
                                step = editingReview ? .review : Step(rawValue: step.rawValue - 1) ?? .welcome
                                editingReview = false
                                error = nil
                            }.accessibilityIdentifier("onboardingBack")
                                .disabled(session.account.isSigningIn)
                        }
                    }
                }
                .sheet(item: $editingPeriod) { period in
                    OnboardingPeriodSheet(period: period, today: session.today ?? today, existing: draft.periods) { value in
                        draft.periods.removeAll { $0.id == value.id }
                        draft.periods.append(value)
                        error = nil
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    @ViewBuilder private var fields: some View {
        switch step {
        case .welcome:
            Section {
                Text("Track periods, symptoms, and patterns over time.")
                Text("Your health data stays on your device.").font(.headline)
                Text("No cloud backup yet. Deleting Cecy or losing this device can mean losing your records.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .about:
            Section { ProfileBasicsFields(profile: $draft.profile, today: today) }
        case .measurements:
            Section { ProfileMeasurementFields(profile: $draft.profile) } footer: {
                Text("Both are optional. Neither is used to predict your next period.")
            }
        case .cycle:
            Section { ProfileCycleFields(profile: $draft.profile) } footer: {
                Text("How long does bleeding usually last? This won’t fill in missing end dates.")
            }
        case .history:
            Section {
                Text("Estimates are okay. End dates are optional.")
                Text("\(draft.periods.count) periods added").accessibilityIdentifier("onboardingPeriodCount")
                ForEach(draft.periods.sorted { $0.start > $1.start }) { period in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DayText.full(period.start)).font(.headline)
                        Text(period.end.map { "Ended \(DayText.full($0))" } ?? "End not recorded")
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button("Edit") { editingPeriod = period }.buttonStyle(.borderless)
                            Spacer()
                            Button("Remove", role: .destructive) { draft.periods.removeAll { $0.id == period.id } }.buttonStyle(.borderless)
                        }.frame(minHeight: 44)
                    }
                }
                Button { editingPeriod = Period(start: today) } label: {
                    Label(draft.periods.count < 4 ? "Add a period" : "Add another period", systemImage: "plus").frame(minHeight: 44)
                }.accessibilityIdentifier("addOnboardingPeriod")
            } footer: {
                Text("Four starts give three cycle intervals. Start with the most recent, then work backward. Your dates stay in this draft until setup.")
            }
        case .symptoms:
            Section {
                Text("What do you usually experience?").font(.headline)
                ProfileSymptomFields(profile: $draft.profile)
            } footer: {
                Text("Choose any that apply. These are preferences, not recorded symptoms.")
            }
        case .context:
            Section {
                Text("Does any of this apply right now?").font(.headline)
                ProfileContextFields(profile: $draft.profile)
            } footer: {
                Text("Optional context—not a diagnosis or prediction input.")
            }
        case .goals:
            Section {
                Text("What do you want Cecy to help with?").font(.headline)
                ProfileGoalFields(profile: $draft.profile)
            } footer: { Text("Choose as many as you like.") }
        case .notifications:
            Section {
                Toggle("Daily check-in", isOn: $draft.dailyReminder).accessibilityIdentifier("onboardingDailyReminder")
                Toggle("Before period window", isOn: $draft.windowReminder).accessibilityIdentifier("onboardingWindowReminder")
                DatePicker("Local time", selection: reminderTime, displayedComponents: .hourAndMinute)
            } footer: {
                Text("A daily reminder to log periods or symptoms, and a reminder one day before an eligible prediction window. iOS permission is requested during setup only if you enable a reminder. You can decline.")
            }
        case .review:
            review
        case .apple:
            AppleSignInSection(session: session, profileID: draft.profile.id) {
                Task { error = await session.finishSetup(draft); errorFocused = error != nil }
            }
        }
    }

    @ViewBuilder private var review: some View {
        Section("Your cycle") {
            LabeledContent("Periods added", value: "\(draft.periods.count)")
            LabeledContent("Average cycle", value: draft.statistics(today: today)?.cycles.map { String(format: "%.1f days", $0.mean) } ?? "Not available")
            LabeledContent("Typical period", value: draft.profile.typicalPeriodDays.map { "\($0) days" } ?? "Not set")
            if let estimate = draft.overview(today: today).estimate {
                LabeledContent("Next start estimate", value: DayText.range(estimate.earliest, estimate.latest))
                LabeledContent("Confidence", value: estimate.confidence.rawValue)
            } else {
                Text("Your cycle history varies too much for an estimate right now. You can still finish setup and track records.")
            }
            Text("Estimates are not medical advice. Do not use for contraception, diagnosis or fertility planning.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        Section("Your preferences") {
            Text("Symptoms: " + summary(CommonSymptom.allCases.filter { draft.profile.commonSymptoms.contains($0) }.map(\.title)))
            Text("Goals: " + summary(TrackingGoal.allCases.filter { draft.profile.goals.contains($0) }.map(\.title)))
            Text("Reminder choices can be changed later in Settings.").font(.footnote).foregroundStyle(.secondary)
        }
        Section("Edit answers") {
            ForEach([Step.about, .measurements, .cycle, .history, .symptoms, .context, .goals, .notifications], id: \.rawValue) { target in
                Button(target.title) { editingReview = true; step = target; error = nil }
                    .frame(minHeight: 44)
            }
        }
    }

    private func summary(_ values: [String]) -> String { values.isEmpty ? "Not selected" : values.joined(separator: ", ") }
    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: draft.reminderHour, minute: draft.reminderMinute)) ?? Date()
        }, set: {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
            draft.reminderHour = parts.hour ?? 20
            draft.reminderMinute = parts.minute ?? 0
        })
    }
    private func advance() {
        do {
            let currentDay = session.today ?? today
            if step == .about || step == .measurements || step == .cycle { try draft.profile.validate(today: currentDay) }
            if step == .cycle && draft.profile.typicalPeriodDays == nil { throw ProfileError.duration }
            if step == .history {
                guard draft.periods.count >= 4 else { throw ProfileError.fourPeriods }
                try PeriodValidation.validate(draft.periods, asOf: currentDay)
            }
            if step == .review { try draft.validate(today: currentDay) }
            error = nil
            if editingReview { step = .review; editingReview = false }
            else { step = Step(rawValue: step.rawValue + 1) ?? .apple }
        } catch { self.error = error.localizedDescription; errorFocused = true }
    }
    private func skip() {
        switch step {
        case .measurements: draft.profile.heightCentimeters = nil; draft.profile.weightKilograms = nil
        case .symptoms: draft.profile.commonSymptoms = []
        case .context: draft.profile.cycleContext = []
        case .goals: draft.profile.goals = []
        case .notifications: draft.dailyReminder = false; draft.windowReminder = false
        default: break
        }
    }
}
