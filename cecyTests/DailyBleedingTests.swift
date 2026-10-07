import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct DailyBleedingDomainTests {
    private let day = try! LocalDay(key: 20261007)

    @Test func absenceAndAllExplicitStatesRemainDistinct() throws {
        #expect(TrackerSnapshot().dailyBleeding.isEmpty)
        for state in DailyBleedingState.allCases {
            let answer = DailyBleedingObservation(day: day, state: state)
            try DailyBleedingValidation.validate([answer], periods: [], asOf: day)
            #expect(TrackerSnapshot(dailyBleeding: [answer]) != TrackerSnapshot())
        }
        #expect(TrackerSnapshot(symptoms: [SymptomEntry(day: day, kind: .headache)]).dailyBleeding.isEmpty)
    }

    @Test func duplicateDayIDFlowAndFutureValidation() throws {
        let answer = DailyBleedingObservation(day: day, state: .bleeding, flow: .light)
        #expect(throws: DailyBleedingError.duplicateDay) {
            try DailyBleedingValidation.validate([answer, DailyBleedingObservation(day: day, state: .unsure)], periods: [])
        }
        #expect(throws: TrackingError.invalidData) { try DailyBleedingValidation.validate([answer, answer], periods: []) }
        for state in [DailyBleedingState.spotting, .noBleeding, .unsure] {
            #expect(throws: DailyBleedingError.invalidFlow) {
                try DailyBleedingValidation.validate([DailyBleedingObservation(day: day, state: state, flow: .heavy)], periods: [])
            }
        }
        #expect(throws: TrackingError.futureDate) {
            try DailyBleedingValidation.validate([answer], periods: [], asOf: day.adding(days: -1))
        }
        // Loading remains independent of today's time zone.
        try DailyBleedingValidation.validate([answer], periods: [])
        var invalid = answer
        invalid.updatedAt = Date(timeIntervalSinceReferenceDate: .infinity)
        #expect(throws: TrackingError.invalidData) { try DailyBleedingValidation.validate([invalid], periods: []) }
    }

    @Test func explicitRangesConflictEvenWithoutLinksButUnsureIsNotNegative() throws {
        let start = try day.adding(days: -3)
        let period = Period(start: start, end: day)
        for date in [start, try start.adding(days: 1), day] {
            for state in [DailyBleedingState.spotting, .noBleeding] {
                #expect(throws: DailyBleedingError.episodeConflict) {
                    try DailyBleedingValidation.validate([DailyBleedingObservation(day: date, state: state)], periods: [period])
                }
            }
            try DailyBleedingValidation.validate([DailyBleedingObservation(day: date, state: .unsure)], periods: [period])
            try DailyBleedingValidation.validate([DailyBleedingObservation(day: date, state: .bleeding, periodID: period.id)], periods: [period])
        }
        try DailyBleedingValidation.validate([DailyBleedingObservation(day: start.adding(days: -1), state: .noBleeding)], periods: [period])
    }

    @Test func unknownEndDoesNotExtendEvidenceAndLinksMustMatch() throws {
        let period = Period(start: try day.adding(days: -1))
        try DailyBleedingValidation.validate([DailyBleedingObservation(day: day, state: .spotting)], periods: [period])
        for answer in [DailyBleedingObservation(day: day, state: .bleeding, periodID: period.id),
                       DailyBleedingObservation(day: period.start, state: .unsure, periodID: period.id),
                       DailyBleedingObservation(day: period.start, state: .bleeding, periodID: UUID())] {
            #expect(throws: DailyBleedingError.invalidAssociation) { try DailyBleedingValidation.validate([answer], periods: [period]) }
        }
    }

    @Test(arguments: [20240229, 20260308, 20261101, 20261231])
    func civilDaysSurviveCalendarBoundaries(key: Int) throws {
        let date = try LocalDay(key: key)
        let answer = DailyBleedingObservation(day: date, state: .noBleeding)
        try DailyBleedingValidation.validate([answer], periods: [], asOf: date)
        #expect(try LocalDay(key: answer.day.key) == date)
        #expect(try date.adding(days: 1).days(until: date) == -1)
    }

    @Test func exportsVersionOnlyNewContentAndPreservePrivacyAndAIAllowlist() throws {
        let period = Period(start: day, notes: "PRIVATE PERIOD NOTE")
        var profile = LocalProfile(); profile.preferredName = "PRIVATE IDENTITY"; profile.birthDayKey = 19950101
        var snapshot = TrackerSnapshot(periods: [period], profile: profile,
            sexualActivities: [SexualActivityEntry(day: day, activities: [.other], notes: "PRIVATE ACTIVITY")])
        let request = try AIContextBuilder.recordInsights(snapshot: snapshot, today: day)
        let old = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: day.formattingDate)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(TrackerExport.Document.self, from: old).formatVersion == 1)
        #expect(!String(decoding: old, as: UTF8.self).contains("dailyBleeding"))
        snapshot.dailyBleeding = [DailyBleedingObservation(day: day, state: .bleeding, flow: .heavy, periodID: period.id)]
        let data = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: day.formattingDate)
        let document = try decoder.decode(TrackerExport.Document.self, from: data)
        #expect(document.formatVersion == 7 && document.dailyBleeding?.count == 1)
        #expect(document.dailyBleeding?.first?.date == "2026-10-07")
        #expect(document.dailyBleeding?.first?.periodID == period.id && document.dailyBleeding?.first?.flow == "heavy")
        #expect(document.profile == nil && document.sexualActivities == nil && document.periods.first?.notes == nil)
        #expect(!String(decoding: data, as: UTF8.self).contains("PRIVATE"))
        let included = try TrackerExport.encode(snapshot: snapshot, includeNotes: true, generatedAt: day.formattingDate,
                                               includeProfile: true, includeSexualActivity: true)
        let all = try decoder.decode(TrackerExport.Document.self, from: included)
        #expect(all.profile?.preferredName == profile.preferredName && all.sexualActivities?.count == 1)
        #expect(all.periods.first?.notes == period.notes)
        #expect(try AIContextBuilder.recordInsights(snapshot: snapshot, today: day) == request)
        #expect(throws: AIContextError.insufficientRecords) {
            try AIContextBuilder.recordInsights(snapshot: TrackerSnapshot(dailyBleeding: snapshot.dailyBleeding), today: day)
        }
    }
}

@MainActor struct DailyBleedingRepositoryTests {
    private let today = try! LocalDay(key: 20261007)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case disk }

    @Test func dailyCRUDDoesNotCreateEpisodesOrChangeOtherRecords() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let symptom = SymptomEntry(day: today, kind: .headache, createdAt: now)
        _ = try repository.saveSymptom(symptom, editing: false, today: today, now: now)
        let activity = SexualActivityEntry(day: today, activities: [.other], createdAt: now)
        _ = try repository.saveSexualActivity(activity, editing: false, today: today, now: now)
        var answer = DailyBleedingObservation(day: today, state: .spotting)
        let first = try repository.saveDailyBleeding(answer, editing: false, today: today, now: now)
        #expect(first.periods.isEmpty && first.dailyBleeding.first?.createdAt == now)
        #expect(throws: DailyBleedingError.duplicateDay) {
            try repository.saveDailyBleeding(DailyBleedingObservation(day: today, state: .unsure), editing: false, today: today, now: now)
        }
        #expect(throws: TrackingError.invalidData) { try repository.saveDailyBleeding(answer, editing: false, today: today, now: now) }
        answer.state = .noBleeding
        let edited = try repository.saveDailyBleeding(answer, editing: true, today: today, now: now.addingTimeInterval(60))
        #expect(edited.dailyBleeding.first?.id == answer.id && edited.dailyBleeding.first?.createdAt == now)
        #expect(edited.dailyBleeding.first?.updatedAt == now.addingTimeInterval(60))
        #expect(try repository.load() == edited)
        let deleted = try repository.deleteDailyBleeding(id: answer.id)
        #expect(deleted.dailyBleeding.isEmpty && deleted.periods.isEmpty)
        #expect(deleted.symptoms == [symptom] && deleted.sexualActivities == [activity])
        #expect(throws: TrackingError.missingRecord) { try repository.saveDailyBleeding(answer, editing: true, today: today, now: now) }
    }

    @Test func allPeriodWritersRejectContradictionsWithoutChangingAnything() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let answer = DailyBleedingObservation(day: today, state: .noBleeding)
        let original = try repository.saveDailyBleeding(answer, editing: false, today: today, now: now)
        #expect(throws: DailyBleedingError.episodeConflict) {
            try repository.add([Period(start: today)], completingOnboarding: true, today: today, now: now)
        }
        var draft = OnboardingDraft()
        draft.profile.preferredName = "Synthetic"; draft.profile.birthDayKey = 19950101
        draft.profile.typicalCycleDays = 28; draft.profile.typicalPeriodDays = 5
        draft.periods = [Period(start: today)]
        #expect(throws: DailyBleedingError.episodeConflict) { try repository.prepareOnboarding(draft, today: today) }
        let sample = HealthFlowSample(id: UUID(), sourceName: "Synthetic", sourceBundle: "test.source", start: now,
                                     end: now, timeZoneIdentifier: "GMT", flowValue: 2, markedCycleStart: true)
        #expect(throws: DailyBleedingError.episodeConflict) {
            try repository.importHealthStart(sample, confirmedStart: today, today: today, now: now, timeZone: .gmt)
        }
        #expect(try repository.load() == original)
        var period = Period(start: try today.adding(days: -1))
        let beforeEdit = try repository.add([period], completingOnboarding: false, today: today, now: now)
        period.end = today
        #expect(throws: DailyBleedingError.episodeConflict) { try repository.update(period, today: today, now: now) }
        #expect(try repository.load() == beforeEdit)
    }

    @Test func reviewedBoundaryCorrectionCommitsBothSidesAndPreservesEpisodeFlow() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let start = try today.adding(days: -2)
        let period = Period(start: start, end: today, flow: .heavy, notes: "Synthetic", createdAt: now)
        _ = try repository.add([period], completingOnboarding: true, today: today, now: now)
        let answer = DailyBleedingObservation(day: today, state: .bleeding, flow: .light, periodID: period.id)
        let original = try repository.saveDailyBleeding(answer, editing: false, today: today, now: now)
        var shortened = period; shortened.end = try today.adding(days: -1)
        #expect(throws: DailyBleedingError.invalidAssociation) { try repository.update(shortened, today: today, now: now) }
        var review = BleedingReconciliation(snapshot: original)
        review.periods = [shortened]
        review.observations[0].periodID = nil
        review.observations[0].state = .spotting
        review.observations[0].flow = nil
        let saved = try repository.reconcileBleeding(review, today: today, now: now.addingTimeInterval(60))
        #expect(saved.periods.first?.id == period.id && saved.periods.first?.flow == .heavy)
        #expect(saved.periods.first?.createdAt == now && saved.periods.first?.updatedAt == now.addingTimeInterval(60))
        #expect(saved.dailyBleeding.first?.id == answer.id && saved.dailyBleeding.first?.state == .spotting)
        #expect(try repository.load() == saved)
    }

    @Test func episodeDeleteRequiresReviewAndDefaultsToRetainingDailyAnswers() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let period = Period(start: today, createdAt: now)
        _ = try repository.add([period], completingOnboarding: true, today: today, now: now)
        let original = try repository.saveDailyBleeding(DailyBleedingObservation(day: today, state: .bleeding, periodID: period.id),
                                                       editing: false, today: today, now: now)
        #expect(throws: DailyBleedingError.invalidAssociation) { try repository.delete(id: period.id) }
        let review = try BleedingReconciliation.retainingDailyRecordsWhenDeleting(period.id, from: original)
        #expect(try repository.load() == original) // A preview is not a mutation.
        let saved = try repository.reconcileBleeding(review, today: today, now: now.addingTimeInterval(60))
        #expect(saved.periods.isEmpty && saved.dailyBleeding.count == 1)
        #expect(saved.dailyBleeding[0].id == original.dailyBleeding[0].id && saved.dailyBleeding[0].periodID == nil)
        #expect(saved.dailyBleeding[0].createdAt == now && saved.dailyBleeding[0].updatedAt == now.addingTimeInterval(60))
    }

    @Test func staleReviewDetectsNewDailyAndPeriodRecordsButPreservesUnrelatedEdits() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let emptyReview = BleedingReconciliation(snapshot: try repository.load())
        let saved = try repository.saveDailyBleeding(DailyBleedingObservation(day: today, state: .unsure), editing: false, today: today, now: now)
        #expect(throws: DailyBleedingError.staleReview) { try repository.reconcileBleeding(emptyReview, today: today, now: now) }
        var review = BleedingReconciliation(snapshot: saved)
        review.observations[0].state = .bleeding
        let symptom = SymptomEntry(day: today, kind: .headache, createdAt: now)
        _ = try repository.saveSymptom(symptom, editing: false, today: today, now: now)
        let corrected = try repository.reconcileBleeding(review, today: today, now: now)
        #expect(corrected.symptoms == [symptom])
        let prior = BleedingReconciliation(snapshot: corrected)
        let current = try repository.add([Period(start: today)], completingOnboarding: false, today: today, now: now)
        #expect(throws: DailyBleedingError.staleReview) { try repository.reconcileBleeding(prior, today: today, now: now) }
        #expect(try repository.load() == current)
    }

    @Test func failedDailyCreateEditDeleteAndResetRollBackAndRetry() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }; try $0.save()
        })
        var answer = DailyBleedingObservation(day: today, state: .unsure)
        #expect(throws: Failure.disk) { try repository.saveDailyBleeding(answer, editing: false, today: today, now: now) }
        #expect(try repository.load() == TrackerSnapshot())
        fail = false
        let original = try repository.saveDailyBleeding(answer, editing: false, today: today, now: now)
        fail = true
        answer.state = .noBleeding
        #expect(throws: Failure.disk) { try repository.saveDailyBleeding(answer, editing: true, today: today, now: now) }
        #expect(throws: Failure.disk) { try repository.deleteDailyBleeding(id: answer.id) }
        #expect(throws: Failure.disk) { try repository.deleteAll() }
        #expect(try repository.load() == original)
        fail = false
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func failedCoupledReconciliationNeverPartiallyCommitsOrLosesReceipt() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let sample = HealthFlowSample(id: UUID(), sourceName: "Synthetic", sourceBundle: "test.source", start: now,
                                     end: now, timeZoneIdentifier: "GMT", flowValue: 3, markedCycleStart: true)
        let imported = try memory.importHealthStart(sample, confirmedStart: today, today: today, now: now, timeZone: .gmt)
        let period = try #require(imported.periods.first)
        let original = try memory.saveDailyBleeding(DailyBleedingObservation(day: today, state: .bleeding, periodID: period.id),
                                                   editing: false, today: today, now: now)
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }; try $0.save()
        })
        let review = try BleedingReconciliation.retainingDailyRecordsWhenDeleting(period.id, from: original)
        #expect(throws: Failure.disk) { try repository.reconcileBleeding(review, today: today, now: now) }
        #expect(try repository.load() == original)
        fail = false
        let saved = try repository.reconcileBleeding(review, today: today, now: now)
        #expect(saved.periods.isEmpty && saved.dailyBleeding[0].periodID == nil && saved.healthImports == original.healthImports)
        #expect(throws: HealthImportError.alreadyReviewed) {
            try repository.importHealthStart(sample, confirmedStart: today, today: today, now: now, timeZone: .gmt)
        }
        #expect(try repository.load() == saved)
    }

    @Test func sessionPublishesOnlyCommittedAnswersAndLeavesCycleEvidenceUnchanged() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let period = Period(start: try today.adding(days: -28), createdAt: now)
        _ = try memory.add([period, Period(start: today, createdAt: now)], completingOnboarding: true, today: today, now: now)
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }; try $0.save()
        })
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt })
        let answer = DailyBleedingObservation(day: today, state: .bleeding)
        #expect(session.saveDailyBleeding(answer) != nil) // Not loaded.
        session.load()
        let original = session.snapshot
        let overview = session.overview
        let request = session.dailyInsightRequest
        #expect(session.saveDailyBleeding(answer) != nil)
        #expect(session.snapshot == original && session.confirmation == nil && !session.isSaving)
        fail = false
        #expect(session.saveDailyBleeding(answer) == nil)
        #expect(session.snapshot.dailyBleeding.count == 1 && session.overview == overview && session.dailyInsightRequest == request)
        #expect(session.deleteDailyBleeding(id: answer.id) == nil)
        #expect(session.snapshot == original)
    }

    @Test func reviewedCreationIsAtomicAndDailyDeletionKeepsTheEpisode() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }; try $0.save()
        })
        let period = Period(start: today)
        let answer = DailyBleedingObservation(day: today, state: .bleeding, periodID: period.id)
        var review = BleedingReconciliation(snapshot: TrackerSnapshot())
        review.periods = [period]; review.observations = [answer]
        #expect(throws: Failure.disk) { try repository.reconcileBleeding(review, today: today, now: now) }
        #expect(try repository.load() == TrackerSnapshot())
        fail = false
        let saved = try repository.reconcileBleeding(review, today: today, now: now)
        #expect(saved.periods.count == 1 && saved.dailyBleeding.count == 1)
        #expect(saved.periods[0].createdAt == now && saved.dailyBleeding[0].createdAt == now)
        let deleted = try repository.deleteDailyBleeding(id: answer.id)
        #expect(deleted.periods == saved.periods && deleted.dailyBleeding.isEmpty)
    }

    @Test func invalidReviewAndFutureAnswersNeverMutateStorage() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let answer = DailyBleedingObservation(day: today, state: .noBleeding)
        let original = try repository.saveDailyBleeding(answer, editing: false, today: today, now: now)
        var review = BleedingReconciliation(snapshot: original)
        review.periods = [Period(start: today)]
        #expect(throws: DailyBleedingError.episodeConflict) { try repository.reconcileBleeding(review, today: today, now: now) }
        review.periods = []
        review.observations[0].periodID = UUID()
        #expect(throws: DailyBleedingError.invalidAssociation) { try repository.reconcileBleeding(review, today: today, now: now) }
        let future = try DailyBleedingObservation(day: today.adding(days: 1), state: .unsure)
        #expect(throws: TrackingError.futureDate) { try repository.saveDailyBleeding(future, editing: false, today: today, now: now) }
        #expect(try repository.load() == original)
    }

    @Test func malformedRawDailyRecordsFailClosedButExplicitResetStillWorks() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let context = ModelContext(memory.container)
        let record = TrackerSchemaV7.DailyBleedingRecord(DailyBleedingObservation(day: today, state: .unsure))
        record.stateRaw = "unsupported"
        context.insert(record); try context.save()
        let repository = SwiftDataPeriodRepository(container: memory.container)
        #expect(throws: TrackingError.invalidData) { try repository.load() }
        #expect(try repository.deleteAll() == TrackerSnapshot())
        #expect(try repository.load() == TrackerSnapshot())
    }
}
