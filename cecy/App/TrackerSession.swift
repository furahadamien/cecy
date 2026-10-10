import Foundation
import Observation

@MainActor @Observable
final class TrackerSession {
    enum Phase { case loading, loaded, failed }
    private(set) var phase: Phase = .loading
    private(set) var snapshot = TrackerSnapshot()
    private(set) var activityIndex = DayActivityIndex()
    private(set) var today: LocalDay?
    private(set) var overview: CycleOverview?
    private(set) var cycleForecast = CycleForecast()
    private(set) var statistics: CycleStatistics?
    private(set) var predictionReplay: PredictionReplay?
    private(set) var insights: [CycleInsight] = []
    private(set) var insightMessage: String?
    private(set) var isSaving = false
    private(set) var isUpdatingPredictions = false
    @ObservationIgnored private var predictionUpdateRevision = 0
    private(set) var failureMessage: String?
    var confirmation: String?
    let privacy: TrackerPrivacy
    let account: AppleAccount
    let registry: UserRegistryCoordinator
    @ObservationIgnored private var registryAuthorization: AppleIdentity?
    let healthImport: HealthImportReview
    let ai: AIRequestCoordinator
    let dailyAI: AIRequestCoordinator
    private(set) var dailyInsightRequest: AIRequest?
    var dailyInsightOutput: AIOutput? {
        guard canUseAI, dailyAI.request == dailyInsightRequest else { return nil }
        return dailyAI.output
    }
    var canUseAI: Bool {
        privacy.canAccess && privacy.aiEnabled && !account.requiresSignIn && phase == .loaded
            && snapshot.onboardingCompletedAt != nil && !isSaving && !isUpdatingPredictions
    }
    enum SetupStage: String {
        case saving = "Saving your profile"
        case analyzing = "Analyzing your cycles"
        case predicting = "Preparing your first prediction"
        case insights = "Getting your insights ready"
        case reminders = "Applying your reminders"
        case finishing = "Finishing setup"
    }
    private(set) var setupStage: SetupStage?
    @ObservationIgnored private var setupRevision = 0

    @ObservationIgnored private var repository: (any PeriodRepository)?
    @ObservationIgnored private let makeRepository: @MainActor () throws -> any PeriodRepository
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let zone: () -> TimeZone

    init(repository: @escaping @MainActor () throws -> any PeriodRepository = { try SwiftDataPeriodRepository.production() },
         clock: @escaping () -> Date = Date.init, timeZone: @escaping () -> TimeZone = { .current },
         privacy: TrackerPrivacy? = nil, account: AppleAccount? = nil,
         healthReader: (any HealthFlowReading)? = nil, aiService: any AIService = UnavailableAIService(),
         registry: UserRegistryCoordinator? = nil) {
        makeRepository = repository
        self.clock = clock
        zone = timeZone
        self.privacy = privacy ?? .isolated()
        self.account = account ?? AppleAccount()
        self.registry = registry ?? UserRegistryCoordinator()
        healthImport = HealthImportReview(reader: healthReader ?? UnavailableHealthReader())
        ai = AIRequestCoordinator(service: aiService)
        dailyAI = AIRequestCoordinator(service: aiService)
        self.account.onSuccessfulLink = { [weak self] in
            guard let self else { return }
            registryAuthorization = self.account.identity
            enqueueRegistryActivation()
        }
    }

    private func enqueueRegistryActivation() {
        guard privacy.canAccess, phase == .loaded, snapshot.onboardingCompletedAt != nil,
              let identity = registryAuthorization, account.identity == identity,
              let profile = snapshot.profile, profile.id == identity.profileID else { return }
        if registry.activate(appleUserID: identity.userID, displayName: profile.preferredName) {
            registryAuthorization = nil
        }
    }

    func resumeRegistry() {
        guard privacy.canAccess else { return }
        enqueueRegistryActivation()
        registry.resume()
    }

    /// UI entry point: present before synchronous local work, and keep its completion
    /// transition readable. A nil result retains the existing "committed" meaning.
    func withPredictionUpdate(_ operation: @MainActor () -> String?) async -> String? {
        guard privacy.canAccess, !account.requiresSignIn, phase == .loaded,
              !isSaving, !isUpdatingPredictions else { return "Finish the current update or unlock Cecy before saving." }
        isUpdatingPredictions = true
        predictionUpdateRevision += 1
        let token = predictionUpdateRevision
        let presentationClock = ContinuousClock()
        let deadline = presentationClock.now.advanced(by: .milliseconds(450))
        defer { if token == predictionUpdateRevision { isUpdatingPredictions = false } }
        // Let SwiftUI render the indicator before main-actor storage/calculation work.
        do { try await Task.sleep(for: .milliseconds(50)) }
        catch { return "The update was cancelled before saving. Your draft has not been saved." }
        guard token == predictionUpdateRevision, privacy.canAccess, !account.requiresSignIn,
              !Task.isCancelled else { return "The update was interrupted before saving. Your draft has not been saved." }
        let error = operation()
        if error == nil {
            // Once committed, cancellation must not misreport the save as a failure.
            try? await presentationClock.sleep(until: deadline)
        }
        return error
    }

    func cancelPredictionUpdatePresentation() {
        predictionUpdateRevision += 1
        isUpdatingPredictions = false
    }

    func performAI(_ request: AIRequest) {
        if case .wellness = request {
            prepareTodayInsights()
            return
        }
        ai.begin(request) { [weak self] in self?.canUseAI == true }
    }

    func preloadDailyInsights() {
        guard canUseAI, privacy.dailyInsightsEnabled, !ai.isLoading, !dailyAI.isLoading,
              dailyInsightOutput == nil,
              let today, let request = dailyInsightRequest,
              privacy.reserveDailyInsightAttempt(on: today) else { return }
        dailyAI.begin(request) { [weak self] in
            guard let self else { return false }
            return canUseAI && privacy.dailyInsightsEnabled && self.today == today && dailyInsightRequest == request
        }
    }

    /// Explicit generation/retry shares the automatic request and result across both tabs.
    func prepareTodayInsights() {
        guard canUseAI, !dailyAI.isLoading, let today, let request = dailyInsightRequest else { return }
        if privacy.dailyInsightsEnabled {
            // Manual retries are allowed, but must never be followed by another automatic attempt.
            if privacy.preferences.dailyInsightAttemptDay != today.key,
               !privacy.reserveDailyInsightAttempt(on: today) { return }
        }
        dailyAI.begin(request) { [weak self] in
            guard let self else { return false }
            return canUseAI && self.today == today && dailyInsightRequest == request
        }
    }

    func setAIEnabled(_ enabled: Bool) -> String? {
        if !enabled { ai.invalidate(); dailyAI.invalidate() }
        return privacy.setAIEnabled(enabled, now: clock())
    }

    func load() {
        ai.invalidate()
        guard privacy.canAccess, !account.requiresSignIn else { return }
        phase = .loading
        do {
            if repository == nil { repository = try makeRepository() }
            guard let repository else { throw TrackingError.invalidData }
            let loaded = try repository.load()
            let day = try LocalDay(date: clock(), timeZone: zone())
            publish(loaded, today: day)
            if loaded == TrackerSnapshot(), account.identityLoaded, account.identity == nil {
                registry.completeDeletion()
            }
            enqueueRegistryActivation()
        } catch {
            phase = .failed
            dailyAI.invalidate()
            failureMessage = "Your records couldn’t be opened. They have not been reset. Try again when your device is unlocked. If the problem continues, keep your app data intact."
        }
    }

    func refresh() {
        guard phase == .loaded, !isSaving else { return }
        load()
    }

    func cancelSetup() { setupRevision += 1 }

    func logOut() -> String? {
        guard privacy.canAccess, !isSaving, !isUpdatingPredictions, !privacy.isAuthenticating, !privacy.isChangingReminders,
              !account.isSigningIn else { return "Finish the current action before logging out." }
        do { try account.signOut() }
        catch { return "Logout couldn’t be saved securely. You are still signed in. Try again." }
        registryAuthorization = nil
        cancelSetup()
        healthImport.stop()
        ai.invalidate()
        dailyAI.invalidate()
        dailyInsightRequest = nil
        privacy.cleanupExport()
        snapshot = TrackerSnapshot()
        activityIndex = DayActivityIndex()
        today = nil
        overview = nil
        cycleForecast = CycleForecast()
        statistics = nil
        predictionReplay = nil
        insights = []
        insightMessage = nil
        confirmation = nil
        failureMessage = nil
        repository = nil
        phase = .loading
        return nil
    }

    func reviewAppleHealth(months: Int) {
        healthImport.begin(months: months, now: clock(), timeZone: zone()) { [weak self] in
            guard let self else { return false }
            return privacy.canAccess && !account.requiresSignIn && phase == .loaded && !isSaving
                && snapshot.onboardingCompletedAt != nil
        }
    }

    func importHealthStart(_ sample: HealthFlowSample, confirmedStart: LocalDay) -> String? {
        guard healthImport.contains(sample) else { return HealthImportError.interrupted.localizedDescription }
        let mappingZone = healthImport.mappingTimeZone
        return mutate(confirmation: "Period start imported.", failure: "Import wasn’t saved. No records were changed. Try again.") {
            try $0.importHealthStart(sample, confirmedStart: confirmedStart, today: $1, now: $2, timeZone: mappingZone)
        }
    }

    func saveProfile(_ profile: LocalProfile) -> String? {
        mutate(confirmation: "Profile updated.", failure: "Your profile hasn’t been saved. Try again.") { repository, today, _ in
            try repository.saveProfile(profile, today: today)
        }
    }

    func saveDailyInsightPreferences(_ preferences: WellnessPreferences?) -> String? {
        guard let preferences, preferences.isReadyForInsights else {
            return "Choose your activity, exercise, diet, allergies and goals first."
        }
        guard var profile = snapshot.profile else { return ProfileError.notReady.localizedDescription }
        profile.wellnessPreferences = preferences
        if let error = saveProfile(profile) { return error }
        // Save & prepare is an explicit request. No consent means local save only.
        prepareTodayInsights()
        return nil
    }

    /// Keychain, SwiftData and notification services cannot share one transaction.
    /// Stage local records atomically, retry idempotently, and publish completion last.
    func finishSetup(_ draft: OnboardingDraft, minimumPresentation: Duration = .zero) async -> String? {
        guard privacy.canAccess, !account.requiresSignIn, phase == .loaded, !isSaving, let repository else { return ProfileError.notReady.localizedDescription }
        isSaving = true
        let token = setupRevision
        defer { isSaving = false; setupStage = nil }
        func checkAccess() throws {
            guard token == setupRevision, privacy.canAccess, !Task.isCancelled else { throw ProfileError.notReady }
            guard account.state == .authorized, account.identity?.profileID == draft.profile.id else { throw ProfileError.identity }
        }
        do {
            let now = clock()
            let day = try LocalDay(date: now, timeZone: zone())
            try checkAccess()
            try draft.validate(today: day)
            setupStage = .saving
            let presentationClock = ContinuousClock()
            let presentationDeadline = presentationClock.now.advanced(by: minimumPresentation)
            await Task.yield()
            try checkAccess()
            let staged = try repository.prepareOnboarding(draft, today: day)
            snapshot = staged
            activityIndex = DayActivityIndex(snapshot: staged)
            today = day
            setupStage = .analyzing
            await Task.yield()
            try checkAccess()
            statistics = try CycleStatistics.calculate(periods: staged.periods, today: day)
            setupStage = .predicting
            await Task.yield()
            try checkAccess()
            overview = ForecastAvailabilityPolicy.applying(to: CycleCalculator.overview(
                periods: staged.periods, today: day, engine: EvidencePredictionEngine(), profile: staged.profile))
            predictionReplay = try PredictionBacktester.evaluate(periods: staged.periods, today: day)
            setupStage = .insights
            await Task.yield()
            try checkAccess()
            insights = try CycleInsightEngine.generate(periods: staged.periods, symptoms: staged.symptoms, today: day)
            insightMessage = nil
            setupStage = .reminders
            privacy.trackingChanged(prediction: overview?.estimate, now: now, timeZone: zone())
            let reminderResult = await privacy.setReminders(daily: draft.dailyReminder, window: draft.windowReminder,
                                                           hour: draft.reminderHour, minute: draft.reminderMinute,
                                                           showDetails: draft.reminderDetailsEnabled)
            try checkAccess()
            if reminderResult == .failed || reminderResult == .interrupted {
                return privacy.message ?? "Reminder choices couldn’t be saved. Retry setup."
            }
            setupStage = .finishing
            await Task.yield()
            // UI callers can keep the confirmation readable without adding delay to slow setup.
            // Completion stays uncommitted during the wait; backgrounding/cancellation still fail closed.
            if minimumPresentation > .zero {
                try await presentationClock.sleep(until: presentationDeadline)
            }
            try checkAccess()
            let completed = try repository.completeOnboarding(profileID: draft.profile.id, today: day, now: now)
            publish(completed, today: day)
            enqueueRegistryActivation()
            confirmation = reminderResult == .permissionUnavailable
                ? "Setup complete. Notifications weren’t enabled; you can change this in Settings."
                : "Your profile is ready."
            return nil
        } catch let error as ProfileError { return error.localizedDescription
        } catch let error as TrackingError { return error.localizedDescription
        } catch { return "Setup couldn’t finish. Your local records are intact. Try again." }
    }

    /// A nil result means the transaction committed. Errors never include storage details.
    func save(_ periods: [Period], completingOnboarding: Bool = false) -> String? {
        guard privacy.canAccess, !account.requiresSignIn, phase == .loaded, !isSaving, let repository else { return "Your records aren’t ready. Unlock Cecy or try loading them again." }
        isSaving = true
        defer { isSaving = false }
        do {
            let now = clock()
            let day = try LocalDay(date: now, timeZone: zone())
            let committed = try repository.add(periods, completingOnboarding: completingOnboarding, today: day, now: now)
            publish(committed, today: day)
            if !periods.isEmpty { confirmation = periods.count == 1 ? "Period start recorded." : "Previous period dates recorded." }
            return nil
        } catch let error as DailyBleedingError {
            return error.localizedDescription
        } catch let error as TrackingError {
            return error.localizedDescription
        } catch {
            return "Your dates haven’t been saved. They are still here so you can try again."
        }
    }

    private func publish(_ snapshot: TrackerSnapshot, today: LocalDay) {
        ai.invalidate()
        if self.snapshot != snapshot || self.today != today { dailyAI.invalidate() }
        dailyInsightRequest = try? AIContextBuilder.wellness(snapshot: snapshot, today: today)
        self.snapshot = snapshot
        activityIndex = DayActivityIndex(snapshot: snapshot)
        self.today = today
        overview = ForecastAvailabilityPolicy.applying(to: CycleCalculator.overview(
            periods: snapshot.periods, today: today, engine: EvidencePredictionEngine(), profile: snapshot.profile))
        cycleForecast = overview.map { CycleForecast.calculate(overview: $0, profile: snapshot.profile, periods: snapshot.periods, asOf: today, dailyBleeding: snapshot.dailyBleeding) } ?? CycleForecast()
        predictionReplay = try? PredictionBacktester.evaluate(periods: snapshot.periods, today: today)
        statistics = try? CycleStatistics.calculate(periods: snapshot.periods, today: today)
        privacy.trackingChanged(prediction: overview?.estimate, now: clock(), timeZone: zone())
        do {
            insights = try CycleInsightEngine.generate(periods: snapshot.periods, symptoms: snapshot.symptoms, today: today)
            insightMessage = nil
        } catch {
            insights = []
            insightMessage = "Observations cannot be compared in the current date context. Check your device date and recorded dates; no records have been removed."
        }
        failureMessage = nil
        phase = .loaded
    }

    func update(_ period: Period) -> String? {
        mutate(confirmation: "Period updated.", failure: "Your changes haven’t been saved. They are still here so you can try again.") {
            try $0.update(period, today: $1, now: $2)
        }
    }

    func delete(id: UUID) -> String? {
        mutate(confirmation: "Period deleted.", failure: "This period wasn’t deleted. Try again.") { repository, _, _ in
            try repository.delete(id: id)
        }
    }

    func saveDailyBleeding(_ observation: DailyBleedingObservation, editing: Bool = false) -> String? {
        mutate(confirmation: editing ? "Daily answer updated." : "Daily answer recorded.",
               failure: "Your daily answer hasn’t been saved. Keep your draft and try again.") {
            try $0.saveDailyBleeding(observation, editing: editing, today: $1, now: $2)
        }
    }

    func deleteDailyBleeding(id: UUID) -> String? {
        mutate(confirmation: "Daily answer deleted.", failure: "Your daily answer wasn’t deleted. Try again.") { repository, _, _ in
            try repository.deleteDailyBleeding(id: id)
        }
    }

    func reconcileBleeding(_ review: BleedingReconciliation) -> String? {
        mutate(confirmation: "Reviewed records updated.", failure: "Your reviewed changes haven’t been saved. Try again.") {
            try $0.reconcileBleeding(review, today: $1, now: $2)
        }
    }

    func saveSymptom(_ entry: SymptomEntry, editing: Bool = false) -> String? {
        mutate(confirmation: editing ? "Observation updated." : "Observation recorded.",
               failure: "Your observation hasn’t been saved. Your draft is still here; try again.") {
            try $0.saveSymptom(entry, editing: editing, today: $1, now: $2)
        }
    }

    func addSymptoms(_ entries: [SymptomEntry]) -> String? {
        mutate(confirmation: entries.count == 1 ? "Observation recorded." : "Observations recorded.",
               failure: "Your observations haven’t been saved. Your draft is still here; try again.") {
            try $0.addSymptoms(entries, today: $1, now: $2)
        }
    }

    func deleteSymptoms(on day: LocalDay) -> String? {
        mutate(confirmation: "Symptoms deleted for \(DayText.full(day)).",
               failure: "These symptoms weren’t deleted. Try again.") { repository, _, _ in
            try repository.deleteSymptoms(on: day)
        }
    }

    func deleteSymptom(id: UUID) -> String? {
        mutate(confirmation: "Observation deleted.", failure: "This observation wasn’t deleted. Try again.") { repository, _, _ in
            try repository.deleteSymptom(id: id)
        }
    }

    func saveSexualActivity(_ entry: SexualActivityEntry, editing: Bool = false) -> String? {
        mutate(confirmation: editing ? "Activity record updated." : "Activity recorded.",
               failure: "Your activity hasn’t been saved. Your draft is still here; try again.") {
            try $0.saveSexualActivity(entry, editing: editing, today: $1, now: $2)
        }
    }

    func deleteSexualActivity(id: UUID) -> String? {
        mutate(confirmation: "Activity record deleted.", failure: "This activity record wasn’t deleted. Try again.") { repository, _, _ in
            try repository.deleteSexualActivity(id: id)
        }
    }

    func deleteAllAndWait() async -> String? {
        guard privacy.canAccess, !isSaving, !isUpdatingPredictions else {
            return "Finish the current update or unlock Cecy before deleting records."
        }
        ai.invalidate()
        dailyAI.invalidate()
        healthImport.stop()
        if account.requiresSignIn { return await resetWhileSignedOut() }
        // Keep the mutation gate closed across the notification-service suspension.
        isSaving = true
        defer { isSaving = false }
        do {
            try registry.prepareDeletion(appleUserID: account.identity?.userID)
            registryAuthorization = nil
            try privacy.prepareForReset()
            await privacy.reminders.flush()
            guard !Task.isCancelled else {
                return "Deletion was cancelled. Records remain unchanged; reminders may already be disabled."
            }
            // deleteAll's synchronous transaction owns the gate from here; no suspension intervenes.
            isSaving = false
            return deleteAll()
        } catch {
            return "Deletion did not finish. Records remain unchanged; reminders may already be disabled. Try again."
        }
    }

    /// Only used by the explicit, typed DELETE confirmation on the signed-out screen.
    private func resetWhileSignedOut() async -> String? {
        isSaving = true
        defer { isSaving = false }
        do {
            // Never discard an unreadable identity: it may be needed to deactivate the registry.
            guard account.identityLoaded else { throw AccountError.storage }
            try registry.prepareDeletion(appleUserID: account.identity?.userID)
            registryAuthorization = nil
            try privacy.prepareForReset()
            await privacy.reminders.flush()
            guard privacy.canAccess, !Task.isCancelled else { throw ProfileError.notReady }
            let repository = try makeRepository()
            _ = try repository.deleteAll()
            try account.removeLocalIdentity()
            self.repository = repository
            publish(TrackerSnapshot(), today: try LocalDay(date: clock(), timeZone: zone()))
            registry.completeDeletion()
            return nil
        } catch {
            return "Reset did not finish. Local records may already be deleted, but the Apple link may remain. Retry to finish cleanup."
        }
    }

    func deleteAll() -> String? {
        guard !isSaving, !isUpdatingPredictions else {
            return "Finish the current update before deleting records."
        }
        ai.invalidate()
        dailyAI.invalidate()
        healthImport.stop()
        let error = mutate(confirmation: nil,
                failure: "Deletion did not finish. Local records may already be deleted. Retry to finish account cleanup.") { repository, _, _ in
            try self.registry.prepareDeletion(appleUserID: self.account.identity?.userID)
            self.registryAuthorization = nil
            try self.privacy.prepareForReset()
            // Keep the Apple identity recoverable until the health-store transaction commits.
            let empty = try repository.deleteAll()
            try self.account.removeLocalIdentity()
            return empty
        }
        if error == nil { registry.completeDeletion() }
        return error
    }

    private func mutate(confirmation: String?, failure: String,
                        operation: (any PeriodRepository, LocalDay, Date) throws -> TrackerSnapshot) -> String? {
        guard privacy.canAccess, !account.requiresSignIn, phase == .loaded, !isSaving, let repository else { return "Your records aren’t ready. Unlock Cecy or try loading them again." }
        isSaving = true
        defer { isSaving = false }
        do {
            let now = clock()
            let day = try LocalDay(date: now, timeZone: zone())
            let committed = try operation(repository, day, now)
            publish(committed, today: day)
            self.confirmation = confirmation
            return nil
        } catch let error as ProfileError {
            return error.localizedDescription
        } catch let error as WellnessValidationError {
            return error.localizedDescription
        } catch let error as SexualActivityError {
            return error.localizedDescription
        } catch let error as HealthImportError {
            return error.localizedDescription
        } catch let error as DailyBleedingError {
            return error.localizedDescription
        } catch let error as TrackingError {
            return error.localizedDescription
        } catch { return failure }
    }

    static func live() -> TrackerSession {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
           ProcessInfo.processInfo.environment["CECY_UI_TEST_ID"] == nil {
            return TrackerSession(repository: { try SwiftDataPeriodRepository.inMemory() })
        }
        // Isolated UI-test composition; never removes or opens the production store.
        if let value = ProcessInfo.processInfo.environment["CECY_UI_TEST_ID"], let id = UUID(uuidString: value) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CecyUITests", isDirectory: true)
                .appendingPathComponent(id.uuidString, isDirectory: true).appendingPathComponent("test.store")
            let fixed = ISO8601DateFormatter().date(from: "2026-09-29T12:00:00Z")!
            return TrackerSession(repository: {
                let repository = try SwiftDataPeriodRepository.local(url: url)
                let fixture = ProcessInfo.processInfo.environment["CECY_UI_FIXTURE"]
                if fixture == "history" || fixture == "patterns" || fixture == "wellness" || fixture == "ai" || fixture == "sparse" || fixture == "oldStart",
                   try repository.load().onboardingCompletedAt == nil {
                    let keys = fixture == "oldStart" ? [20260101] : fixture == "sparse" ? [20260902] : fixture == "patterns" || fixture == "ai" ? [20260410, 20260509, 20260607, 20260705, 20260804, 20260902]
                        : [20260607, 20260705, 20260804, 20260902]
                    let periods = try keys.map { key in
                        let start = try LocalDay(key: key)
                        return Period(start: start, end: fixture == "ai" ? try start.adding(days: 4) : nil)
                    }
                    _ = try repository.add(periods, completingOnboarding: true, today: LocalDay(key: 20260929), now: fixed)
                    if fixture == "wellness" || fixture == "ai" || fixture == "sparse" || fixture == "oldStart" {
                        var profile = LocalProfile()
                        profile.preferredName = "Synthetic Alex"
                        profile.birthDayKey = 19950512
                        profile.typicalPeriodDays = 5
                        if fixture == "sparse" || fixture == "oldStart" {
                            profile.typicalCycleDays = 28
                            _ = try repository.addSymptoms([SymptomEntry(day: LocalDay(key: 20260929), kind: .cramps, value: 2)],
                                                           today: LocalDay(key: 20260929), now: fixed)
                        }
                        if fixture == "ai" {
                            profile.wellnessPreferences = WellnessPreferences(activityLevel: .moderatelyActive, preferredExercises: [.walking],
                                dietaryPreference: .vegetarian, foodAllergyStatus: .listed, foodAllergies: ["Peanuts"], goals: [.manageSymptoms])
                            _ = try repository.addSymptoms([SymptomEntry(day: LocalDay(key: 20260929), kind: .cramps, value: 3)],
                                                           today: LocalDay(key: 20260929), now: fixed)
                        }
                        _ = try repository.saveProfile(profile, today: LocalDay(key: 20260929))
                    }
                    if fixture == "patterns" || fixture == "ai" {
                        for period in periods {
                            let entry = try SymptomEntry(day: period.start.adding(days: -1), kind: .headache)
                            _ = try repository.saveSymptom(entry, editing: false, today: LocalDay(key: 20260929), now: fixed)
                        }
                    }
                }
                return repository
            }, clock: { fixed }, timeZone: { TimeZone(secondsFromGMT: 0)! }, privacy: .testing(id: id), account: .testing(id: id),
               healthReader: FixtureHealthReader(mode: ProcessInfo.processInfo.environment["CECY_UI_HEALTH"] ?? "unavailable"),
               aiService: FixtureAIService(mode: ProcessInfo.processInfo.environment["CECY_UI_AI"] ?? "unavailable"))
        }
        #endif
        return TrackerSession(privacy: .production(), account: .production(), healthReader: HealthKitService(), aiService: RemoteAIService(),
                              registry: UserRegistryCoordinator(service: RemoteUserRegistryService(), store: KeychainRegistryOperationStore()))
    }
}

#if DEBUG
extension TrackerSession {
    static func preview(withHistory: Bool) -> TrackerSession {
        let fixed = ISO8601DateFormatter().date(from: "2026-09-29T12:00:00Z")!
        let session = TrackerSession(repository: {
            let repository = try SwiftDataPeriodRepository.inMemory()
            if withHistory {
                let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
                _ = try repository.add(periods, completingOnboarding: true, today: LocalDay(key: 20260929), now: fixed)
            }
            return repository
        }, clock: { fixed }, timeZone: { TimeZone(secondsFromGMT: 0)! })
        session.load()
        return session
    }
}
#endif
