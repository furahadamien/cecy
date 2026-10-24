import Foundation
import Testing
@testable import cecy

/// Today follow-up questions and dynamic cards. Synthetic data only.
@MainActor struct TodayFollowUpEngineTests {
    private func day(_ key: Int) -> LocalDay { try! LocalDay(key: key) }
    private let longAgo = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
    /// Four 28-day cycles, then a 40-day cycle starting 2026-10-03.
    private var unusualPeriods: [Period] {
        [20260601, 20260629, 20260727, 20260824, 20261003].map { Period(start: day($0), createdAt: longAgo) }
    }

    private func input(_ snapshot: TrackerSnapshot, today: LocalDay, memory: FollowUpMemory = FollowUpMemory(),
                       minute: Int = 12 * 60) -> FollowUpInput {
        let overview = CycleCalculator.overview(periods: snapshot.periods, today: today, engine: EvidencePredictionEngine(),
                                                factors: P2Forecast.factors(for: snapshot))
        let forecast = CycleForecast.calculate(overview: overview, profile: snapshot.profile, periods: snapshot.periods,
                                               asOf: today, dailyBleeding: snapshot.dailyBleeding)
        return FollowUpInput(today: today, snapshot: snapshot, overview: overview, forecast: forecast, memory: memory,
                             minuteOfDay: minute, timeZone: .gmt)
    }

    private func kinds(_ input: FollowUpInput) -> [FollowUpKind] { FollowUpEngine.eligible(input).map(\.kind) }

    // MARK: Rules

    @Test func unusualCycleIsAskedUntilAFactorCoversIt() throws {
        var snapshot = TrackerSnapshot(periods: Array(unusualPeriods.dropLast()), onboardingCompletedAt: longAgo)
        // Before the long cycle is complete there's nothing unusual to ask about.
        #expect(!kinds(input(snapshot, today: day(20260930))).contains(.unusualCycle))
        snapshot.periods = unusualPeriods
        let today = day(20261004)
        let prompt = try #require(FollowUpEngine.eligible(input(snapshot, today: today)).first { $0.kind == .unusualCycle })
        #expect(prompt.title.contains("longer"))
        guard case .unusualCycle(let interval, let usual) = prompt.context else { Issue.record("Wrong context"); return }
        #expect(interval.length == 40 && usual == 28)
        // A new-cycle question isn't asked on top of the unusual-cycle question.
        #expect(!kinds(input(snapshot, today: today)).contains(.newCycle))
        #expect(!kinds(input(snapshot, today: day(20261030))).contains(.unusualCycle), "Only asked for three weeks.")
        snapshot.cycleFactors = [CycleFactor(kind: .illness, start: day(20260910), end: day(20260915))]
        #expect(!kinds(input(snapshot, today: today)).contains(.unusualCycle), "A recorded factor answers the question.")
    }

    @Test func newCycleIsAskedOnlyInItsFirstDays() {
        let periods = [20260601, 20260629, 20260727, 20260824, 20260921].map { Period(start: day($0), createdAt: longAgo) }
        let snapshot = TrackerSnapshot(periods: periods, onboardingCompletedAt: longAgo)
        #expect(kinds(input(snapshot, today: day(20260922))).contains(.newCycle))
        #expect(!kinds(input(snapshot, today: day(20260925))).contains(.newCycle))
    }

    @Test func openFactorWaitsAfterStillGoingAndEndsWhenAnswered() {
        let factor = CycleFactor(kind: .travel, start: day(20261001), createdAt: longAgo)
        var snapshot = TrackerSnapshot(onboardingCompletedAt: longAgo)
        snapshot.cycleFactors = [factor]
        #expect(!kinds(input(snapshot, today: day(20261005))).contains(.openFactor), "Too early to ask.")
        let today = day(20261010)
        #expect(kinds(input(snapshot, today: today)).contains(.openFactor))
        var memory = FollowUpMemory()
        memory.confirm("openFactor:\(factor.id.uuidString)", today: today)
        #expect(!kinds(input(snapshot, today: today, memory: memory)).contains(.openFactor))
        #expect(kinds(input(snapshot, today: day(20261017), memory: memory)).contains(.openFactor), "Asked again a week later.")
        snapshot.cycleFactors[0].end = day(20261008)
        #expect(!kinds(input(snapshot, today: day(20261017), memory: memory)).contains(.openFactor))
    }

    @Test func treatmentDoseNeedsReminderTimeAndNoLog() {
        let pill = TreatmentRecord(category: .contraception, name: "Synthetic pill", contraceptionType: .pill,
                                   start: day(20261001), reminderEnabled: true, reminderHour: 9, createdAt: longAgo)
        var snapshot = TrackerSnapshot(onboardingCompletedAt: longAgo)
        snapshot.treatments = [pill]
        let today = day(20261010)
        #expect(!kinds(input(snapshot, today: today, minute: 8 * 60)).contains(.treatmentDose))
        #expect(kinds(input(snapshot, today: today, minute: 10 * 60)).contains(.treatmentDose))
        snapshot.treatmentAdherence = [TreatmentAdherence(treatmentID: pill.id, day: today, state: .taken)]
        #expect(!kinds(input(snapshot, today: today, minute: 10 * 60)).contains(.treatmentDose))
        var weekly = pill
        weekly.cadence = .weekly
        snapshot.treatments = [weekly]
        snapshot.treatmentAdherence = []
        #expect(kinds(input(snapshot, today: day(20261008), minute: 10 * 60)).contains(.treatmentDose))
        #expect(!kinds(input(snapshot, today: day(20261009), minute: 10 * 60)).contains(.treatmentDose), "Not due on off days.")
    }

    @Test func treatmentAndLifeStageReviewsUseTheirOwnIntervals() {
        var snapshot = TrackerSnapshot(onboardingCompletedAt: longAgo)
        snapshot.treatments = [TreatmentRecord(category: .contraception, name: "Synthetic ring", contraceptionType: .ring,
                                               start: day(20260601), createdAt: longAgo)]
        snapshot.p2.lifeStages = [LifeStageEpisode(kind: .breastfeeding, start: day(20260901), createdAt: longAgo),
                                  LifeStageEpisode(kind: .cycleChange, start: day(20260901), createdAt: longAgo)]
        let prompts = FollowUpEngine.eligible(input(snapshot, today: day(20261010)))
        #expect(prompts.contains { $0.kind == .treatmentReview })
        let stages = prompts.compactMap { if case .lifeStage(let value) = $0.context { value.kind } else { nil } }
        #expect(stages == [.breastfeeding], "Cycle change is reviewed every 90 days, feeding every 30.")
        // A recent edit restarts the review clock.
        snapshot.treatments[0].updatedAt = ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")!
        #expect(!kinds(input(snapshot, today: day(20261010))).contains(.treatmentReview))
    }

    @Test func periodQuestionAppearsOnEstimatedDaysUntilAnswered() throws {
        let periods = [20260601, 20260629, 20260727, 20260824, 20260921].map { Period(start: day($0), end: try! day($0).adding(days: 4), createdAt: longAgo) }
        var snapshot = TrackerSnapshot(periods: periods, onboardingCompletedAt: longAgo)
        let probe = input(snapshot, today: day(20261019))
        let estimatedDay = try #require((0...10).compactMap { try? day(20261014).adding(days: $0) }
            .first { probe.forecast.bleeding(on: $0) != nil })
        let prompt = try #require(FollowUpEngine.eligible(input(snapshot, today: estimatedDay)).first)
        #expect(prompt.kind == .periodToday)
        snapshot.dailyBleeding = [DailyBleedingObservation(day: estimatedDay, state: .noBleeding)]
        #expect(!kinds(input(snapshot, today: estimatedDay)).contains(.periodToday))
    }

    @Test func windowPassedAsksOnceThenStaysQuietAfterAMonth() throws {
        let periods = [20260601, 20260629, 20260727, 20260824, 20260921].map { Period(start: day($0), end: try! day($0).adding(days: 4), createdAt: longAgo) }
        let snapshot = TrackerSnapshot(periods: periods, onboardingCompletedAt: longAgo)
        let base = input(snapshot, today: day(20261019))
        guard case .available(let estimate) = base.overview.prediction else { Issue.record("No estimate"); return }
        #expect(kinds(input(snapshot, today: try estimate.latest.adding(days: 2))).contains(.windowPassed))
        #expect(!kinds(input(snapshot, today: try estimate.latest.adding(days: 31))).contains(.windowPassed))
    }

    @Test func biomarkerFollowUpOnlyForRegularRecorders() {
        var snapshot = TrackerSnapshot(onboardingCompletedAt: longAgo)
        let today = day(20261010)
        snapshot.p2.biomarkers = [20261002, 20261005].map { BiomarkerEntry(day: day($0), kind: .lhTest, result: .negative) }
        #expect(!kinds(input(snapshot, today: today)).contains(.biomarker))
        snapshot.p2.biomarkers.append(BiomarkerEntry(day: day(20261008), kind: .lhTest, result: .negative))
        #expect(kinds(input(snapshot, today: today)).contains(.biomarker))
        snapshot.p2.biomarkers.append(BiomarkerEntry(day: today, kind: .lhTest, result: .negative))
        #expect(!kinds(input(snapshot, today: today)).contains(.biomarker))
    }

    // MARK: Limits, quiet times and memory

    @Test func onlyOneQuestionADayAndThreeAWeek() {
        var snapshot = TrackerSnapshot(onboardingCompletedAt: longAgo)
        snapshot.cycleFactors = [CycleFactor(kind: .travel, start: day(20261001), createdAt: longAgo)]
        let today = day(20261010)
        #expect(FollowUpEngine.next(input(snapshot, today: today)) != nil)
        var memory = FollowUpMemory()
        memory.markShown(today)
        #expect(FollowUpEngine.next(input(snapshot, today: today, memory: memory)) == nil, "One a day.")
        memory = FollowUpMemory(shownDays: [20261004, 20261006, 20261008])
        #expect(FollowUpEngine.next(input(snapshot, today: today, memory: memory)) == nil, "Three a week.")
        memory = FollowUpMemory(shownDays: [20261002, 20261006, 20261008])
        #expect(FollowUpEngine.next(input(snapshot, today: today, memory: memory)) != nil, "Older days fall out of the week.")
    }

    @Test func quietAfterSetupAndDuringPregnancyOrLoss() {
        var snapshot = TrackerSnapshot(onboardingCompletedAt: ISO8601DateFormatter().date(from: "2026-10-09T12:00:00Z")!)
        snapshot.cycleFactors = [CycleFactor(kind: .travel, start: day(20261001), createdAt: longAgo)]
        let today = day(20261010)
        #expect(FollowUpEngine.next(input(snapshot, today: today)) == nil, "Quiet in the first days after setup.")
        snapshot.onboardingCompletedAt = longAgo
        snapshot.cycleFactors.append(CycleFactor(kind: .pregnancyLoss, start: day(20260920), end: day(20260925)))
        snapshot.treatments = [TreatmentRecord(category: .medication, name: "Synthetic", start: day(20261001),
                                               reminderEnabled: true, reminderHour: 8, createdAt: longAgo)]
        #expect(kinds(input(snapshot, today: today)) == [.treatmentDose], "Only explicit reminders remain.")
        #expect(!FollowUpEngine.isSensitivePeriod(input(snapshot, today: day(20261030))), "Quiet for 30 days after the end.")
    }

    @Test func notNowWaitsLongerEachTimeAndTurnedOffKindsStayOff() throws {
        let today = day(20261010)
        var memory = FollowUpMemory()
        memory.snooze("a", today: today)
        #expect(memory.snoozes["a"]?.untilDay == 20261013)
        memory.snooze("a", today: today)
        #expect(memory.snoozes["a"]?.untilDay == 20261017)
        memory.snooze("a", today: today)
        memory.snooze("a", today: today)
        #expect(memory.snoozes["a"]?.untilDay == 20261031 && memory.snoozes["a"]?.count == 4)
        #expect(memory.isWaiting("a", today: today) && !memory.isWaiting("a", today: day(20261031)))
        memory.resolve("b", today: today)
        #expect(memory.isWaiting("b", today: day(20271010)))

        var snapshot = TrackerSnapshot(onboardingCompletedAt: longAgo)
        snapshot.cycleFactors = [CycleFactor(kind: .travel, start: day(20261001), createdAt: longAgo)]
        memory.disabledKinds = [.openFactor]
        #expect(FollowUpEngine.next(input(snapshot, today: today, memory: memory)) == nil)
        memory.resetSkipped()
        #expect(memory.snoozes.isEmpty && memory.resolvedDays.isEmpty && memory.disabledKinds.isEmpty)
        #expect(FollowUpEngine.next(input(snapshot, today: today, memory: memory)) != nil)
    }

    @Test func memoryIsPrunedAndValidatedAndOlderPreferencesStillLoad() throws {
        var memory = FollowUpMemory(shownDays: [20260901, 20261005, 20261010])
        memory.snoozes["old"] = FollowUpSnooze(untilDay: 20250101, count: 1)
        memory.prune(today: day(20261010))
        #expect(memory.shownDays == [20261005, 20261010] && memory.snoozes.isEmpty)
        try memory.validate()
        #expect(throws: (any Error).self) { try FollowUpMemory(shownDays: [20261399]).validate() }

        var preferences = PrivacyPreferences()
        preferences.followUpMemory = memory
        preferences.estimateShift = EstimateShift(fromKey: 20261019, toKey: 20261021, dayKey: 20261010, reason: .period)
        let data = try JSONEncoder().encode(preferences)
        #expect(try JSONDecoder().decode(PrivacyPreferences.self, from: data) == preferences)
        // A preferences file from before this feature has none of the new keys.
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["followUpsEnabled", "followUpMemory", "estimateCenterKey", "estimateShift"] { legacy[key] = nil }
        let decoded = try JSONDecoder().decode(PrivacyPreferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.followUpMemory == nil && decoded.followUpsEnabled == nil)
        try decoded.validate()
    }

    @Test func promptsNeverClaimMedicalMeaning() {
        var snapshot = TrackerSnapshot(periods: unusualPeriods + [Period(start: day(20261112), createdAt: longAgo)],
                                       onboardingCompletedAt: longAgo)
        snapshot.cycleFactors = [CycleFactor(kind: .travel, start: day(20261113), createdAt: longAgo)]
        let prompts = FollowUpEngine.candidates(input(snapshot, today: day(20261125)))
        #expect(!prompts.isEmpty)
        for prompt in prompts {
            let text = [prompt.title, prompt.message, prompt.explainer, prompt.reason].joined(separator: " ").lowercased()
            for word in ["pregnan", "diagnos", "abnormal", "should see", "fertile"] {
                #expect(!text.contains(word), "\(prompt.kind): \(word)")
            }
        }
    }
}

@MainActor struct TodayHighlightTests {
    private func day(_ key: Int) -> LocalDay { try! LocalDay(key: key) }
    private let periods = [20260601, 20260629, 20260727, 20260824, 20260921].map { Period(start: try! LocalDay(key: $0)) }

    private func overview(_ snapshot: TrackerSnapshot, _ today: LocalDay) -> CycleOverview {
        CycleCalculator.overview(periods: snapshot.periods, today: today, engine: EvidencePredictionEngine(),
                                 factors: P2Forecast.factors(for: snapshot))
    }

    @Test func recapAfterANewPeriodThenEchoLaterInTheCycle() {
        var snapshot = TrackerSnapshot(periods: periods)
        snapshot.periods[3].end = day(20260828)
        snapshot.symptoms = [SymptomEntry(day: day(20260825), kind: .cramps), SymptomEntry(day: day(20260826), kind: .cramps),
                             SymptomEntry(day: day(20260902), kind: .headache)]
        let recapDay = day(20260922)
        let recap = TodayHighlights.make(today: recapDay, snapshot: snapshot, overview: overview(snapshot, recapDay), shift: nil)
        #expect(recap.first == .cycleRecap(length: 28, periodDays: 5, symptoms: [.cramps, .headache], factors: []))
        // Cycle day 10 of the current cycle lines up with Sep 2 in the previous one.
        let echoDay = day(20260930)
        let echo = TodayHighlights.make(today: echoDay, snapshot: snapshot, overview: overview(snapshot, echoDay), shift: nil)
        #expect(echo.contains(.lastCycleEcho(cycleDay: 10, symptoms: [.headache])))
        #expect(echo.count <= TodayHighlights.maximumCards)
    }

    @Test func windowApproachingAndActiveContext() throws {
        var snapshot = TrackerSnapshot(periods: periods)
        let base = overview(snapshot, day(20261001))
        guard case .available(let estimate) = base.prediction else { Issue.record("No estimate"); return }
        let today = try estimate.earliest.adding(days: -2)
        snapshot.cycleFactors = [CycleFactor(kind: .travel, start: try today.adding(days: -1))]
        snapshot.p2.lifeStages = [LifeStageEpisode(kind: .cycleChange, start: day(20260101))]
        let cards = TodayHighlights.make(today: today, snapshot: snapshot, overview: overview(snapshot, today), shift: nil)
        #expect(cards.first == .windowApproaching(days: 2, earliest: estimate.earliest, latest: estimate.latest))
        let context = TodayHighlights.activeContext(today: today, snapshot: snapshot, overview: overview(snapshot, today))
        guard case .activeContext(_, let factors, let stages) = context else { Issue.record("No context"); return }
        #expect(factors == [.travel] && stages == [.cycleChange], "The cycle-change stage isn't repeated as a factor.")
    }

    @Test func coverageCountsUniqueLoggedDays() {
        var snapshot = TrackerSnapshot(periods: [Period(start: day(20261001), end: day(20261003))])
        snapshot.symptoms = [SymptomEntry(day: day(20261003), kind: .cramps), SymptomEntry(day: day(20261005), kind: .fatigue)]
        snapshot.dailyBleeding = [DailyBleedingObservation(day: day(20261006), state: .noBleeding)]
        // Window Sep 30 – Oct 6: Oct 1, 2, 3 (period), 5, 6.
        #expect(TodayHighlights.coverage(today: day(20261006), snapshot: snapshot) == .coverage(logged: 5, days: 7))
    }

    @Test func estimateMovedShowsForTwoDaysAndExplainsWhy() throws {
        let before = TrackerSnapshot(periods: Array(periods.dropLast()))
        let after = TrackerSnapshot(periods: periods)
        let shift = try #require(EstimateShift.detect(previousCenter: day(20260921), newCenter: day(20261019),
                                                      previous: before, current: after, today: day(20260921)))
        #expect(shift.reason == .period)
        #expect(EstimateShift.detect(previousCenter: day(20261019), newCenter: day(20261019), previous: before, current: after,
                                     today: day(20260921)) == nil)
        let moved = EstimateShift(fromKey: 20261017, toKey: 0, dayKey: 20261001, reason: .factor)
        let snapshot = TrackerSnapshot(periods: periods)
        let today = day(20261001)
        let current = overview(snapshot, today)
        guard case .available(let estimate) = current.prediction else { Issue.record("No estimate"); return }
        var valid = moved
        valid.toKey = estimate.center.key
        let expected = TodayHighlight.estimateMoved(days: abs(day(20261017).days(until: estimate.center)),
                                                    earlier: day(20261017) > estimate.center, reason: .factor, center: estimate.center)
        if estimate.center != day(20261017) {
            #expect(TodayHighlights.estimateMoved(today: today, overview: current, shift: valid) == expected)
            #expect(TodayHighlights.estimateMoved(today: day(20261004), overview: overview(snapshot, day(20261004)), shift: valid) == nil,
                    "Hidden after two days.")
        }
        #expect(TodayHighlights.estimateMoved(today: today, overview: current, shift: moved) == nil, "Stale once the estimate moves again.")
    }
}

@MainActor struct TodayFollowUpSessionTests {
    private let today = try! LocalDay(key: 20261010)
    private let now = ISO8601DateFormatter().date(from: "2026-10-10T12:00:00Z")!
    private let setup = ISO8601DateFormatter().date(from: "2026-09-01T12:00:00Z")!

    private func session(_ factors: [CycleFactor] = []) throws -> TrackerSession {
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add([Period(start: try LocalDay(key: 20260901))], completingOnboarding: true,
                               today: try LocalDay(key: 20260901), now: setup)
        for factor in factors { _ = try repository.saveCycleFactor(factor, today: today, now: setup) }
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt })
        session.load()
        return session
    }

    @Test func answeringSavesTheRecordAndTheQuestionGoesAway() throws {
        let travel = CycleFactor(kind: .travel, start: try LocalDay(key: 20261001), createdAt: setup)
        let session = try session([travel])
        #expect(session.nextFollowUp() != nil)
        let open = try #require(session.followUpInput())
        #expect(FollowUpEngine.eligible(open).contains { $0.kind == .openFactor })
        var ended = travel
        ended.end = try LocalDay(key: 20261008)
        #expect(session.saveCycleFactor(ended) == nil)
        #expect(session.snapshot.cycleFactors.first?.end == ended.end)
        let after = try #require(session.followUpInput())
        #expect(!FollowUpEngine.eligible(after).contains { $0.kind == .openFactor })
    }

    @Test func shownQuestionsCountTowardTheDailyLimitAndDeleteAllClearsMemory() async throws {
        let session = try session([CycleFactor(kind: .travel, start: try LocalDay(key: 20261001), createdAt: setup)])
        #expect(session.nextFollowUp() != nil)
        #expect(session.markFollowUpShown())
        #expect(session.nextFollowUp() == nil)
        let input = try #require(session.followUpInput())
        let prompt = try #require(FollowUpEngine.eligible(input).first)
        session.disableFollowUpKind(prompt.kind)
        #expect(session.privacy.followUpMemory.disabledKinds == [prompt.kind])
        let remaining = try #require(session.followUpInput())
        #expect(!FollowUpEngine.eligible(remaining).contains { $0.kind == prompt.kind })
        #expect(await session.deleteAllAndWait() == nil)
        #expect(session.privacy.preferences.followUpMemory == nil && session.privacy.preferences.estimateShift == nil)
    }

    @Test func turningQuestionsOffStopsThem() throws {
        let session = try session([CycleFactor(kind: .travel, start: try LocalDay(key: 20261001), createdAt: setup)])
        #expect(session.privacy.setFollowUpsEnabled(false) == nil)
        #expect(session.nextFollowUp() == nil)
        #expect(session.privacy.setFollowUpsEnabled(true) == nil)
        #expect(session.nextFollowUp() != nil)
    }

    @Test func savingAPeriodRecordsWhyTheEstimateMoved() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let starts = [20260601, 20260629, 20260727, 20260824].map { try! LocalDay(key: $0) }
        _ = try repository.add(starts.map { Period(start: $0) }, completingOnboarding: true, today: try LocalDay(key: 20260901), now: setup)
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt })
        session.load()
        let before = try #require(session.overview?.estimate?.center)
        #expect(session.privacy.preferences.estimateCenterKey == before.key)
        #expect(session.privacy.preferences.estimateShift == nil, "Loading never counts as a move.")
        #expect(session.save([Period(start: try LocalDay(key: 20260925))]) == nil)
        let after = try #require(session.overview?.estimate?.center)
        #expect(after != before)
        #expect(session.privacy.preferences.estimateShift == EstimateShift(fromKey: before.key, toKey: after.key,
                                                                           dayKey: today.key, reason: .period))
    }
}
