import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    enum Step: Int, CaseIterable {
        case welcome, about, measurements, gender, partners, cycle, history, symptoms, context, goals, notifications, review, apple
        var title: String {
            switch self {
            case .welcome: "Understand your cycle."
            case .about: "About you"
            case .measurements: "Height and weight"
            case .gender: "Your gender"
            case .partners: "Who do you have sex with?"
            case .cycle: "Cycle basics"
            case .history: "Add your last 4 periods"
            case .symptoms: "Common symptoms"
            case .context: "Cycle context"
            case .goals: "Your goals"
            case .notifications: "Your reminders"
            case .review: "Review your profile"
            case .apple: "Start tracking"
            }
        }
        var optional: Bool { [.measurements, .gender, .partners, .symptoms, .context, .goals, .notifications].contains(self) }
        var subtitle: String? {
            switch self {
            case .welcome: "A little understanding, day by day."
            case .about: "Let’s make Cecy feel like yours."
            case .measurements: "Optional details. Always yours to change."
            case .gender: "How do you describe your gender? You can skip this."
            case .partners: "Choose all that apply, or skip. This doesn’t define your orientation."
            case .cycle: "Tell us what’s usual for you."
            case .history: "Start with the most recent. Estimates are okay."
            case .symptoms: "What do you usually experience? Choose any that apply."
            case .context: "Does any of this apply right now?"
            case .goals: "What would you like Cecy to help with?"
            case .notifications: "A gentle nudge, only when you want it."
            case .review: "Take a quick look. You can change anything later."
            case .apple: nil
            }
        }
        var symbol: String {
            switch self {
            case .welcome: "leaf"
            case .about: "person.crop.circle"
            case .measurements: "ruler"
            case .gender: "person.crop.circle"
            case .partners: "person.2"
            case .cycle: "drop"
            case .history: "calendar"
            case .symptoms: "heart.text.square"
            case .context: "square.text.square"
            case .goals: "scope"
            case .notifications: "bell"
            case .review: "checkmark.circle"
            case .apple: "person.badge.key"
            }
        }
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
            if session.setupStage != nil {
                VStack(spacing: 20) {
                    ProgressView().controlSize(.large)
                        .accessibilityLabel("Creating your account")
                        .accessibilityIdentifier("setupStatus")
                    Text("Creating your account…").font(TrackerTypography.sectionTitle)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("creatingAccountMessage")
                }
                .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TrackerPalette(scheme: colorScheme).background)
            } else {
                OnboardingPage(title: step.title, subtitle: step.subtitle, symbol: step.symbol,
                               step: step.rawValue + 1, totalSteps: Step.allCases.count, optional: step.optional) {
                    fields
                }
                .id(step)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        if let error {
                            InlineError(message: error).font(.callout)
                                .fixedSize(horizontal: false, vertical: true).accessibilityFocused($errorFocused)
                        }
                        if step != .apple {
                            HStack(spacing: 16) {
                                if step.optional {
                                    Button("Skip") { skip(); advance() }.frame(minWidth: 44, minHeight: 44)
                                        .accessibilityIdentifier("onboardingSkip")
                                }
                                Button { advance() } label: {
                                     Text(editingReview ? "Back to review" : "Continue")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                    .buttonStyle(TrackerPrimaryButtonStyle()).accessibilityIdentifier("onboardingContinue")
                            }
                        }
                    }
                    .padding(.horizontal, TrackerLayout.pageInset).padding(.vertical, 12)
                    .background(TrackerPalette(scheme: colorScheme).background)
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
                Label("See your next estimated period window", systemImage: "calendar")
                Label("Keep track of symptoms and how you feel", systemImage: "heart.text.square")
                Label("Understand patterns in your own records", systemImage: "chart.xyaxis.line")
            }
        case .about:
            Section { ProfileBasicsFields(profile: $draft.profile, today: today) }
        case .measurements:
            Section { ProfileMeasurementFields(profile: $draft.profile) } footer: {
                Text("Both are optional. Neither is used to predict your next period.")
            }
        case .gender:
            Section { ProfileGenderFields(profile: $draft.profile) } footer: {
                Text("Stored only in your local profile. Not used for predictions or sent for insights.")
            }
        case .partners:
            Section { ProfilePartnerFields(profile: $draft.profile) } footer: {
                Text("Private profile information, not an activity log. Not used for predictions or sent for insights.")
            }
        case .cycle:
            Section { ProfileCycleFields(profile: $draft.profile) } footer: {
                Text("Your usual bleeding length—not the time between periods. Missing end dates stay blank.")
            }
        case .history:
            Section {
                Label("\(draft.periods.count) of 4 required starts added", systemImage: draft.periods.count >= 4 ? "checkmark.circle.fill" : "calendar.badge.plus")
                    .font(.headline).accessibilityIdentifier("onboardingPeriodCount")
                ForEach(draft.periods.sorted { $0.start > $1.start }) { period in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DayText.full(period.start)).font(.headline)
                        Text(period.end.map { "Ended \(DayText.full($0))" } ?? "End not recorded")
                            .font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Button("Edit") { editingPeriod = period }.buttonStyle(.borderless)
                                .accessibilityLabel("Edit period starting \(DayText.full(period.start))")
                            Spacer()
                            Button("Remove", role: .destructive) { draft.periods.removeAll { $0.id == period.id } }.buttonStyle(.borderless)
                                .accessibilityLabel("Remove period starting \(DayText.full(period.start))")
                        }.frame(minHeight: 44)
                    }
                }
                Button { editingPeriod = Period(start: today) } label: {
                    Label(draft.periods.count < 4 ? "Add a period" : "Add another period", systemImage: "plus").frame(minHeight: 44)
                }.accessibilityIdentifier("addOnboardingPeriod")
            } footer: {
                Text("End dates are optional.")
            }
        case .symptoms:
            Section {
                ProfileSymptomFields(profile: $draft.profile)
            } footer: {
                Text("Preferences only. This won’t add symptoms to your calendar.")
            }
        case .context:
            Section {
                ProfileContextFields(profile: $draft.profile)
            } footer: {
                Text("Optional context—not a diagnosis or prediction input.")
            }
        case .goals:
            Section {
                ProfileGoalFields(profile: $draft.profile)
            } footer: { Text("Choose as many as you like.") }
        case .notifications:
            Section {
                Toggle(isOn: $draft.dailyReminder) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily check-in")
                        Text("A moment to log periods or symptoms.").font(.caption).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("onboardingDailyReminder")
                Toggle(isOn: $draft.windowReminder) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before period window")
                        Text("One day before an eligible estimate.").font(.caption).foregroundStyle(.secondary)
                    }
                }.accessibilityIdentifier("onboardingWindowReminder")
                DatePicker("Local time", selection: reminderTime, displayedComponents: .hourAndMinute)
            } footer: {
                Text("Discreet notifications, without health details. If you enable one, iOS will ask permission during setup. You can decline.")
            }
        case .review:
            review
        case .apple:
            AppleSignInSection(session: session, profileID: draft.profile.id) {
                Task {
                    error = await session.finishSetup(draft, minimumPresentation: .milliseconds(1_200))
                    errorFocused = error != nil
                }
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
            LabeledContent("Gender", value: draft.profile.genderIdentity?.title ?? "Not answered")
            LabeledContent("Partners", value: summary(SexualPartnerPreference.allCases.filter { draft.profile.sexualPartners?.contains($0) == true }.map(\.title)))
            Text("Symptoms: " + summary(CommonSymptom.allCases.filter { draft.profile.commonSymptoms.contains($0) }.map(\.title)))
            Text("Goals: " + summary(TrackingGoal.allCases.filter { draft.profile.goals.contains($0) }.map(\.title)))
            Text("Reminder choices can be changed later in Settings.").font(.footnote).foregroundStyle(.secondary)
        }
        Section("Edit answers") {
            DisclosureGroup("Review or change an answer") {
            ForEach([Step.about, .measurements, .gender, .partners, .cycle, .history, .symptoms, .context, .goals, .notifications], id: \.rawValue) { target in
                Button(target.title) { editingReview = true; step = target; error = nil }
                    .frame(minHeight: 44)
            }
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
        case .gender: draft.profile.genderIdentity = nil
        case .partners: draft.profile.sexualPartners = nil
        case .symptoms: draft.profile.commonSymptoms = []
        case .context: draft.profile.cycleContext = []
        case .goals: draft.profile.goals = []
        case .notifications: draft.dailyReminder = false; draft.windowReminder = false
        default: break
        }
    }
}
