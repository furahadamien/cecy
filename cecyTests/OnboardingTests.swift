import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated private func onboardingFixture() throws -> OnboardingDraft {
    var draft = OnboardingDraft()
    draft.profile.preferredName = "Synthetic Alex"
    draft.profile.birthDayKey = 19950512
    draft.profile.typicalPeriodDays = 5
    draft.periods = try [20260607, 20260705, 20260804, 20260902].map {
        Period(start: try LocalDay(key: $0), createdAt: try LocalDay(key: 20260929).formattingDate)
    }
    return draft
}

nonisolated struct OnboardingDomainTests {
    private let today = try! LocalDay(key: 20260929)

    @Test func fourStartsRequiredAndPredictionPolicyUnchanged() throws {
        var draft = try onboardingFixture()
        try draft.validate(today: today)
        #expect(draft.overview(today: today).intervals.map(\.length) == [28, 30, 29])
        #expect(draft.statistics(today: today)?.cycles?.mean == 29)
        #expect(draft.overview(today: today).estimate?.confidence == .low)
        draft.periods.removeFirst()
        #expect(throws: ProfileError.self) { try draft.validate(today: today) }
        #expect(draft.overview(today: today).estimate == nil)
    }

    @Test func preferencesNeverBecomePredictionEvidence() throws {
        var draft = try onboardingFixture()
        let estimate = draft.overview(today: today)
        draft.profile.heightCentimeters = 173.2
        draft.profile.weightKilograms = 65.5
        draft.profile.commonSymptoms = [.headaches, .lowEnergy]
        draft.profile.goals = [.doctorVisits]
        draft.profile.predictability = .rarely
        draft.profile.cycleContext = [.breastfeeding, .postpartum]
        draft.profile.typicalPeriodDays = 7
        #expect(draft.overview(today: today) == estimate)
        #expect(draft.periods.allSatisfy { $0.end == nil })
    }

    @Test func validatesNamesBirthdaysMeasurementsAndExclusiveChoices() throws {
        var profile = try onboardingFixture().profile
        profile.preferredName = "  "
        #expect(throws: ProfileError.self) { try profile.validate(today: today) }
        profile.preferredName = "Synthetic"
        profile.birthDayKey = 20270101
        #expect(throws: ProfileError.self) { try profile.validate(today: today) }
        profile.birthDayKey = nil
        #expect(throws: ProfileError.self) { try profile.validate(today: today) }
        profile.birthDayKey = 19950512
        for invalid in [Double.nan, Double.infinity, -1, 0] {
            profile.weightKilograms = invalid
            #expect(throws: ProfileError.self) { try profile.validate(today: today) }
        }
        profile.weightKilograms = nil
        profile.toggle(.cramps as CommonSymptom)
        profile.toggle(.none as CommonSymptom)
        #expect(profile.commonSymptoms == [.none])
        profile.toggle(.headaches as CommonSymptom)
        #expect(profile.commonSymptoms == [.headaches])
        profile.toggle(.postpartum as CycleContext)
        profile.toggle(.preferNotToSay as CycleContext)
        #expect(profile.cycleContext == [.preferNotToSay])
        profile.toggle(.breastfeeding as CycleContext)
        #expect(profile.cycleContext == [.breastfeeding])
        try profile.validate(today: today)
    }

    @Test func unitsRoundTripWithoutChangingStoredValues() {
        for units in MeasurementSystem.allCases {
            #expect(abs(units.heightInCentimeters(units.heightForDisplay(173.2)) - 173.2) < 0.000001)
            #expect(abs(units.weightInKilograms(units.weightForDisplay(65.5)) - 65.5) < 0.000001)
        }
    }

    @Test func variableHistoryCanFinishWithoutFabricatingAnEstimate() throws {
        var draft = try onboardingFixture()
        draft.periods = try [20260301, 20260401, 20260601, 20260901].map { Period(start: try LocalDay(key: $0)) }
        try draft.validate(today: today)
        #expect(draft.overview(today: today).prediction == .wideVariation)
    }

    @Test func profileExportRequiresIndependentConsent() throws {
        let draft = try onboardingFixture()
        let snapshot = TrackerSnapshot(periods: draft.periods, profile: draft.profile)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let excluded = try TrackerExport.encode(snapshot: snapshot, includeNotes: true, generatedAt: today.formattingDate)
        #expect(try decoder.decode(TrackerExport.Document.self, from: excluded).profile == nil)
        #expect(!String(decoding: excluded, as: UTF8.self).contains("Synthetic Alex"))
        let included = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: today.formattingDate, includeProfile: true)
        let document = try decoder.decode(TrackerExport.Document.self, from: included)
        #expect(document.formatVersion == 2)
        #expect(document.profile?.dateOfBirth == "1995-05-12")
        #expect(document.profile?.preferredName == "Synthetic Alex")
        #expect(!String(decoding: included, as: UTF8.self).contains("userID"))
    }
}

@MainActor struct OnboardingPersistenceTests {
    private let today = try! LocalDay(key: 20260929)
    private enum Failure: Error { case disk }

    @Test func stagingIsAtomicRetryableAndDoesNotCompleteEarly() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let draft = try onboardingFixture()
        let first = try repository.prepareOnboarding(draft, today: today)
        #expect(first.onboardingCompletedAt == nil && first.periods.count == 4)
        #expect(first.profile == draft.profile && first.symptoms.isEmpty)
        #expect(try repository.prepareOnboarding(draft, today: today) == first)
        let completed = try repository.completeOnboarding(profileID: draft.profile.id, today: today, now: today.formattingDate)
        #expect(completed.onboardingCompletedAt == today.formattingDate)
        #expect(try repository.completeOnboarding(profileID: draft.profile.id, today: today, now: Date()) == completed)
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func failedStagingRollsBackProfileAndPeriodsTogether() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let repository = SwiftDataPeriodRepository(container: memory.container, save: { _ in throw Failure.disk })
        #expect(throws: Failure.self) { try repository.prepareOnboarding(onboardingFixture(), today: today) }
        #expect(try repository.load() == TrackerSnapshot())
    }

    @Test func v3MigrationPreservesLegacyHistoryAndOnboarding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy.store")
        let draft = try onboardingFixture()
        try autoreleasepool {
            let schema = Schema(versionedSchema: TrackerSchemaV3.self)
            let configuration = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            draft.periods.forEach { context.insert(TrackerSchemaV2.PeriodRecord($0)) }
            context.insert(TrackerSchemaV2.AppStateRecord(completedAt: today.formattingDate))
            try context.save()
        }
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let migrated = try repository.load()
            #expect(migrated.periods == draft.periods && migrated.profile == nil)
            #expect(migrated.onboardingCompletedAt == today.formattingDate)
            _ = try repository.saveProfile(draft.profile, today: today)
        }
        let reopened = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(reopened.profile == draft.profile && reopened.periods == draft.periods)
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func setupRetriesAfterFinalCommitFailureAndRecalculatesEdits() async throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var writes = 0
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            writes += 1
            if writes == 2 { throw Failure.disk }
            try $0.save()
        })
        let draft = try onboardingFixture()
        let account = AppleAccount()
        try account.link(userID: "synthetic", profileID: draft.profile.id, protectsExistingProfile: false)
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, timeZone: { .gmt }, account: account)
        session.load()
        #expect(await session.finishSetup(draft) != nil)
        #expect(session.snapshot.onboardingCompletedAt == nil)
        #expect(try repository.load().periods.count == 4)
        #expect(await session.finishSetup(draft) == nil)
        #expect(session.snapshot.periods.count == 4 && session.overview?.estimate != nil)
        #expect(session.snapshot.symptoms.isEmpty)
        let originalPrediction = session.overview
        var profile = draft.profile
        profile.typicalPeriodDays = 7
        profile.commonSymptoms = [.headaches]
        #expect(session.saveProfile(profile) == nil)
        #expect(session.snapshot.profile?.typicalPeriodDays == 7 && session.overview == originalPrediction)
        var period = draft.periods[3]
        period.start = try period.start.adding(days: 1)
        #expect(session.update(period) == nil)
        #expect(session.overview != originalPrediction)
        #expect(await session.deleteAllAndWait() == nil)
        #expect(session.snapshot == TrackerSnapshot() && account.identity == nil)
    }

    @Test func setupPresentationFinishesBeforePublishingCompletion() async throws {
        let draft = try onboardingFixture()
        let repository = try SwiftDataPeriodRepository.inMemory()
        let account = AppleAccount()
        try account.link(userID: "synthetic", profileID: draft.profile.id, protectsExistingProfile: false)
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, account: account)
        session.load()
        let clock = ContinuousClock()
        let start = clock.now
        #expect(await session.finishSetup(draft, minimumPresentation: .milliseconds(40)) == nil)
        #expect(start.duration(to: clock.now) >= .milliseconds(40))
        #expect(session.snapshot.onboardingCompletedAt != nil)
        #expect(session.setupStage == nil && !session.isSaving)
        #expect(session.overview?.estimate != nil)
    }

    @Test func cancellationDuringPresentationDoesNotCompleteOnboarding() async throws {
        let draft = try onboardingFixture()
        let repository = try SwiftDataPeriodRepository.inMemory()
        let account = AppleAccount()
        try account.link(userID: "synthetic", profileID: draft.profile.id, protectsExistingProfile: false)
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, account: account)
        session.load()
        let task = Task { await session.finishSetup(draft, minimumPresentation: .seconds(30)) }
        defer { task.cancel() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while session.setupStage != .finishing && ContinuousClock.now < deadline { await Task.yield() }
        try #require(session.setupStage == .finishing)
        #expect(session.snapshot.onboardingCompletedAt == nil)
        #expect(try repository.load().onboardingCompletedAt == nil)
        session.cancelSetup()
        task.cancel()
        #expect(await task.value != nil)
        #expect(session.setupStage == nil && !session.isSaving)
        #expect(try repository.load().onboardingCompletedAt == nil)
        #expect(await session.finishSetup(draft) == nil)
        #expect(session.snapshot.periods.count == 4)
    }

    @Test func missingIdentityCannotPersistOnboarding() async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate })
        session.load()
        let draft = try onboardingFixture()
        #expect(await session.finishSetup(draft) != nil)
        #expect(try repository.load() == TrackerSnapshot())
    }

    @Test func deniedNotificationsDoNotBlockCompletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let delivery = MemoryReminderDelivery(); delivery.permission = .denied
        let privacy = TrackerPrivacy(storage: MemoryPrivacyPreferences(), authentication: FixedDeviceAuthentication(),
                                     exports: ProtectedExportFiles(directory: directory), delivery: delivery)
        privacy.start()
        var draft = try onboardingFixture(); draft.dailyReminder = true
        let account = AppleAccount()
        try account.link(userID: "synthetic", profileID: draft.profile.id, protectsExistingProfile: false)
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, privacy: privacy, account: account)
        session.load()
        #expect(await session.finishSetup(draft) == nil)
        #expect(session.snapshot.onboardingCompletedAt != nil)
        #expect(!privacy.preferences.dailyReminder && delivery.requests.isEmpty)
        #expect(session.confirmation?.contains("weren’t enabled") == true)
    }

    @Test func cancellationBeforePersistencePreservesDraft() async throws {
        let draft = try onboardingFixture()
        let repository = try SwiftDataPeriodRepository.inMemory()
        let account = AppleAccount()
        try account.link(userID: "synthetic", profileID: draft.profile.id, protectsExistingProfile: false)
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, account: account)
        session.load()
        let task = Task { await session.finishSetup(draft) }
        task.cancel()
        #expect(await task.value != nil)
        #expect(try repository.load().onboardingCompletedAt == nil)
        #expect(draft.periods.count == 4)
    }
}

@MainActor struct AppleIdentityTests {
    @Test func cancellationRevocationAndAccountMismatchDoNotEraseIdentity() throws {
        let store = MemoryAppleIdentityStore()
        let account = AppleAccount(store: store)
        let profileID = UUID()
        let token = account.beginAuthorization()
        account.cancelPendingAuthorization()
        #expect(!account.accept(.failure(AccountError.cancelled), token: token, profileID: profileID, protectsExistingProfile: false))
        #expect(store.identity == nil)
        try account.link(userID: "synthetic-one", profileID: profileID, protectsExistingProfile: false)
        account.markRevoked()
        #expect(account.state == .revoked && store.identity?.userID == "synthetic-one")
        #expect(throws: ProfileError.self) {
            try account.link(userID: "synthetic-two", profileID: profileID, protectsExistingProfile: true)
        }
        #expect(store.identity?.userID == "synthetic-one")
        try account.link(userID: "synthetic-one", profileID: profileID, protectsExistingProfile: true)
        #expect(account.state == .authorized)
        try account.removeLocalIdentity()
        #expect(store.identity == nil && account.state == .notLinked)
    }
}
