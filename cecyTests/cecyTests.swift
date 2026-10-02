//
//  cecyTests.swift
//  cecyTests
//
//  Created by Furaha Damien on 9/29/26.
//

import Foundation
import SwiftData
import Testing
@testable import cecy

@MainActor
struct TrackerPersistenceTests {
    private let now = Date(timeIntervalSince1970: 1_790_683_200)
    private func day(_ key: Int) throws -> LocalDay { try LocalDay(key: key) }
    private func fixture() throws -> [Period] {
        try [20260607, 20260705, 20260804, 20260902].map { Period(start: try day($0), createdAt: now) }
    }
    private enum Failure: Error { case diskFull }
    @MainActor private final class Availability { var shouldFail = true }

    @Test(arguments: [false, true]) func fileStoreSurvivesReopening(withHistory: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("roundtrip.store")
        let periods = withHistory ? try fixture() : []
        do {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            #expect(try repository.load() == TrackerSnapshot())
            _ = try repository.add(periods.reversed(), completingOnboarding: true, today: day(20260929), now: now)
        }
        let snapshot = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(snapshot.periods == periods)
        #expect(snapshot.onboardingCompletedAt == now)
    }

    @Test func failedBatchRollsBackRecordsAndCompletionThenRetries() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container) { context in
            if fail { throw Failure.diskFull }
            try context.save()
        }
        let periods = try fixture()
        #expect(throws: Failure.self) {
            try repository.add(periods, completingOnboarding: true, today: day(20260929), now: now)
        }
        #expect(try repository.load() == TrackerSnapshot())
        fail = false
        let saved = try repository.add(periods, completingOnboarding: true, today: day(20260929), now: now)
        #expect(saved.periods == periods)
        #expect(saved.onboardingCompletedAt == now)
        #expect(try repository.load() == saved)
    }

    @Test func validationNeverPartiallySaves() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let periods = try fixture()
        let original = try repository.add(periods, completingOnboarding: true, today: day(20260929), now: now)
        #expect(throws: TrackingError.duplicateStart) {
            try repository.add([Period(start: day(20260902))], completingOnboarding: false, today: day(20260929), now: now)
        }
        #expect(throws: TrackingError.invalidData) {
            try repository.add([periods[0]], completingOnboarding: false, today: day(20260929), now: now)
        }
        #expect(throws: TrackingError.futureDate) {
            try repository.add([Period(start: day(20260930))], completingOnboarding: false, today: day(20260929), now: now)
        }
        #expect(try repository.load() == original)
    }

    @Test func invalidOnboardingBatchKeepsCompletionUnset() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let same = try day(20260902)
        #expect(throws: TrackingError.duplicateStart) {
            try repository.add([Period(start: same), Period(start: same)], completingOnboarding: true,
                               today: day(20260929), now: now)
        }
        #expect(try repository.load() == TrackerSnapshot())
    }

    @Test func correctionPreservesIdentityAndRecomputesIntervals() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let periods = try fixture()
        _ = try repository.add(periods, completingOnboarding: true, today: day(20260929), now: now)
        var changed = periods[2]
        changed.start = try day(20260805)
        changed.end = try day(20260809)
        let later = now.addingTimeInterval(10)
        let snapshot = try repository.update(changed, today: day(20260929), now: later)
        let saved = try #require(snapshot.periods.first { $0.id == changed.id })
        #expect(saved.createdAt == changed.createdAt)
        #expect(saved.updatedAt == later)
        #expect(saved.duration == 5)
        let overview = CycleCalculator.overview(periods: snapshot.periods, today: try day(20260929))
        #expect(overview.intervals.map(\.length) == [28, 31, 28])
        #expect(overview.estimate?.sourceLengths == [28, 31, 28])
        let deleted = try repository.delete(id: periods[0].id)
        #expect(deleted.periods.count == 3)
        #expect(deleted.onboardingCompletedAt == now)
        #expect(CycleCalculator.overview(periods: deleted.periods, today: try day(20260929)).estimate?.sourceLengths == [31, 28])
    }

    @Test func failedUpdateAndDeleteKeepCommittedRecords() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let original = try memory.add(fixture(), completingOnboarding: true, today: day(20260929), now: now)
        let repository = SwiftDataPeriodRepository(container: memory.container) { _ in throw Failure.diskFull }
        var changed = original.periods[0]
        changed.end = changed.start
        #expect(throws: Failure.self) { try repository.update(changed, today: day(20260929), now: now) }
        #expect(try repository.load() == original)
        #expect(throws: Failure.self) { try repository.delete(id: changed.id) }
        #expect(try repository.load() == original)
    }

    @Test func malformedStoredDayIsNotSilentlySkipped() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let context = ModelContext(repository.container)
        let record = TrackerSchemaV2.PeriodRecord(Period(start: try day(20260902)))
        record.startKey = 20260230
        context.insert(record)
        try context.save()
        #expect(throws: TrackingError.invalidDay) { try repository.load() }
        #expect(try context.fetchCount(FetchDescriptor<TrackerSchemaV2.PeriodRecord>()) == 1)
    }

    @Test func conflictingCompletionRecordsAreRejected() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let context = ModelContext(repository.container)
        context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
        context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
        try context.save()
        #expect(throws: TrackingError.invalidData) { try repository.load() }
    }

    @Test func startupFailureCanRetryWithoutEmptyFallback() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let expected = try repository.add(fixture(), completingOnboarding: true, today: day(20260929), now: now)
        let availability = Availability()
        let session = TrackerSession(repository: {
            if availability.shouldFail { throw Failure.diskFull }
            return repository
        }, clock: { self.now })
        session.load()
        #expect(session.phase == .failed)
        #expect(session.failureMessage != nil)
        #expect(session.save([]) != nil)
        availability.shouldFail = false
        session.load()
        #expect(session.phase == .loaded)
        #expect(session.snapshot == expected)
        #expect(session.failureMessage == nil)
    }

    @Test func saveFailurePreservesSnapshotAndDraft() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let repository = SwiftDataPeriodRepository(container: memory.container) { _ in throw Failure.diskFull }
        let today = try day(20260929)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        let draft = PeriodDraft(period: Period(start: today))
        draft.includesEnd = true
        #expect(session.save([draft.period], completingOnboarding: true) != nil)
        #expect(session.snapshot == TrackerSnapshot())
        #expect(session.confirmation == nil)
        #expect(!session.isSaving)
        #expect(draft.includesEnd)
        #expect(draft.period.end == today)
    }

    @Test func clockRefreshPreservesRecordsAndPrediction() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add(fixture(), completingOnboarding: true, today: day(20260929), now: now)
        var instant = try day(20260929).formattingDate
        let session = TrackerSession(repository: { repository }, clock: { instant }, timeZone: { .gmt })
        session.load()
        let initial = session.snapshot
        let estimate = session.overview?.estimate
        #expect(session.overview?.currentDay == 28)
        instant = try day(20261005).formattingDate
        session.refresh()
        #expect(session.overview?.currentDay == 34)
        #expect(session.overview?.estimate == estimate)
        instant = try day(20260901).formattingDate
        session.refresh()
        #expect(session.overview?.prediction == .unavailable(.futureDate))
        #expect(session.snapshot == initial)
    }

    @Test func draftValidationKeepsAnUnknownEndUnknown() throws {
        let today = try day(20260929)
        let draft = PeriodDraft(period: Period(start: today))
        #expect(draft.period.end == nil)
        #expect(!draft.hasChanges)
        draft.start = try day(20260902)
        #expect(draft.hasChanges)
        #expect(draft.period.end == nil)
        draft.includesEnd = true
        draft.end = try day(20260901)
        #expect(draft.validationMessage(existing: [], today: today) == TrackingError.reversedEnd.localizedDescription)
    }
}
