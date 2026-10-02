import Foundation
import Testing
@testable import cecy

@MainActor
struct PredictionUpdateProgressTests {
    private enum Failure: Error { case diskFull }

    private func makeSession(_ repository: SwiftDataPeriodRepository) throws -> TrackerSession {
        let today = try LocalDay(key: 20260929)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, timeZone: { .gmt })
        session.load()
        return session
    }

    @Test(arguments: ["period", "symptom", "activity", "history"])
    func progressSurroundsRecordSaveAndRecalculation(kind: String) async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = try makeSession(repository)
        let today = try #require(session.today)
        let previousStart = try today.adding(days: -28)
        #expect(!session.isUpdatingPredictions)
        let error = await session.withPredictionUpdate {
            #expect(session.isUpdatingPredictions)
            switch kind {
            case "period": return session.save([Period(start: today)])
            case "symptom": return session.addSymptoms([SymptomEntry(day: today, kind: .headache)])
            case "activity": return session.saveSexualActivity(SexualActivityEntry(day: today, activities: [.other]))
            default: return session.save([Period(start: previousStart), Period(start: today)])
            }
        }
        #expect(error == nil)
        #expect(!session.isUpdatingPredictions && !session.isSaving)
        #expect(session.snapshot == (try repository.load()))
        #expect(session.snapshot != TrackerSnapshot())
        #expect(session.overview != nil)
        #expect(session.statistics != nil)
    }

    @Test func failedSaveClearsProgressAndPreservesRecords() async throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        let repository = SwiftDataPeriodRepository(container: memory.container, save: { _ in throw Failure.diskFull })
        let session = try makeSession(repository)
        let period = Period(start: try #require(session.today))
        let error = await session.withPredictionUpdate { session.save([period]) }
        #expect(error != nil)
        #expect(!session.isUpdatingPredictions && !session.isSaving)
        #expect(session.snapshot == TrackerSnapshot())
        #expect(try repository.load() == TrackerSnapshot())
        #expect(session.confirmation == nil)
    }

    @Test func duplicateUpdateIsRejectedAndInterruptionPreventsCommit() async throws {
        let session = try makeSession(SwiftDataPeriodRepository.inMemory())
        var committed = false
        var duplicateRan = false
        let interruption = Task { @MainActor in
            #expect(session.isUpdatingPredictions)
            let duplicate = await session.withPredictionUpdate { duplicateRan = true; return nil }
            #expect(duplicate != nil)
            session.cancelPredictionUpdatePresentation()
        }
        let error = await session.withPredictionUpdate { committed = true; return nil }
        await interruption.value
        #expect(error != nil)
        #expect(!committed && !duplicateRan)
        #expect(!session.isUpdatingPredictions)
    }

    @Test func cancelledTaskDoesNotSave() async throws {
        let session = try makeSession(SwiftDataPeriodRepository.inMemory())
        var committed = false
        let update = Task { await session.withPredictionUpdate { committed = true; return nil } }
        update.cancel()
        #expect(await update.value != nil)
        #expect(!committed && !session.isUpdatingPredictions)
    }

    @Test func cancellationAfterCommitStillReportsSuccess() async throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = try makeSession(repository)
        let period = Period(start: try #require(session.today))
        var update: Task<String?, Never>?
        update = Task { @MainActor in
            await session.withPredictionUpdate {
                let error = session.save([period])
                update?.cancel()
                return error
            }
        }
        let task = try #require(update)
        #expect(await task.value == nil)
        #expect(session.snapshot.periods.map(\.id) == [period.id])
        #expect(!session.isUpdatingPredictions && !session.isSaving)
    }
}
