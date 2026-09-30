import Foundation

/// Comparison candidates share eligibility and ranges so center-error comparisons are fair.
nonisolated enum PredictionCandidate: String, CaseIterable, Sendable {
    case median, mean, recentWeighted
}

nonisolated struct ComparisonPredictionEngine: CyclePredicting {
    let candidate: PredictionCandidate

    func predict(intervals: [CycleInterval], latestStart: LocalDay) throws -> PredictionOutcome {
        let outcome = try BaselinePredictionEngine().predict(intervals: intervals, latestStart: latestStart)
        guard case .available(let baseline) = outcome, candidate != .median else { return outcome }
        let values = baseline.sourceLengths.map(Double.init)
        let center: Double
        if candidate == .mean {
            center = values.reduce(0, +) / Double(values.count)
        } else {
            let weights = values.indices.map { Double($0 + 1) }
            center = zip(values, weights).reduce(0) { $0 + $1.0 * $1.1 } / weights.reduce(0, +)
        }
        return .available(CyclePrediction(center: try latestStart.adding(days: Int(center.rounded(.toNearestOrAwayFromZero))),
                                         earliest: baseline.earliest, latest: baseline.latest,
                                         confidence: baseline.confidence, sourceLengths: baseline.sourceLengths))
    }
}

nonisolated struct PredictionReplayRow: Identifiable, Equatable, Sendable {
    let target: CycleInterval
    let sources: [CycleInterval]
    let outcome: PredictionOutcome
    var id: UUID { target.id }
    var estimate: CyclePrediction? {
        if case .available(let value) = outcome { return value }
        return nil
    }
    var isWarmUp: Bool {
        if case .insufficientHistory = outcome { return true }
        return false
    }
    /// Positive means the actual recorded start was later than the estimated center.
    var signedError: Int? { estimate.map { $0.center.days(until: target.nextStart) } }
    var covered: Bool? { estimate.map { $0.contains(target.nextStart) } }
    var windowSpan: Int? { estimate.map { $0.earliest.days(until: $0.latest) } }
    var outsideWindowDays: Int? {
        guard let estimate else { return nil }
        if target.nextStart < estimate.earliest { return target.nextStart.days(until: estimate.earliest) }
        if target.nextStart > estimate.latest { return estimate.latest.days(until: target.nextStart) }
        return 0
    }
}

nonisolated struct PredictionReplay: Equatable, Sendable {
    let rows: [PredictionReplayRow]
    var scored: [PredictionReplayRow] { rows.filter { $0.estimate != nil } }
    var warmUpCount: Int { rows.filter(\.isWarmUp).count }
    var withheldCount: Int { rows.count - warmUpCount - scored.count }
    var coveredCount: Int { scored.filter { $0.covered == true }.count }
    var meanAbsoluteError: Double? {
        average(scored.compactMap { $0.signedError.map { abs($0) } })
    }
    var meanWindowSpan: Double? { average(scored.compactMap(\.windowSpan)) }
    private func average(_ values: [Int]) -> Double? {
        values.isEmpty ? nil : values.map(Double.init).reduce(0, +) / Double(values.count)
    }
}

nonisolated enum PredictionBacktester {
    static func evaluate(periods: [Period], today: LocalDay,
                         engine: any CyclePredicting = BaselinePredictionEngine()) throws -> PredictionReplay {
        try PeriodValidation.validate(periods, asOf: today)
        let sorted = periods.sorted { $0.start < $1.start }
        return try evaluate(intervals: zip(sorted, sorted.dropFirst()).map {
            CycleInterval(id: $0.id, start: $0.start, nextStart: $1.start)
        }, engine: engine)
    }

    static func evaluate(intervals: [CycleInterval],
                         engine: any CyclePredicting = BaselinePredictionEngine()) throws -> PredictionReplay {
        try validate(intervals)
        // A bounded six-record slice avoids copying the entire history for every fold.
        let rows = intervals.indices.map { index -> PredictionReplayRow in
            let sources = Array(intervals[max(0, index - 6)..<index])
            let target = intervals[index]
            let outcome: PredictionOutcome
            do { outcome = try engine.predict(intervals: sources, latestStart: target.start) }
            catch { outcome = .unavailable(error as? TrackingError ?? .invalidData) }
            return PredictionReplayRow(target: target, sources: sources, outcome: outcome)
        }
        return PredictionReplay(rows: rows)
    }

    static func validate(_ intervals: [CycleInterval]) throws {
        guard Set(intervals.map(\.id)).count == intervals.count else { throw TrackingError.invalidData }
        for index in intervals.indices {
            guard intervals[index].length > 0 else { throw TrackingError.invalidData }
            if index > 0, intervals[index - 1].nextStart != intervals[index].start { throw TrackingError.invalidData }
        }
    }
}

nonisolated struct PredictionEvidence: Equatable, Sendable {
    static let policy = "Median window V1 · Evidence policy V2"
    let confidence: PredictionConfidence
    let reason: String
    let recentReplay: PredictionReplay

    static func assess(sourceLengths: [Int], replay: PredictionReplay) -> Self {
        let recent = PredictionReplay(rows: Array(replay.rows.filter { !$0.isWarmUp }.suffix(6)))
        let reason: String
        let confidence: PredictionConfidence
        if sourceLengths.count < 6 {
            confidence = .low
            reason = "Fewer than six completed intervals support this estimate."
        } else if (sourceLengths.max() ?? 0) - (sourceLengths.min() ?? 0) > 7 {
            confidence = .low
            reason = "The six source intervals span more than seven days."
        } else if recent.scored.count < 3 || recent.withheldCount > 0 {
            confidence = .low
            reason = "Recent history has fewer than three checkable estimates or includes a withheld estimate."
        } else if recent.coveredCount * 5 < recent.scored.count * 4 || (recent.meanAbsoluteError ?? .infinity) > 3 {
            confidence = .low
            reason = "Recent reconstructed estimates missed too many start windows or their average center error exceeded three days."
        } else {
            confidence = .moderate
            reason = "Six intervals span at most seven days, with at least three recent checks, no withheld estimates, at least 80% of checked starts inside their windows, and an average center error of at most three days."
        }
        return Self(confidence: confidence, reason: reason, recentReplay: recent)
    }
}

/// Same dates as V1; confidence can only be reduced by retrospective evidence.
nonisolated struct EvidencePredictionEngine: CyclePredicting {
    func predict(intervals: [CycleInterval], latestStart: LocalDay) throws -> PredictionOutcome {
        try PredictionBacktester.validate(intervals)
        guard intervals.last.map({ $0.nextStart == latestStart }) ?? true else { throw TrackingError.invalidData }
        let baseline = try BaselinePredictionEngine().predict(intervals: intervals, latestStart: latestStart)
        guard case .available(let prediction) = baseline else { return baseline }
        let replay = try PredictionBacktester.evaluate(intervals: intervals)
        let evidence = PredictionEvidence.assess(sourceLengths: prediction.sourceLengths, replay: replay)
        return .available(CyclePrediction(center: prediction.center, earliest: prediction.earliest, latest: prediction.latest,
                                         confidence: evidence.confidence, sourceLengths: prediction.sourceLengths))
    }
}
