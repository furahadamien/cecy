import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct StatisticsTests {
    @Test func descriptiveStatistics() throws {
        #expect(RecordedStatistics(lengths: []) == nil)
        #expect(RecordedStatistics(lengths: [0]) == nil)
        let one = try #require(RecordedStatistics(lengths: [28]))
        #expect(one.mean == 28 && one.median == 28 && one.standardDeviation == nil)
        let even = try #require(RecordedStatistics(lengths: [32, 28, 30, 28]))
        #expect(even.mean == 29.5 && even.median == 29)
        #expect(even.minimum == 28 && even.maximum == 32 && even.spread == 4)
        #expect(abs(try #require(even.standardDeviation) - sqrt(2.75)) < 0.00001)
        #expect(even.distribution == [LengthFrequency(length: 28, count: 2),
                                     LengthFrequency(length: 30, count: 1), LengthFrequency(length: 32, count: 1)])
        #expect(RecordedStatistics(lengths: [29, 28, 30])?.median == 29)
        #expect(RecordedStatistics(lengths: [28, 28, 28])?.standardDeviation == 0)
    }

    @Test func confirmedEndsOnlyAndNoOpenCycle() throws {
        let today = try LocalDay(key: 20260929)
        let periods = try [
            Period(start: LocalDay(key: 20260705), end: LocalDay(key: 20260709)),
            Period(start: LocalDay(key: 20260804)),
            Period(start: LocalDay(key: 20260902), end: LocalDay(key: 20260902))
        ]
        let result = try CycleStatistics.calculate(periods: periods.reversed(), today: today)
        #expect(result.cycles?.count == 2 && result.cycles?.mean == 29.5)
        #expect(result.bleeding?.count == 2 && result.bleeding?.mean == 3)
        #expect(result.unconfirmedEndCount == 1)
        let empty = try CycleStatistics.calculate(periods: [], today: today)
        #expect(empty.cycles == nil && empty.bleeding == nil)
        #expect(throws: TrackingError.futureDate) {
            try CycleStatistics.calculate(periods: periods, today: LocalDay(key: 20260801))
        }
    }

    @Test func notesBoundariesAndCalendarEndSemantics() throws {
        let start = try LocalDay(key: 20260902)
        var period = Period(start: start, flow: .heavy, notes: String(repeating: "é", count: 2_000))
        try PeriodValidation.validate([period])
        #expect(try !period.contains(start.adding(days: 1)))
        period.notes! += "a"
        #expect(throws: TrackingError.noteTooLong) { try PeriodValidation.validate([period]) }
        period.notes = nil
        period.end = try start.adding(days: 4)
        #expect(period.duration == 5)
        #expect(try period.contains(start.adding(days: 4)))
        #expect(try !period.contains(start.adding(days: 5)))
    }
}

@MainActor
struct PhaseTwoPersistenceTests {
    private let today = try! LocalDay(key: 20260929)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case unavailable }

    @Test(arguments: [false, true]) func v1StoreMigratesInPlace(withHistory: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("CecyPeriodsV1.store")
        let period = try Period(start: LocalDay(key: 20260902), end: LocalDay(key: 20260906), createdAt: now)
        try autoreleasepool {
            let schema = Schema(versionedSchema: TrackerSchemaV1.self)
            let config = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            context.autosaveEnabled = false
            if withHistory { context.insert(TrackerSchemaV1.PeriodRecord(period)) }
            context.insert(TrackerSchemaV1.AppStateRecord(completedAt: now))
            try context.save()
        }
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let snapshot = try repository.load()
            #expect(snapshot.periods == (withHistory ? [period] : []))
            #expect(snapshot.onboardingCompletedAt == now)
            if withHistory {
                var edited = period
                edited.flow = .moderate
                edited.notes = "Synthetic migration note"
                _ = try repository.update(edited, today: today, now: now.addingTimeInterval(60))
            }
        }
        let reopened = try SwiftDataPeriodRepository.local(url: url).load()
        #expect(reopened.onboardingCompletedAt == now)
        if withHistory {
            let saved = try #require(reopened.periods.first)
            #expect(saved.id == period.id && saved.createdAt == period.createdAt)
            #expect(saved.start == period.start && saved.end == period.end)
            #expect(saved.flow == .moderate && saved.notes == "Synthetic migration note")
            #expect(saved.updatedAt == now.addingTimeInterval(60))
        }
    }

    @Test func allFlowValuesRoundTripAndInvalidRawValueFails() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let periods = try PeriodFlow.allCases.enumerated().map { index, flow in
            Period(start: try today.adding(days: -index * 28), flow: flow, notes: "Synthetic \(index)")
        }
        let committed = try repository.add(periods, completingOnboarding: true, today: today, now: now)
        #expect(try repository.load() == committed)
        let context = ModelContext(repository.container)
        let raw = try #require(context.fetch(FetchDescriptor<TrackerSchemaV2.PeriodRecord>()).first)
        raw.flowRaw = "unsupported"
        try context.save()
        let reader = SwiftDataPeriodRepository(container: repository.container)
        #expect(throws: TrackingError.invalidData) { try reader.load() }
    }

    @Test func resetSurvivesReopeningAndRemovesOnlyAllowlistedLegacyFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["cecy.sqlite", "cecy.sqlite-wal", "cecy.sqlite-shm", "unrelated.txt"] {
            try Data("synthetic".utf8).write(to: directory.appendingPathComponent(name))
        }
        let url = directory.appendingPathComponent("Cecy/active.store")
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url, clearLegacyData: {
                try LegacyStoreCleanup.removeTemplateStore(in: directory)
            })
            _ = try repository.add([Period(start: today, flow: .light, notes: "Synthetic")],
                                   completingOnboarding: true, today: today, now: now)
            #expect(try repository.deleteAll() == TrackerSnapshot())
            #expect(try repository.deleteAll() == TrackerSnapshot())
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == TrackerSnapshot())
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("unrelated.txt").path))
        for name in ["cecy.sqlite", "cecy.sqlite-wal", "cecy.sqlite-shm"] {
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path))
        }
    }

    @Test(arguments: [false, true]) func failedResetRetainsCurrentSnapshot(failCleanup: Bool) throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let original = try memory.add([Period(start: today, notes: "Synthetic")], completingOnboarding: true, today: today, now: now)
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, clearLegacyData: {
            if fail && failCleanup { throw Failure.unavailable }
        }, save: {
            if fail && !failCleanup { throw Failure.unavailable }
            try $0.save()
        })
        #expect(throws: Failure.self) { try repository.deleteAll() }
        #expect(try repository.load() == original)
        fail = false
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func sessionEditsDeleteAndResetRecomputeTogether() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt })
        session.load()
        let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        #expect(session.save(periods, completingOnboarding: true) == nil)
        var edited = periods[3]
        edited.end = try LocalDay(key: 20260906)
        edited.flow = .light
        edited.notes = "Synthetic"
        let initialEstimate = session.overview?.estimate
        #expect(session.update(edited) == nil)
        #expect(session.statistics?.bleeding?.mean == 5)
        #expect(session.overview?.estimate == initialEstimate)
        edited.start = try LocalDay(key: 20260903)
        #expect(session.update(edited) == nil)
        #expect(session.overview?.currentDay == 27)
        #expect(session.overview?.estimate != initialEstimate)
        #expect(session.statistics?.bleeding?.mean == 4)
        #expect(session.delete(id: periods[0].id) == nil)
        #expect(session.overview?.estimate == nil)
        for period in session.snapshot.periods { #expect(session.delete(id: period.id) == nil) }
        #expect(session.snapshot.onboardingCompletedAt != nil)
        #expect(session.statistics?.cycles == nil)
        #expect(session.deleteAll() == nil)
        #expect(session.snapshot == TrackerSnapshot())
        #expect(session.confirmation == nil)
    }

    @Test func metadataDraftAndFailedEditRemainIntact() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let period = Period(start: today)
        let original = try memory.add([period], completingOnboarding: true, today: today, now: now)
        let repository = SwiftDataPeriodRepository(container: memory.container) { _ in throw Failure.unavailable }
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt })
        session.load()
        let draft = PeriodDraft(period: period)
        draft.notes = "   "
        #expect(draft.period.notes == nil)
        draft.notes = String(repeating: " ", count: 2_001)
        #expect(draft.validationMessage(existing: [], today: today) == TrackingError.noteTooLong.localizedDescription)
        draft.notes = "Synthetic unsaved note"
        draft.flow = .heavy
        #expect(draft.hasChanges)
        #expect(session.update(draft.period) != nil)
        #expect(session.snapshot == original)
        #expect(draft.notes == "Synthetic unsaved note" && draft.flow == .heavy)
        #expect(session.delete(id: period.id) != nil)
        #expect(session.deleteAll() != nil)
        #expect(session.snapshot == original && session.confirmation == nil)
    }
}
