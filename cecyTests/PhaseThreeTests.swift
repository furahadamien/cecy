import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct PhaseThreeDomainTests {
    private let today = try! LocalDay(key: 20260929)

    private func periods(count: Int = 6) throws -> [Period] {
        try (0..<count).map { Period(start: try today.adding(days: -200 + $0 * 28)) }
    }

    @Test func observationValidationAndRatings() throws {
        var entry = SymptomEntry(day: today, kind: .headache)
        try SymptomValidation.validate([entry], asOf: today)
        #expect(entry.ratingLabel == nil)
        #expect(throws: TrackingError.duplicateSymptom) {
            try SymptomValidation.validate([entry, SymptomEntry(day: today, kind: .headache)])
        }
        try SymptomValidation.validate([entry, SymptomEntry(day: today, kind: .cramps)])
        entry.value = 4
        #expect(throws: TrackingError.invalidRating) { try SymptomValidation.validate([entry]) }
        entry.value = 1
        #expect(entry.ratingLabel == "Mild")
        entry.kind = .energyLevel
        #expect(entry.ratingLabel == "Low")
        entry.kind = .sleepQuality
        #expect(entry.ratingLabel == "Poor")
        entry.notes = String(repeating: "é", count: 2000)
        try SymptomValidation.validate([entry])
        entry.notes! += "a"
        #expect(throws: TrackingError.noteTooLong) { try SymptomValidation.validate([entry]) }
        entry.notes = nil
        entry.day = try today.adding(days: 1)
        #expect(throws: TrackingError.futureDate) { try SymptomValidation.validate([entry], asOf: today) }
        entry.day = today
        entry.updatedAt = entry.createdAt.addingTimeInterval(-1)
        #expect(throws: TrackingError.invalidData) { try SymptomValidation.validate([entry]) }
        entry.updatedAt = Date(timeIntervalSinceReferenceDate: .infinity)
        #expect(throws: TrackingError.invalidData) { try SymptomValidation.validate([entry]) }
    }

    @Test func timingCountsWindowsNotDaysAndExplainsMissingLogs() throws {
        let periods = try periods()
        let logs = try periods.prefix(4).flatMap { period in
            try [-3, -2, -1].map { SymptomEntry(day: try period.start.adding(days: $0), kind: .headache) }
        }
        let result = try CycleInsightEngine.generate(periods: periods.reversed(), symptoms: logs.reversed(), today: today)
        let insight = try #require(result.first)
        #expect(result.count == 1 && insight.matchedStarts == 4 && insight.timing.count == 6)
        #expect(insight.evidence == .limited && insight.timing[4].logDays.isEmpty)
        #expect(insight.explanation.contains("does not mean"))
        #expect(insight.sourceIDs.count == periods.count + logs.count)
        let tooSparse = Array(logs.prefix(9)) // Three of six is below 60%.
        #expect(try CycleInsightEngine.generate(periods: periods, symptoms: tooSparse, today: today).isEmpty)
        let fiveLogs = try periods.prefix(5).map { SymptomEntry(day: try $0.start.adding(days: -1), kind: .headache) }
        #expect(try CycleInsightEngine.generate(periods: periods, symptoms: fiveLogs, today: today).first?.evidence == .repeated)
        #expect(try CycleInsightEngine.generate(periods: [], symptoms: logs, today: today).isEmpty)
    }

    @Test func timingWindowsBoundariesTiesAndRatingMeaning() throws {
        let periods = try periods(count: 3)
        for offset in [-4, -3, -1, 0, 2, 3] {
            let logs = try periods.map { SymptomEntry(day: try $0.start.adding(days: offset), kind: .cramps) }
            let result = try CycleInsightEngine.generate(periods: periods, symptoms: logs, today: today)
            #expect(result.isEmpty == !(-3...2).contains(offset))
        }
        for kind in [SymptomKind.sleepQuality, .energyLevel] {
            for value: Int? in [nil, 1, 2, 3] {
                let logs = periods.map { SymptomEntry(day: $0.start, kind: kind, value: value) }
                #expect(try CycleInsightEngine.generate(periods: periods, symptoms: logs, today: today).isEmpty == (value != 1))
            }
        }
        let tied = try periods.flatMap {
            [SymptomEntry(day: try $0.start.adding(days: -1), kind: .cramps), SymptomEntry(day: $0.start, kind: .cramps)]
        }
        #expect(try CycleInsightEngine.generate(periods: periods, symptoms: tied, today: today).first?.explanation.contains("before") == true)
    }

    @Test func eligibleStartsCapOverlapAndOpenWindow() throws {
        let periods = try periods(count: 8)
        let logs = periods.map { SymptomEntry(day: $0.start, kind: .cramps) }
        let insight = try #require(CycleInsightEngine.generate(periods: periods, symptoms: logs, today: today).first)
        #expect(insight.timing.count == 6 && insight.timing.first?.start == periods[2].start)
        let close = try (0..<4).map { Period(start: try today.adding(days: -30 + $0 * 5)) }
        #expect(try CycleInsightEngine.generate(periods: close, symptoms: close.map { SymptomEntry(day: $0.start, kind: .cramps) }, today: today).isEmpty)
        let three = try [28, 14, 0].map { Period(start: try today.adding(days: -$0)) }
        #expect(try CycleInsightEngine.generate(periods: three, symptoms: three.map { SymptomEntry(day: $0.start, kind: .cramps) }, today: today).isEmpty)
        let lastDayOpen = try [30, 16, 2].map { Period(start: try today.adding(days: -$0)) }
        let openLogs = lastDayOpen.map { SymptomEntry(day: $0.start, kind: .cramps) }
        #expect(try CycleInsightEngine.generate(periods: lastDayOpen, symptoms: openLogs, today: today).isEmpty)
        #expect(try CycleInsightEngine.generate(periods: lastDayOpen, symptoms: openLogs, today: today.adding(days: 1)).count == 1)
        let earliest = try Period(start: LocalDay(key: 10101))
        #expect(try CycleInsightEngine.generate(periods: [earliest], symptoms: [], today: today).isEmpty)
        let future = try SymptomEntry(day: today.adding(days: 1), kind: .cramps)
        #expect(throws: TrackingError.futureDate) { try CycleInsightEngine.generate(periods: periods, symptoms: [future], today: today) }
    }

    @Test func civilDayWindowsAcrossDSTLeapDayAndArithmeticLimits() throws {
        let starts = try [20240301, 20240311, 20241104].map { Period(start: try LocalDay(key: $0)) }
        let logs = try starts.map { SymptomEntry(day: try $0.start.adding(days: -1), kind: .headache) }
        let result = try #require(CycleInsightEngine.generate(periods: starts, symptoms: logs, today: today).first { $0.category == .symptomTiming })
        #expect(result.matchedStarts == 3 && logs[0].day.key == 20240229)
        let end = try LocalDay(key: 99991231)
        #expect(try CycleInsightEngine.generate(periods: [Period(start: end)], symptoms: [], today: end).isEmpty)
        let sixApart = try (0..<5).map { Period(start: try today.adding(days: -60 + $0 * 6)) }
        let threeLogs = sixApart.prefix(3).map { SymptomEntry(day: $0.start, kind: .cramps) }
        let exact = try #require(CycleInsightEngine.generate(periods: sixApart, symptoms: threeLogs, today: today).first)
        #expect(exact.matchedStarts == 3 && exact.timing.count == 5)
        let eight = try periods(count: 8)
        let oldLogs = eight.prefix(3).map { SymptomEntry(day: $0.start, kind: .cramps) }
        #expect(try CycleInsightEngine.generate(periods: eight, symptoms: oldLogs, today: today).isEmpty)
    }

    @Test func comparisonThresholdsAndUnknownEndDoesNotGetSkipped() throws {
        func history(_ lengths: [Int]) throws -> [Period] {
            var start = try today.adding(days: -230)
            var records = [Period(start: start)]
            for length in lengths { start = try start.adding(days: length); records.append(Period(start: start)) }
            return records
        }
        for delta in [2, 3] {
            let values = try history([28, 28, 28, 28 + delta, 28 + delta, 28 + delta])
            let insights = try CycleInsightEngine.generate(periods: values, symptoms: [], today: today)
            #expect(insights.contains { $0.category == .cycleLength } == (delta == 3))
        }
        let variable = try history([28, 28, 28, 24, 28, 32])
        let variability = try #require(CycleInsightEngine.generate(periods: variable, symptoms: [], today: today).first { $0.category == .cycleVariability })
        #expect(variability.previousMetric == 0 && variability.recentValues == [24, 28, 32])
        var bleeding = try periods()
        for index in bleeding.indices { bleeding[index].end = try bleeding[index].start.adding(days: index < 3 ? 3 : 4) }
        #expect(try CycleInsightEngine.generate(periods: bleeding, symptoms: [], today: today).contains { $0.category == .bleedingDuration })
        bleeding[4].end = nil
        #expect(try !CycleInsightEngine.generate(periods: bleeding, symptoms: [], today: today).contains { $0.category == .bleedingDuration })
    }
}

@MainActor struct PhaseThreePersistenceTests {
    private let today = try! LocalDay(key: 20260929)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case disk }

    @Test(arguments: [false, true]) func v2MigrationPreservesMetadataAndSkippedOnboarding(history: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let period = Period(start: today, end: today, flow: .heavy, notes: "Synthetic", createdAt: now)
        try autoreleasepool {
            let schema = Schema(versionedSchema: TrackerSchemaV2.self)
            let config = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            if history { context.insert(TrackerSchemaV2.PeriodRecord(period)) }
            context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
            try context.save()
        }
        let entry = SymptomEntry(day: today, kind: .headache, value: 2, notes: "Synthetic", createdAt: now)
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let state = try repository.load()
            #expect(state.periods == (history ? [period] : []) && state.onboardingCompletedAt == now)
            #expect(state.symptoms.isEmpty)
            _ = try repository.saveSymptom(entry, editing: false, today: today, now: now)
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load().symptoms == [entry])
    }

    @Test func crudIdentityConflictAndReset() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let entry = SymptomEntry(day: today, kind: .headache, createdAt: now)
        _ = try repository.saveSymptom(entry, editing: false, today: today, now: now)
        #expect(throws: TrackingError.duplicateSymptom) {
            try repository.saveSymptom(SymptomEntry(day: today, kind: .headache), editing: false, today: today, now: now)
        }
        var edit = entry
        edit.value = 3
        edit.notes = "  "
        let updated = try #require(repository.saveSymptom(edit, editing: true, today: today, now: now.addingTimeInterval(10)).symptoms.first)
        #expect(updated.createdAt == now && updated.id == entry.id && updated.updatedAt == now.addingTimeInterval(10))
        #expect(updated.value == 3 && updated.notes == nil)
        let second = SymptomEntry(day: today, kind: .cramps)
        let before = try repository.saveSymptom(second, editing: false, today: today, now: now)
        edit.kind = .cramps
        #expect(throws: TrackingError.duplicateSymptom) { try repository.saveSymptom(edit, editing: true, today: today, now: now) }
        #expect(try repository.load() == before)
        #expect(try repository.deleteSymptom(id: entry.id).symptoms.count == 1)
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func failedObservationWritesAndResetRollbackThenRetry() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let entry = SymptomEntry(day: today, kind: .cramps, createdAt: now)
        let saved = try memory.saveSymptom(entry, editing: false, today: today, now: now)
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: { context in
            if fail { throw Failure.disk }; try context.save()
        })
        var edit = entry
        edit.notes = "Unsaved"
        #expect(throws: Failure.self) { try repository.saveSymptom(edit, editing: true, today: today, now: now) }
        #expect(throws: Failure.self) { try repository.saveSymptom(SymptomEntry(day: today, kind: .headache), editing: false, today: today, now: now) }
        #expect(throws: Failure.self) { try repository.deleteSymptom(id: entry.id) }
        #expect(throws: Failure.self) { try repository.deleteAll() }
        #expect(try repository.load() == saved)
        fail = false
        #expect(try repository.saveSymptom(edit, editing: true, today: today, now: now).symptoms.first?.notes == "Unsaved")
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func batchSymptomsSaveTogetherAndConflictsPreserveExistingRecords() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let entries = [SymptomEntry(day: today, kind: .cramps, value: 3, notes: "Shared note"),
                       SymptomEntry(day: today, kind: .sleepQuality, value: 1, notes: "Shared note")]
        let saved = try repository.addSymptoms(entries, today: today, now: now)
        #expect(Set(saved.symptoms.map(\.id)) == Set(entries.map(\.id)))
        #expect(saved.symptoms.first(where: { $0.kind == .cramps })?.value == 3)
        #expect(saved.symptoms.first(where: { $0.kind == .sleepQuality })?.value == 1)
        #expect(saved.symptoms.allSatisfy { $0.notes == "Shared note" && $0.createdAt == now })
        #expect(throws: TrackingError.duplicateSymptom) {
            try repository.addSymptoms([SymptomEntry(day: today, kind: .headache),
                                        SymptomEntry(day: today, kind: .cramps)], today: today, now: now)
        }
        #expect(try repository.load() == saved)
        #expect(SymptomKind.allCases.allSatisfy { !$0.symbol.isEmpty })
    }

    @Test func failedBatchRollsBackEverySymptomAndCanRetry() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: { context in
            if fail { throw Failure.disk }; try context.save()
        })
        let entries = [SymptomEntry(day: today, kind: .headache, notes: "  "),
                       SymptomEntry(day: today, kind: .energyLevel, value: 2)]
        #expect(throws: Failure.self) { try repository.addSymptoms(entries, today: today, now: now) }
        #expect(try repository.load().symptoms.isEmpty)
        fail = false
        let saved = try repository.addSymptoms(entries, today: today, now: now)
        #expect(saved.symptoms.count == 2 && saved.symptoms.allSatisfy { $0.notes == nil })
        #expect(try repository.load() == saved)
    }

    @Test func malformedStoredObservationFailsVisiblyButResetWorks() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let context = ModelContext(repository.container)
        let record = TrackerSchemaV3.SymptomRecord(SymptomEntry(day: today, kind: .headache))
        record.kindRaw = "unknown"
        context.insert(record)
        try context.save()
        #expect(throws: TrackingError.invalidData) { try repository.load() }
        #expect(try repository.deleteAll() == TrackerSnapshot())
    }

    @Test func clockTravelWithholdsInsightsWithoutChangingObservations() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        var zone = TimeZone(secondsFromGMT: 14 * 3600)!
        let instant = today.formattingDate.addingTimeInterval(3600)
        let session = TrackerSession(repository: { repository }, clock: { instant }, timeZone: { zone })
        session.load()
        #expect(session.save([], completingOnboarding: true) == nil)
        #expect(session.saveSymptom(SymptomEntry(day: today, kind: .headache)) == nil)
        let saved = session.snapshot
        zone = TimeZone(secondsFromGMT: -12 * 3600)!
        session.refresh()
        #expect(session.snapshot == saved && session.insights.isEmpty && session.insightMessage != nil)
        zone = .gmt
        session.refresh()
        #expect(session.snapshot == saved && session.insightMessage == nil)
    }

    @Test func allObservationKindsRoundTripAndInvalidStorageRatingFails() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        for kind in SymptomKind.allCases {
            _ = try repository.saveSymptom(SymptomEntry(day: today, kind: kind, value: 1), editing: false, today: today, now: now)
        }
        #expect(try repository.load().symptoms.count == SymptomKind.allCases.count)
        let context = ModelContext(repository.container)
        let record = try #require(context.fetch(FetchDescriptor<TrackerSchemaV3.SymptomRecord>()).first)
        record.rating = 0
        try context.save()
        let reader = SwiftDataPeriodRepository(container: repository.container)
        #expect(throws: TrackingError.invalidRating) { try reader.load() }
    }

    @Test func sessionRecomputesAfterPeriodCorrectionAndPreservesSymptoms() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { self.now }, timeZone: { .gmt })
        session.load()
        let periods = try [90, 60, 30].map { Period(start: try today.adding(days: -$0)) }
        #expect(session.save(periods, completingOnboarding: true) == nil)
        for period in periods { #expect(session.saveSymptom(SymptomEntry(day: period.start, kind: .cramps)) == nil) }
        #expect(session.insights.count == 1)
        var correction = periods[0]
        correction.start = try correction.start.adding(days: 7)
        #expect(session.update(correction) == nil)
        #expect(session.insights.isEmpty && session.snapshot.symptoms.count == 3)
        #expect(session.update(periods[0]) == nil && session.insights.count == 1)
        #expect(session.delete(id: periods[0].id) == nil && session.insights.isEmpty)
        #expect(session.snapshot.symptoms.count == 3)
        #expect(session.deleteAll() == nil && session.insights.isEmpty && session.snapshot.symptoms.isEmpty)
    }
}
