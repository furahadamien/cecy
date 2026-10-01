import Foundation
import Observation

@MainActor @Observable
final class HealthImportReview {
    enum State: Equatable { case off, requesting, reading, review, empty, failed }
    private(set) var state: State = .off
    private(set) var samples: [HealthFlowSample] = []
    private(set) var message: String?
    private(set) var mappingTimeZone = TimeZone.current
    @ObservationIgnored private let reader: any HealthFlowReading
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var revision = 0
    var isAvailable: Bool { reader.isAvailable }
    var isBusy: Bool { state == .requesting || state == .reading }

    init(reader: any HealthFlowReading) { self.reader = reader }

    func stop() {
        revision += 1
        task?.cancel()
        task = nil
        samples = []
        message = nil
        state = .off
    }

    func begin(months: Int, now: Date, timeZone: TimeZone, canAccess: @escaping @MainActor () -> Bool) {
        stop()
        guard canAccess() else { return }
        guard reader.isAvailable else {
            state = .failed
            message = HealthImportError.unavailable.localizedDescription
            return
        }
        guard [3, 6, 12].contains(months) else { return }
        var calendar = LocalDay.calendar
        calendar.timeZone = timeZone
        guard let start = calendar.date(byAdding: .month, value: -months, to: now) else { return }
        let token = revision
        mappingTimeZone = timeZone
        state = .requesting
        task = Task { [weak self] in
            guard let self else { return }
            defer { if token == revision { task = nil } }
            do {
                try await reader.requestReadAccess()
                guard continueReview(token: token, canAccess: canAccess) else { return }
                state = .reading
                let values = try await reader.samples(from: start, through: now)
                guard continueReview(token: token, canAccess: canAccess) else { return }
                // Keep no-flow observations out of the list; never infer starts from gaps.
                // UUID—not date—is identity, including multiple sources on the same day.
                var seen: Set<UUID> = []
                samples = values.filter { $0.flowValue != 5 && seen.insert($0.id).inserted }
                    .sorted { $0.start == $1.start ? $0.id.uuidString < $1.id.uuidString : $0.start > $1.start }
                state = samples.isEmpty ? .empty : .review
            } catch {
                guard continueReview(token: token, canAccess: canAccess) else { return }
                state = .failed
                message = (error as? HealthImportError)?.localizedDescription
                    ?? "Apple Health couldn’t be read. Unlock your device and try again. Your Cecy records haven’t changed."
            }
        }
    }

    private func continueReview(token: Int, canAccess: @MainActor () -> Bool) -> Bool {
        guard token == revision else { return false }
        guard !Task.isCancelled, canAccess() else { stop(); return false }
        return true
    }

    func contains(_ sample: HealthFlowSample) -> Bool { state == .review && samples.contains(sample) }
}
