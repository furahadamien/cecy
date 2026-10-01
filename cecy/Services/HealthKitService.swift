import Foundation
import HealthKit

/// Read-only, foreground, on-demand. No observer queries, background delivery or writes.
@MainActor
final class HealthKitService: HealthFlowReading {
    private let store = HKHealthStore()
    private var type: HKCategoryType { HKObjectType.categoryType(forIdentifier: .menstrualFlow)! }
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestReadAccess() async throws {
        guard isAvailable else { throw HealthImportError.unavailable }
        // Completion means the permission UI finished, not that read permission was granted.
        try await store.requestAuthorization(toShare: [], read: [type])
        try Task.checkCancellation()
    }

    func samples(from start: Date, through end: Date) async throws -> [HealthFlowSample] {
        guard isAvailable else { throw HealthImportError.unavailable }
        try Task.checkCancellation()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\HKCategorySample.startDate, order: .reverse)], limit: 2_001)
        let records = try await query.result(for: store)
        try Task.checkCancellation()
        guard records.count <= 2_000 else { throw HealthImportError.tooManySamples }
        return records.map {
            HealthFlowSample(id: $0.uuid, sourceName: $0.sourceRevision.source.name,
                             sourceBundle: $0.sourceRevision.source.bundleIdentifier,
                             start: $0.startDate, end: $0.endDate,
                             timeZoneIdentifier: $0.metadata?[HKMetadataKeyTimeZone] as? String,
                             flowValue: $0.value,
                             markedCycleStart: ($0.metadata?[HKMetadataKeyMenstrualCycleStart] as? NSNumber)?.boolValue ?? false)
        }
    }
}

#if DEBUG
/// Used only by the isolated UI-test composition; never contacts Apple Health.
@MainActor
struct FixtureHealthReader: HealthFlowReading {
    let mode: String
    var isAvailable: Bool { mode != "unavailable" }
    func requestReadAccess() async throws {}
    func samples(from start: Date, through end: Date) async throws -> [HealthFlowSample] {
        if mode == "empty" { return [] }
        if mode == "error" { throw HealthImportError.unavailable }
        let date = try LocalDay(key: 20260510).formattingDate
        return [HealthFlowSample(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                                 sourceName: "Synthetic Health source", sourceBundle: "test.cecy.health",
                                 start: date, end: date.addingTimeInterval(3600), timeZoneIdentifier: "UTC",
                                 flowValue: 2, markedCycleStart: true)]
    }
}
#endif
