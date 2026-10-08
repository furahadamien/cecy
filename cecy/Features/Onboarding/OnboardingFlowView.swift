import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    enum Step: Int, CaseIterable {
        case welcome, about, measurements, gender, partners, history, cycle, cycleLength, symptoms, context, goals, notifications, review, apple
        var title: String {
            switch self {
            case .welcome: "Understand your cycle."
            case .about: "About you"
            case .measurements: "Height and weight"
            case .gender: "Your gender"
            case .partners: "Who do you have sex with?"
            case .cycle: "How long is your period?"
            case .cycleLength: "How long is your cycle?"
            case .history: "When did your last period start?"
            case .symptoms: "Common symptoms"
            case .context: "Cycle context"
            case .goals: "Your goals"
            case .notifications: "Your reminders"
            case .review: "Review your profile"
            case .apple: "Let's save your profile"
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
            case .cycle: "The number of days you usually bleed."
            case .cycleLength: "From the first day of one period to the first day of the next."
            case .history: "It’s OK if you don’t remember."
            case .symptoms: "What do you usually experience? Choose any that apply."
            case .context: "Does any of this apply right now?"
            case .goals: "What would you like Cecy to help with?"
            case .notifications: "Choose what to be reminded about and when."
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
            case .cycleLength: "arrow.triangle.2.circlepath"
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
        value.profile = session.snapshot.profile ?? value.profile
        value.periods = session.snapshot.periods
        value.dailyReminder = session.privacy.preferences.dailyReminder
        value.windowReminder = session.privacy.preferences.windowReminder
        value.reminderDetailsEnabled = session.privacy.preferences.reminderDetailsEnabled == true
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
                Group {
                    if step == .apple {
                        OnboardingApplePage(title: step.title, step: step.rawValue + 1,
                                            totalSteps: Step.allCases.count) {
                            fields
                        }
                    } else {
                        OnboardingPage(title: step.title, subtitle: step.subtitle, symbol: step.symbol,
                                       step: step.rawValue + 1, totalSteps: Step.allCases.count, optional: step.optional) {
                            fields
                        }
                    }
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
                                     Text(editingReview ? "Back to review" : step == .welcome ? "Get started" : "Continue")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                    .buttonStyle(TrackerPrimaryButtonStyle()).accessibilityIdentifier("onboardingContinue")
                            }
                        }
                    }
                    .padding(.horizontal, TrackerLayout.pageInset).padding(.vertical, 12)
                    .background(step == .apple ? Color(uiColor: .systemBackground) : TrackerPalette(scheme: colorScheme).background)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbar {
                    if step != .welcome {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back", action: goBack).accessibilityIdentifier("onboardingBack")
                                .disabled(session.account.isSigningIn)
                        }
                    }
                }
                .sheet(item: $editingPeriod) { period in
                    OnboardingPeriodSheet(period: period, today: session.today ?? today, existing: draft.periods) { value in
                        draft.periods.removeAll { $0.id == value.id }
                        draft.periods.append(value)
                        draft.profile.setUnknown(.lastStart, false)
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
            Section {
                OnboardingCycleLengthField(title: "Typical period length", range: CycleSetupPolicy.periodDays,
                    suggestedDays: CycleSetupPolicy.defaultPeriodDays, identifier: "onboardingPeriodLength",
                    value: $draft.profile.typicalPeriodDays, isUnknown: unknown(.periodLength))
            }
        case .cycleLength:
            Section {
                OnboardingCycleLengthField(title: "Typical cycle length", range: CycleSetupPolicy.cycleDays,
                    suggestedDays: CycleSetupPolicy.defaultCycleDays, identifier: "onboardingCycleLength",
                    value: $draft.profile.typicalCycleDays, isUnknown: unknown(.cycleLength))
            }
            Section { ProfilePredictabilityFields(profile: $draft.profile) }
        case .history:
            Section {
                if let latest = draft.periods.max(by: { $0.start < $1.start }) {
                    Label("Last period started", systemImage: "calendar.badge.checkmark").font(.subheadline)
                    Text(DayText.full(latest.start)).font(TrackerTypography.sectionTitle)
                        .accessibilityIdentifier("onboardingLastStart")
                } else if draft.profile.unknownCycleFields?.contains(.lastStart) != true {
                    Text("Choose the first day of your most recent period.").font(.title3.weight(.medium))
                }
                Button { editingPeriod = draft.periods.max(by: { $0.start < $1.start }) ?? Period(start: today) } label: {
                    Label(draft.periods.isEmpty ? "Choose start date" : "Change start date", systemImage: "calendar")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.accessibilityIdentifier("addOnboardingPeriod")
                if draft.periods.isEmpty {
                    SelectionChip(title: "I don’t remember", selected: draft.profile.unknownCycleFields?.contains(.lastStart) == true) {
                        draft.profile.setUnknown(.lastStart, true)
                        error = nil
                    }
                    .accessibilityIdentifier("onboardingLastStartUnknown")
                }
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
                    ReminderChoiceLabel(kind: .daily)
                }.accessibilityIdentifier("onboardingDailyReminder")
                Toggle(isOn: $draft.windowReminder) {
                    ReminderChoiceLabel(kind: .window)
                }.accessibilityIdentifier("onboardingWindowReminder")
                DatePicker("Reminder time", selection: reminderTime, displayedComponents: .hourAndMinute)
            } footer: {
                Text("Both use this local time. Period alerts need a future estimate. iOS permission is requested during setup only if you enable a reminder.")
            }
            if draft.dailyReminder || draft.windowReminder {
                Section {
                    ReminderMessageFields(daily: draft.dailyReminder, window: draft.windowReminder,
                                          showDetails: $draft.reminderDetailsEnabled)
                }
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
            LabeledContent("Typical cycle", value: draft.profile.typicalCycleDays.map { "\($0) days" } ?? "Not sure")
            LabeledContent("Typical period", value: draft.profile.typicalPeriodDays.map { "\($0) days" } ?? "Not sure")
            if let estimate = draft.overview(today: today).estimate {
                LabeledContent("Next start estimate", value: DayText.range(estimate.earliest, estimate.latest))
                LabeledContent("Confidence", value: estimate.confidence.rawValue)
                if let notice = estimate.starterNotice {
                    Text(notice)
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("starterEstimateNotice")
                }
            } else {
                Text("You can track without an estimate.")
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
            ForEach([Step.about, .measurements, .gender, .partners, .history, .cycle, .cycleLength, .symptoms, .context, .goals, .notifications], id: \.rawValue) { target in
                Button(target.title) { editingReview = true; step = target; error = nil }
                    .frame(minHeight: 44)
            }
            }
        }
    }

    private func unknown(_ field: CycleSetupField) -> Binding<Bool> {
        Binding(get: { draft.profile.unknownCycleFields?.contains(field) == true },
                set: { draft.profile.setUnknown(field, $0) })
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
    private func goBack() {
        step = editingReview ? .review : Step(rawValue: step.rawValue - 1) ?? .welcome
        editingReview = false
        error = nil
    }

    private func advance() {
        do {
            let currentDay = session.today ?? today
            if step == .about || step == .measurements || step == .cycleLength { try draft.profile.validate(today: currentDay) }
            if step == .cycle && draft.profile.typicalPeriodDays == nil && !unknown(.periodLength).wrappedValue { throw ProfileError.duration }
            if step == .cycleLength && draft.profile.typicalCycleDays == nil && !unknown(.cycleLength).wrappedValue { throw ProfileError.cycleLength }
            if step == .history {
                guard !draft.periods.isEmpty || unknown(.lastStart).wrappedValue else { throw ProfileError.lastPeriod }
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
        case .notifications:
            draft.dailyReminder = false
            draft.windowReminder = false
            draft.reminderDetailsEnabled = false
        default: break
        }
    }
}

private struct OnboardingApplePage<Content: View>: View {
    let title: String
    let step: Int
    let totalSteps: Int
    @ViewBuilder var content: Content
    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboardingHeading")
                        .accessibilityFocused($headingFocused)
                        .padding(.horizontal, 8)
                        .padding(.top, 36)

                    Text("Your records are stored on this device. Optional AI insights send selected information for online processing only with your consent.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.top, 12)
                        .accessibilityIdentifier("onboardingLocalProfileNote")

                    Spacer(minLength: 64)
                    content
                    Spacer(minLength: 64)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
        }
        .foregroundStyle(.primary)
        .background(Color(uiColor: .systemBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            ProgressView(value: Double(step), total: Double(totalSteps))
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step \(step) of \(totalSteps)")
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Color(uiColor: .systemBackground))
        }
        .navigationTitle("Cecy")
        .onAppear { headingFocused = true }
    }
}
