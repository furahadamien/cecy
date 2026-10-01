import Foundation

/// Framework-free copy of one menstrual-flow observation. Never itself a period.
nonisolated struct HealthFlowSample: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let sourceName: String
    let sourceBundle: String
    let start: Date
    let end: Date
    let timeZoneIdentifier: String?
    let flowValue: Int
    let markedCycleStart: Bool

    func suggestedDay(fallbackTimeZone: TimeZone) throws -> LocalDay {
        guard start.timeIntervalSinceReferenceDate.isFinite,
              end.timeIntervalSinceReferenceDate.isFinite, end >= start else { throw TrackingError.invalidData }
        let zone = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? fallbackTimeZone
        return try LocalDay(date: start, timeZone: zone)
    }

    var flowDescription: String {
        switch flowValue {
        case 1: "Unspecified flow"
        case 2: "Light flow"
        case 3: "Medium flow"
        case 4: "Heavy flow"
        case 5: "No flow"
        default: "Unknown flow"
        }
    }
}

/// Kept even after local deletion to prevent an accepted sample reappearing as new.
/// Source metadata is private, not included in the general health-data export.
nonisolated struct HealthImportReceipt: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { sample.id }
    let sample: HealthFlowSample
    let periodID: UUID
    let acceptedStartKey: Int
    let mappingTimeZone: String
    let acceptedAt: Date
    let mappingVersion: Int
}

nonisolated enum HealthImportError: Error, LocalizedError {
    case unavailable, alreadyReviewed, invalidSample, tooManySamples, interrupted

    var errorDescription: String? {
        switch self {
        case .unavailable: "Apple Health isn’t available here. You can keep tracking in Cecy."
        case .alreadyReviewed: "This Health sample was already imported. Edit its local period in Calendar or History; it won’t be imported again."
        case .invalidSample: "This sample cannot be used as a period start. Record the date manually instead."
        case .tooManySamples: "Too many samples to review at once. Choose a shorter date range. No records were changed."
        case .interrupted: "Review was interrupted. Open Apple Health review again; no unconfirmed dates were saved."
        }
    }
}

nonisolated enum HealthImportPolicy {
    static let mappingVersion = 1

    /// Confirmation supplies a civil day; daily flow never implies a whole-period flow or end.
    static func prepare(sample: HealthFlowSample, confirmedStart: LocalDay, existing: TrackerSnapshot,
                        today: LocalDay, now: Date, timeZone: TimeZone) throws -> (Period, HealthImportReceipt) {
        guard !existing.healthImports.contains(where: { $0.id == sample.id }) else { throw HealthImportError.alreadyReviewed }
        // Validate source timestamps, but do not confuse a source-zone civil day with
        // a future instant when the user has traveled across the date line.
        _ = try sample.suggestedDay(fallbackTimeZone: timeZone)
        guard (1...4).contains(sample.flowValue), !sample.sourceBundle.isEmpty,
              now.timeIntervalSinceReferenceDate.isFinite, sample.start <= now else { throw HealthImportError.invalidSample }
        let period = Period(start: confirmedStart, createdAt: now)
        try PeriodValidation.validate(existing.periods + [period], asOf: today)
        return (period, HealthImportReceipt(sample: sample, periodID: period.id, acceptedStartKey: confirmedStart.key,
                                           mappingTimeZone: timeZone.identifier, acceptedAt: now, mappingVersion: mappingVersion))
    }
}

@MainActor
protocol HealthFlowReading {
    var isAvailable: Bool { get }
    func requestReadAccess() async throws
    func samples(from start: Date, through end: Date) async throws -> [HealthFlowSample]
}

/// Default for previews/tests. Production must explicitly inject the real adapter.
@MainActor
struct UnavailableHealthReader: HealthFlowReading {
    var isAvailable: Bool { false }
    func requestReadAccess() async throws { throw HealthImportError.unavailable }
    func samples(from start: Date, through end: Date) async throws -> [HealthFlowSample] { throw HealthImportError.unavailable }
}
