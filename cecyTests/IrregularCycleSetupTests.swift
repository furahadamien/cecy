import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated private func unknownSetup() -> OnboardingDraft {
    var draft = OnboardingDraft()
    draft.profile.preferredName = "Synthetic Alex"
    draft.profile.birthDayKey = 19950512
    for field in [CycleSetupField.periodLength, .cycleLength, .lastStart] {
        draft.profile.setUnknown(field, true)
    }
    return draft
}

nonisolated struct IrregularCycleSetupTests {
    let today = try! LocalDay(key: 20260929)

    @Test func unknownIsDifferentFromUnansweredAndNeverCreatesRecords() throws {
        var draft = unknownSetup()
        try draft.validate(today: today)
        #expect(draft.periods.isEmpty && draft.profile.typicalCycleDays == nil && draft.profile.typicalPeriodDays == nil)
        #expect(draft.overview(today: today).estimate == nil && draft.overview(today: today).currentDay == nil)
        draft.profile.setUnknown(.periodLength, false)
        #expect(throws: ProfileError.duration) { try draft.validate(today: today) }
        draft.profile.typicalPeriodDays = 5
        draft.profile.setUnknown(.cycleLength, false)
        #expect(throws: ProfileError.cycleLength) { try draft.validate(today: today) }
        draft.profile.typicalCycleDays = 28
        draft.profile.setUnknown(.lastStart, false)
        #expect(throws: ProfileError.lastPeriod) { try draft.validate(today: today) }
    }

    @Test func choosingUnknownClearsOnlyTheSelectedAssumption() {
        var draft = unknownSetup()
        draft.profile.typicalCycleDays = 28
        draft.profile.typicalPeriodDays = 5
        draft.profile.setUnknown(.cycleLength, true)
        #expect(draft.profile.typicalCycleDays == nil && draft.profile.typicalPeriodDays == 5)
        draft.profile.setUnknown(.periodLength, true)
        #expect(draft.profile.typicalPeriodDays == nil)
    }

    @Test func legacyKnownValuesAndUnknownMetadataRoundTripWithoutReinterpretation() throws {
        var legacy = unknownSetup().profile
        legacy.unknownCycleFields = nil
        legacy.typicalPeriodDays = 5
        legacy.typicalCycleDays = 28
        let data = try JSONEncoder().encode(legacy)
        #expect(!String(decoding: data, as: UTF8.self).contains("unknownCycleFields"))
        let restored = try JSONDecoder().decode(LocalProfile.self, from: data)
        #expect(restored == legacy && restored.unknownCycleFields == nil)
        let unknown = unknownSetup().profile
        #expect(try JSONDecoder().decode(LocalProfile.self, from: JSONEncoder().encode(unknown)) == unknown)
    }

    @Test func unknownAnswersDoNotBypassIdentityBasicsOrFutureValidation() throws {
        var draft = unknownSetup()
        draft.profile.birthDayKey = nil
        #expect(throws: ProfileError.birthday) { try draft.validate(today: today) }
        draft.profile.birthDayKey = 19950512
        draft.periods = [Period(start: try today.adding(days: 1))]
        #expect(throws: TrackingError.futureDate) { try draft.validate(today: today) }
        draft.periods = []
        draft.profile.typicalCycleDays = 0
        #expect(throws: ProfileError.cycleLength) { try draft.validate(today: today) }
    }

    @Test func unknownLengthsDoNotDisableMeasuredHistoryOrInventBleeding() throws {
        var draft = unknownSetup()
        draft.periods = try [20260801, 20260901].map { Period(start: try LocalDay(key: $0)) }
        try draft.validate(today: today)
        let raw = CycleCalculator.overview(periods: draft.periods, today: today, engine: EvidencePredictionEngine())
        #expect(draft.overview(today: today) == raw)
        #expect(raw.estimate?.sourceLengths == [31])
        let forecast = CycleForecast.calculate(overview: raw, profile: draft.profile, periods: draft.periods, asOf: today)
        #expect(!forecast.cycles.isEmpty && forecast.cycles.allSatisfy { $0.bleeding == nil })
        #expect(CyclePhaseTimeline.make(overview: raw, forecast: forecast, periods: draft.periods, profile: draft.profile, today: today) == nil)
    }

    @Test func policyPreservesRegularAndStarterCalculations() throws {
        var profile = unknownSetup().profile
        profile.typicalCycleDays = 28
        profile.typicalPeriodDays = 5
        for keys in [[20260902], [20260607, 20260705, 20260804, 20260902]] {
            let periods = try keys.map { Period(start: try LocalDay(key: $0)) }
            let raw = CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine(), profile: profile)
            #expect(ForecastAvailabilityPolicy.applying(to: raw) == raw)
            #expect(!CycleForecast.calculate(overview: raw, profile: profile, periods: periods).cycles.isEmpty)
        }
    }

    @Test func unsuitableHistoryPreservesFactsButCannotScheduleAReference() throws {
        let periods = try [20260927, 20260928].map { Period(start: try LocalDay(key: $0)) }
        let raw = CycleCalculator.overview(periods: periods, today: today)
        let eligible = ForecastAvailabilityPolicy.applying(to: raw)
        #expect(raw.estimate?.sourceLengths == [1])
        #expect(eligible.intervals == raw.intervals && eligible.currentDay == raw.currentDay)
        #expect(eligible.prediction == .unavailable(.unsupportedEstimate))
        var preferences = PrivacyPreferences()
        preferences.dailyReminder = true
        preferences.windowReminder = true
        let reminders = try ReminderPlanner.requests(preferences: preferences, prediction: eligible.estimate,
            now: today.formattingDate, timeZone: .gmt)
        #expect(reminders.map(\.kind) == [.daily])
    }

    @Test func setupMetadataDoesNotExpandExportsOrAIContexts() throws {
        var snapshot = TrackerSnapshot(profile: unknownSetup().profile)
        snapshot.symptoms = [SymptomEntry(day: today, kind: .cramps)]
        let request = try AIContextBuilder.recordInsights(snapshot: snapshot, today: today)
        #expect(request == (try AIContextBuilder.recordInsights(snapshot: TrackerSnapshot(symptoms: snapshot.symptoms), today: today)))
        let exported = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: today.formattingDate, includeProfile: true)
        let text = String(decoding: exported, as: UTF8.self)
        #expect(!text.contains("unknownCycleFields") && !text.contains("typicalCycleDays"))
    }
}

@MainActor struct IrregularCycleSetupPersistenceTests {
    let today = try! LocalDay(key: 20260929)
    private enum Failure: Error { case disk }

    @Test func unknownSetupStagesReopensCompletesAndDoesNotReseed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("records.store")
        let draft = unknownSetup()
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let staged = try repository.prepareOnboarding(draft, today: today)
            #expect(staged.profile == draft.profile && staged.periods.isEmpty && staged.onboardingCompletedAt == nil)
        }
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let staged = try repository.load()
            var resumed = OnboardingDraft()
            resumed.profile = try #require(staged.profile)
            resumed.periods = staged.periods
            try resumed.validate(today: today)
            _ = try repository.completeOnboarding(profileID: draft.profile.id, today: today, now: today.formattingDate)
        }
        let reopened = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(reopened.onboardingCompletedAt != nil && reopened.profile == draft.profile && reopened.periods.isEmpty)
    }

    @Test func unansweredProfileCannotBypassFinalCompletionGuard() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        var profile = unknownSetup().profile
        profile.unknownCycleFields = nil
        _ = try repository.saveProfile(profile, today: today)
        #expect(throws: ProfileError.duration) {
            try repository.completeOnboarding(profileID: profile.id, today: today, now: today.formattingDate)
        }
        #expect(try repository.load().onboardingCompletedAt == nil)
    }

    @Test func unknownSetupStillRequiresAppleAndCanLogAfterCompletion() async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let account = AppleAccount()
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, timeZone: { .gmt }, account: account)
        session.load()
        let draft = unknownSetup()
        #expect(await session.finishSetup(draft) != nil)
        #expect(try repository.load() == TrackerSnapshot())
        try account.link(userID: "synthetic-unknown", profileID: draft.profile.id, protectsExistingProfile: false)
        #expect(session.registry.operations.isEmpty)
        #expect(await session.finishSetup(draft) == nil)
        #expect(session.registry.operations.map(\.kind) == [.activate])
        #expect(session.snapshot.onboardingCompletedAt != nil && session.snapshot.periods.isEmpty)
        #expect(session.overview != nil && session.overview?.estimate == nil && session.cycleForecast.cycles.isEmpty)
        #expect(!session.privacy.aiEnabled && !session.privacy.dailyInsightsEnabled)
        #expect(session.saveSymptom(SymptomEntry(day: today, kind: .cramps)) == nil)
        #expect(session.save([Period(start: today)]) == nil)
        session.refresh()
        #expect(session.overview?.currentDay == 1 && session.overview?.estimate?.basis == .cecyDefault)
        #expect(session.snapshot.profile?.typicalCycleDays == nil && session.snapshot.profile?.typicalPeriodDays == nil)
        #expect(session.snapshot.symptoms.count == 1 && session.snapshot.periods.count == 1)
        #expect(await session.deleteAllAndWait() == nil)
        #expect(try repository.load() == TrackerSnapshot())
        #expect(session.registry.operations.map(\.kind) == [.deactivate] && account.identity == nil)
    }

    @Test func failedUnknownSetupPreservesStagedAnswersAndRetries() async throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var writes = 0
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            writes += 1
            if writes == 2 { throw Failure.disk }
            try $0.save()
        })
        let draft = unknownSetup()
        let account = AppleAccount()
        try account.link(userID: "synthetic-unknown", profileID: draft.profile.id, protectsExistingProfile: false)
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, timeZone: { .gmt }, account: account)
        session.load()
        #expect(await session.finishSetup(draft) != nil)
        let staged = try repository.load()
        #expect(staged.profile == draft.profile && staged.periods.isEmpty && staged.onboardingCompletedAt == nil)
        #expect(await session.finishSetup(draft) == nil)
        #expect(try repository.load().profile == draft.profile)
    }
}
