import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    enum Step: Int, CaseIterable {
        case welcome, about, history, cycle, cycleLength, preview, review, apple
        var title: String {
            switch self {
            case .welcome: "Understand your cycle."
            case .about: "About you"
            case .cycle: "How long is your period?"
            case .cycleLength: "How long is your cycle?"
            case .history: "When did your last period start?"
            case .preview: "Your Today view"
            case .review: "Review your profile"
            case .apple: "Let's save your profile"
            }
        }
        var optional: Bool { false }
        var subtitle: String? {
            switch self {
            case .welcome: "A little understanding, day by day."
            case .about: "Let’s make Cecy feel like yours."
            case .cycle: "The number of days you usually bleed."
            case .cycleLength: "From the first day of one period to the first day of the next."
            case .history: "It’s OK if you don’t remember."
            case .preview: "You can start tracking now and personalize Cecy later."
            case .review: "Take a quick look. You can change anything later."
            case .apple: nil
            }
        }
        var symbol: String {
            switch self {
            case .welcome: "leaf.fill"
            case .about: "person.crop.circle.fill"
            case .cycle: "drop.fill"
            case .cycleLength: "arrow.triangle.2.circlepath"
            case .history: "calendar"
            case .preview: "sun.max.fill"
            case .review: "checkmark.seal.fill"
            case .apple: "lock.shield.fill"
            }
        }
    }

    let session: TrackerSession
    let today: LocalDay
    @State private var draft: OnboardingDraft
    @State private var step: Step
    /// Direction of the last navigation, so pages slide the way the user is moving.
    @State private var forward = true
    @State private var editingReview = false
    @State private var editingPeriod: Period?
    @State private var error: String?
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, today: LocalDay) {
        self.session = session
        self.today = today
        var value = session.snapshot.onboardingProgress?.draft ?? OnboardingDraft()
        value.profile = session.snapshot.profile ?? value.profile
        if session.snapshot.onboardingProgress == nil { value.periods = session.snapshot.periods }
        value.dailyReminder = session.privacy.preferences.dailyReminder
        value.windowReminder = session.privacy.preferences.windowReminder
        value.reminderDetailsEnabled = session.privacy.preferences.reminderDetailsEnabled == true
        value.reminderHour = session.privacy.preferences.reminderHour
        value.reminderMinute = session.privacy.preferences.reminderMinute
        _draft = State(initialValue: value)
        // A process interruption after the staged save resumes at review, not an empty form.
        let resumed = session.snapshot.onboardingProgress.flatMap { Int($0.stepID) }.flatMap(Step.init(rawValue:))
        _step = State(initialValue: resumed ?? (session.snapshot.profile == nil ? .welcome : .review))
    }

    private var palette: TrackerPalette { TrackerPalette(scheme: colorScheme, contrast: contrast) }

    var body: some View {
        Group {
            if session.setupStage != nil {
                creatingAccount
            } else {
                ZStack {
                    OnboardingPage(title: step.title, subtitle: step.subtitle, accent: step.accent, symbol: step.symbol,
                                   step: step.rawValue + 1, totalSteps: Step.allCases.count, optional: step.optional,
                                   hero: step == .welcome) {
                        fields
                    }
                    .id(step)
                    .transition(pageTransition)
                }
                .safeAreaInset(edge: .bottom) { bottomBar }
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
                .sensoryFeedback(.selection, trigger: step)
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

    private var creatingAccount: some View {
        let theme = Step.welcome.theme(palette)
        return VStack(spacing: 20) {
            OnboardingSymbolBadge(theme: theme, pulses: true)
            ProgressView().controlSize(.large).tint(theme.tint)
                .accessibilityLabel("Creating your account")
                .accessibilityIdentifier("setupStatus")
            Text("Creating your account…").font(TrackerTypography.sectionTitle)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("creatingAccountMessage")
        }
        .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { OnboardingBackdrop(theme: theme, hero: true) }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let error {
                InlineError(message: error).font(.callout)
                    .fixedSize(horizontal: false, vertical: true).accessibilityFocused($errorFocused)
            }
            if step == .apple {
                // Pinned like the other steps' primary action; the button keeps Apple's black/white style.
                AppleSignInSection(session: session, profileID: draft.profile.id) {
                    Task {
                        error = await session.finishSetup(draft, minimumPresentation: .milliseconds(1_200))
                        errorFocused = error != nil
                    }
                }
            } else {
                Button { advance() } label: {
                    Text(editingReview ? "Back to review" : step == .welcome ? "Get started" : "Continue")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(TrackerPrimaryButtonStyle()).accessibilityIdentifier("onboardingContinue")
            }
        }
        .padding(.horizontal, TrackerLayout.pageInset).padding(.vertical, 12)
        .background(palette.background.ignoresSafeArea(edges: .bottom))
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                           removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    @ViewBuilder private var fields: some View {
        switch step {
        case .welcome:
            welcome
        case .about:
            Section { ProfileBasicsFields(profile: $draft.profile, today: today) }
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
            history
        case .preview:
            preview
        case .review:
            review
        case .apple:
            Section {
                OnboardingIconRow(symbol: "lock.fill", tint: palette.accent) {
                    Text("Your records are stored on this device. Optional AI insights send selected information for online processing only with your consent.")
                        .accessibilityIdentifier("onboardingLocalProfileNote")
                }
                OnboardingIconRow(symbol: "heart.fill", tint: palette.recorded) {
                    Text("Apple Health import is optional and read-only.")
                }
                OnboardingIconRow(symbol: "icloud.slash", tint: palette.lavender) {
                    Text("No health-data cloud sync or analytics.")
                }
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder private var welcome: some View {
        Section {
            VStack(spacing: 12) {
                OnboardingFeatureCard(accent: .rose, symbol: "calendar", title: "Know what’s coming",
                                      detail: "See your next estimated period window").onboardingStagger(1)
                OnboardingFeatureCard(accent: .apricot, symbol: "heart.text.square.fill", title: "Track how you feel",
                                      detail: "Keep track of symptoms and how you feel").onboardingStagger(2)
                OnboardingFeatureCard(accent: .lavender, symbol: "chart.xyaxis.line", title: "Spot your patterns",
                                      detail: "Understand patterns in your own records").onboardingStagger(3)
                Label("Stored on this device", systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold)).foregroundStyle(palette.accent)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(palette.sage, in: Capsule())
                    .padding(.top, 6)
                    .onboardingStagger(4)
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    @ViewBuilder private var history: some View {
        if let latest = draft.periods.max(by: { $0.start < $1.start }) {
            Section { OnboardingDateCard(day: latest.start) }
                .listRowBackground(palette.recordedSurface)
        }
        Section {
            if draft.periods.isEmpty && draft.profile.unknownCycleFields?.contains(.lastStart) != true {
                Text("Choose the first day of your most recent period.").font(.title3.weight(.medium))
            }
            Button { editingPeriod = draft.periods.max(by: { $0.start < $1.start }) ?? Period(start: today) } label: {
                Label(draft.periods.isEmpty ? "Choose start date" : "Change start date", systemImage: "calendar")
                    .font(.body.weight(.semibold))
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
    }

    @ViewBuilder private var preview: some View {
        let overview = draft.overview(today: today)
        Section {
            OnboardingTodayPreview(overview: overview, typicalCycleDays: draft.profile.typicalCycleDays, today: today)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        Section {
            OnboardingIconRow(symbol: "calendar", tint: palette.recorded) {
                Text("Today will show your recorded cycle day and estimated window.")
            }
            OnboardingIconRow(symbol: "checkmark.circle.fill", tint: palette.accent) {
                Text("Daily check-in keeps bleeding and symptoms together.")
            }
            OnboardingIconRow(symbol: "bolt.fill", tint: palette.sun) {
                Text("Direct logging shortcuts remain available.")
            }
        } footer: {
            Text("After setup, Profile adds optional symptoms, measurements, identity, context and goals. Settings adds reminders and Apple Health import.")
        }
        if let estimate = overview.estimate {
            Section("Your first estimate") {
                LabeledContent("Possible next start", value: DayText.range(estimate.earliest, estimate.latest))
                Text(estimate.starterNotice ?? "Based on your recorded history.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .listRowBackground(palette.sunSurface)
        } else { Section { Text("You can track without an estimate.") } }
    }

    @ViewBuilder private var review: some View {
        let estimate = draft.overview(today: today).estimate
        let latest = draft.periods.max(by: { $0.start < $1.start })
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                     count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                OnboardingReviewTile(accent: .lavender, symbol: Step.cycleLength.symbol, title: "Typical cycle",
                                     value: draft.profile.typicalCycleDays.map { "\($0) days" } ?? "Not sure") {
                    edit(.cycleLength)
                }
                OnboardingReviewTile(accent: .rose, symbol: Step.cycle.symbol, title: "Typical period",
                                     value: draft.profile.typicalPeriodDays.map { "\($0) days" } ?? "Not sure") {
                    edit(.cycle)
                }
                OnboardingReviewTile(accent: .rose, symbol: Step.history.symbol, title: "Last period",
                                     value: latest.map { DayText.short($0.start) } ?? "Not sure") {
                    edit(.history)
                }
                OnboardingReviewTile(accent: .sun, symbol: Step.preview.symbol, title: "Next start estimate",
                                     value: estimate.map { DayText.range($0.earliest, $0.latest) } ?? "No estimate yet",
                                     badge: estimate.map { "\($0.confidence.rawValue) confidence" })
            }
            Button { edit(.about) } label: {
                Label("Edit your details", systemImage: Step.about.symbol)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.apricot)
            .font(.body.weight(.semibold))
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        Section {
            if let estimate {
                if let notice = estimate.starterNotice {
                    Text(notice)
                        .font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("starterEstimateNotice")
                }
            } else {
                Text("You can track without an estimate.")
            }
            Text("Estimates are not medical advice. Do not use for contraception, diagnosis or fertility planning.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Optional symptoms, measurements, identity, context, goals, reminders and Health import can be added after setup.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func unknown(_ field: CycleSetupField) -> Binding<Bool> {
        Binding(get: { draft.profile.unknownCycleFields?.contains(field) == true },
                set: { draft.profile.setUnknown(field, $0) })
    }

    private func navigate(to destination: Step, forward: Bool) {
        self.forward = forward
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { step = destination }
    }

    private func edit(_ target: Step) {
        editingReview = true
        error = nil
        navigate(to: target, forward: false)
    }

    private func goBack() {
        let destination = editingReview ? Step.review : Step(rawValue: step.rawValue - 1) ?? .welcome
        editingReview = false
        error = nil
        navigate(to: destination, forward: false)
    }

    private func advance() {
        do {
            let currentDay = session.today ?? today
            if step == .about || step == .cycleLength { try draft.profile.validate(today: currentDay) }
            if step == .cycle && draft.profile.typicalPeriodDays == nil && !unknown(.periodLength).wrappedValue { throw ProfileError.duration }
            if step == .cycleLength && draft.profile.typicalCycleDays == nil && !unknown(.cycleLength).wrappedValue { throw ProfileError.cycleLength }
            if step == .history {
                guard !draft.periods.isEmpty || unknown(.lastStart).wrappedValue else { throw ProfileError.lastPeriod }
                try PeriodValidation.validate(draft.periods, asOf: currentDay)
            }
            if step == .review { try draft.validate(today: currentDay) }
            let destination: Step
            if editingReview { destination = .review; editingReview = false }
            else { destination = Step(rawValue: step.rawValue + 1) ?? .apple }
            let progress = OnboardingProgress(draft: draft, stepID: String(destination.rawValue), updatedAt: Date())
            if let saveError = session.saveOnboardingProgress(progress) { throw OnboardingProgressError.save(saveError) }
            error = nil
            navigate(to: destination, forward: true)
        } catch { self.error = error.localizedDescription; errorFocused = true }
    }
}

private enum OnboardingProgressError: LocalizedError {
    case save(String)
    var errorDescription: String? { if case .save(let message) = self { message } else { nil } }
}
