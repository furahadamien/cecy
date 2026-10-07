import Foundation
import Testing
@testable import cecy

nonisolated struct StarterPredictionTests {
    private let today = try! LocalDay(key: 20260929)
    private func profile(cycle: Int? = 28, period: Int? = 5) -> LocalProfile {
        var p = LocalProfile()
        p.preferredName = "Synthetic"
        p.birthDayKey = 19950512
        p.typicalCycleDays = cycle
        p.typicalPeriodDays = period
        return p
    }

    @Test func newSetupAndLegacyProfilesDoNotInventLengths() throws {
        #expect(OnboardingDraft().profile.typicalPeriodDays == nil)
        #expect(OnboardingDraft().profile.typicalCycleDays == nil)
        #expect(LocalProfile().typicalCycleDays == nil)
        let legacy = profile(cycle: nil)
        let data = try JSONEncoder().encode(legacy)
        #expect(!String(decoding: data, as: UTF8.self).contains("typicalCycleDays"))
        #expect(try JSONDecoder().decode(LocalProfile.self, from: data).typicalCycleDays == nil)
    }

    @Test func starterUsesLastStartAndUsualCycleWithoutInventingHistory() throws {
        let period = Period(start: try LocalDay(key: 20260902))
        let result = CycleCalculator.overview(periods: [period], today: today, engine: EvidencePredictionEngine(), profile: profile())
        let estimate = try #require(result.estimate)
        #expect(try estimate.center == LocalDay(key: 20260930))
        #expect(try estimate.earliest == LocalDay(key: 20260927) && estimate.latest == LocalDay(key: 20261003))
        #expect(estimate.confidence == .low && estimate.basis == .usualCycle)
        #expect(estimate.sourceLengths.isEmpty && result.intervals.isEmpty)
        #expect(estimate.reportedPeriodDays == 5 && estimate.reportedCycleDays == 28)
        #expect(result.currentDay == 28)
        #expect(try period.end == nil && !period.contains(period.start.adding(days: 1)))
    }

    @Test func periodDurationNeverShiftsNextStartOrCreatesBleedingDays() throws {
        let periods = [Period(start: try LocalDay(key: 20260902))]
        let a = try #require(CycleCalculator.overview(periods: periods, today: today, profile: profile(period: 5)).estimate)
        let b = try #require(CycleCalculator.overview(periods: periods, today: today, profile: profile(period: 7)).estimate)
        #expect(a.center == b.center && a.earliest == b.earliest && a.latest == b.latest)
        #expect(a.reportedPeriodDays == 5 && b.reportedPeriodDays == 7)
        #expect(try CycleStatistics.calculate(periods: periods, today: today).bleeding == nil)
    }

    @Test func missingProfileOrStartDoesNotInventAnEstimate() throws {
        let periods = [Period(start: try LocalDay(key: 20260902))]
        #expect(CycleCalculator.overview(periods: periods, today: today).estimate == nil)
        #expect(CycleCalculator.overview(periods: periods, today: today, profile: profile(cycle: nil)).estimate == nil)
        #expect(CycleCalculator.overview(periods: [], today: today, profile: profile()).estimate == nil)
    }

    @Test func measuredHistorySuppliesInputsAndCanWithhold() throws {
        let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        let historical = CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine())
        #expect(CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine(), profile: profile(cycle: 60)) == historical)
        #expect(historical.estimate?.basis == .recordedHistory)
        #expect(historical.estimate?.reportedCycleDays == nil)
        let variable = try [20260301, 20260401, 20260601, 20260901].map { Period(start: try LocalDay(key: $0)) }
        #expect(CycleCalculator.overview(periods: variable, today: today, profile: profile()).prediction == .wideVariation)
    }

    @Test func expiredStarterDoesNotRollForwardOrSchedulePastNotification() throws {
        let period = Period(start: try LocalDay(key: 20260101))
        let estimate = try #require(CycleCalculator.overview(periods: [period], today: today, profile: profile()).estimate)
        #expect(try estimate.center == LocalDay(key: 20260129))
        #expect(estimate.latest < today)
        var prefs = PrivacyPreferences(); prefs.windowReminder = true
        #expect(try ReminderPlanner.requests(preferences: prefs, prediction: estimate, now: today.formattingDate, timeZone: .gmt).isEmpty)
    }

    @Test func starterDateArithmeticHandlesLeapAndMonthBoundaries() throws {
        let leap = try #require(CycleCalculator.overview(periods: [Period(start: LocalDay(key: 20240201))],
            today: LocalDay(key: 20240201), profile: profile()).estimate)
        #expect(try leap.center == LocalDay(key: 20240229))
        let rollover = try #require(CycleCalculator.overview(periods: [Period(start: LocalDay(key: 20261220))],
            today: LocalDay(key: 20261220), profile: profile()).estimate)
        #expect(try rollover.center == LocalDay(key: 20270117))
    }

    @Test func invalidInputsCannotBypassDateOrProfileValidation() throws {
        for days in [0, 9, 121] {
            #expect(throws: ProfileError.cycleLength) { try profile(cycle: days).validate(today: today) }
        }
        #expect(throws: ProfileError.cycleLength) { try profile(cycle: 20, period: 21).validate(today: today) }
        let future = Period(start: try today.adding(days: 1))
        #expect(CycleCalculator.overview(periods: [future], today: today, profile: profile()).prediction == .unavailable(.futureDate))
    }

    @Test func profileAssumptionsNeverEnterHistoricalReplayOrStatistics() throws {
        let periods = try [20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        let overview = CycleCalculator.overview(periods: periods, today: today, profile: profile())
        #expect(overview.estimate?.basis == .recordedHistory)
        #expect(overview.estimate?.sourceLengths == [30, 29])
        let replay = try PredictionBacktester.evaluate(periods: periods, today: today)
        #expect(replay.scored.count == 1 && replay.warmUpCount == 1)
        #expect(replay.scored.first?.estimate?.sourceLengths == [30])
        #expect(try CycleStatistics.calculate(periods: periods, today: today).cycles?.count == 2)
    }

    @Test func exportRequiresProfileConsentAndPreservesOldVersionWhenMissing() throws {
        let snapshot = TrackerSnapshot(periods: [], profile: profile())
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let included = try decoder.decode(TrackerExport.Document.self, from: TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: today.formattingDate, includeProfile: true))
        #expect(included.formatVersion == 6 && included.profile?.typicalCycleDays == 28)
        let excluded = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: today.formattingDate)
        #expect(!String(decoding: excluded, as: UTF8.self).contains("typicalCycleDays"))
        let old = try decoder.decode(TrackerExport.Document.self, from: TrackerExport.encode(snapshot: TrackerSnapshot(profile: profile(cycle: nil)), includeNotes: false, generatedAt: today.formattingDate, includeProfile: true))
        #expect(old.formatVersion == 2 && old.profile?.typicalCycleDays == nil)
    }
}

@MainActor struct StarterSetupPersistenceTests {
    @Test func oneStartStagesCompletesReopensAndChangesRecalculate() async throws {
        let today = try LocalDay(key: 20260929)
        var draft = OnboardingDraft()
        draft.profile.preferredName = "Synthetic"
        draft.profile.birthDayKey = 19950512
        draft.profile.typicalPeriodDays = 5
        draft.profile.typicalCycleDays = 28
        draft.periods = [Period(start: try LocalDay(key: 20260902))]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try SwiftDataPeriodRepository.local(url: directory.appendingPathComponent("records.store"))
        let staged = try repository.prepareOnboarding(draft, today: today)
        #expect(staged.periods.count == 1 && staged.onboardingCompletedAt == nil)
        let completed = try repository.completeOnboarding(profileID: draft.profile.id, today: today, now: today.formattingDate)
        #expect(completed.profile?.typicalCycleDays == 28 && completed.periods.first?.end == nil)
        let reopened = try SwiftDataPeriodRepository.local(url: directory.appendingPathComponent("records.store"))
        #expect(try reopened.load() == completed)
        let session = TrackerSession(repository: { reopened }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        let original = try #require(session.overview?.estimate?.center)
        var p = draft.profile; p.typicalCycleDays = 31
        #expect(session.saveProfile(p) == nil)
        #expect(try session.overview?.estimate?.center == original.adding(days: 3))
        p.typicalCycleDays = nil
        #expect(session.saveProfile(p) == nil && session.overview?.estimate == nil)
        // Completed legacy profiles do not have to re-answer newly added fields.
        #expect(try reopened.completeOnboarding(profileID: p.id, today: today, now: Date()).onboardingCompletedAt != nil)
        #expect(session.delete(id: draft.periods[0].id) == nil && session.overview?.estimate == nil)
    }
}
