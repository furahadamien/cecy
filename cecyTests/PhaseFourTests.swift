import Foundation
import Testing
@testable import cecy

nonisolated struct PhaseFourDomainTests {
    private let today = try! LocalDay(key: 20260929)
    private func history(_ lengths: [Int], start: Int = 20200101) throws -> [Period] {
        var records = [Period(start: try LocalDay(key: start))]
        for length in lengths { records.append(Period(start: try records.last!.start.adding(days: length))) }
        return records
    }

    @Test func replayUsesOnlyEarlierIntervalsAndIsPrefixStable() throws {
        let periods = try history([28, 29, 30, 31, 28, 29, 30, 32])
        let replay = try PredictionBacktester.evaluate(periods: periods.reversed(), today: today)
        #expect(replay.rows.count == 8 && replay.warmUpCount == 3 && replay.scored.count == 5)
        for (index, row) in replay.rows.enumerated() {
            #expect(row.sources.count == min(index, 6))
            #expect(row.sources.allSatisfy { $0.nextStart <= row.target.start })
            #expect(!row.sources.contains { $0.id == row.target.id })
            let prefix = try PredictionBacktester.evaluate(periods: Array(periods.prefix(index + 2)), today: today)
            #expect(prefix.rows.last == row)
        }
        var changed = periods
        changed[changed.count - 1].start = try changed.last!.start.adding(days: 50)
        let revised = try PredictionBacktester.evaluate(periods: changed, today: today)
        #expect(revised.rows.last?.outcome == replay.rows.last?.outcome)
        #expect(revised.rows.dropLast() == replay.rows.dropLast())
        #expect(revised.rows.last?.signedError != replay.rows.last?.signedError)
    }

    @Test func emptyWarmUpAndWithheldDenominators() throws {
        let empty = try PredictionBacktester.evaluate(periods: [], today: today)
        #expect(empty.rows.isEmpty && empty.meanAbsoluteError == nil && empty.meanWindowSpan == nil)
        let warmup = try PredictionBacktester.evaluate(periods: history([28, 28, 28]), today: today)
        #expect(warmup.warmUpCount == 3 && warmup.scored.isEmpty && warmup.withheldCount == 0)
        let withheld = try PredictionBacktester.evaluate(periods: history([28, 28, 43, 28]), today: today)
        #expect(withheld.withheldCount == 1 && withheld.warmUpCount == 3 && withheld.scored.isEmpty)
        #expect(withheld.meanAbsoluteError == nil && withheld.coveredCount == 0)
    }

    @Test func errorSignInclusiveCoverageAndSpan() throws {
        for target in [25, 26, 28, 30, 31] {
            let replay = try PredictionBacktester.evaluate(periods: history([28, 28, 28, target]), today: today)
            let row = try #require(replay.scored.first)
            #expect(row.signedError == target - 28)
            #expect(row.covered == (26...30).contains(target))
            #expect(row.windowSpan == 4)
            #expect(row.outsideWindowDays == max(0, abs(target - 28) - 2))
            #expect(replay.meanAbsoluteError == Double(abs(target - 28)))
            #expect(replay.meanWindowSpan == 4)
        }
    }

    @Test func candidatesShareEligibilityAndSources() throws {
        let periods = try history([26, 28, 33, 29, 31, 30, 29, 90, 28])
        let baseline = try PredictionBacktester.evaluate(periods: periods, today: today)
        for candidate in PredictionCandidate.allCases {
            let report = try PredictionBacktester.evaluate(periods: periods, today: today, engine: ComparisonPredictionEngine(candidate: candidate))
            #expect(report.coveredCount == baseline.coveredCount && report.withheldCount == baseline.withheldCount)
            #expect(report.meanWindowSpan == baseline.meanWindowSpan)
            for (a, b) in zip(report.rows, baseline.rows) {
                #expect(a.sources == b.sources && a.estimate?.earliest == b.estimate?.earliest && a.estimate?.latest == b.estimate?.latest)
            }
        }
        let sources = Array(baseline.rows[3].sources)
        let latest = baseline.rows[3].target.start
        for (candidate, expected) in [(PredictionCandidate.median, 28), (.mean, 29), (.recentWeighted, 30)] {
            let outcome = try ComparisonPredictionEngine(candidate: candidate).predict(intervals: sources, latestStart: latest)
            guard case .available(let value) = outcome else { Issue.record("Expected available estimate"); continue }
            #expect(latest.days(until: value.center) == expected)
        }
    }

    @Test func productionPreservesDatesButDowngradesPoorEvidence() throws {
        for lengths in [[28, 29, 30, 28, 29, 30], [28, 28, 28, 28, 28, 35], [28, 28, 43], [1, 1, 1]] {
            let periods = try history(lengths)
            let baseline = CycleCalculator.overview(periods: periods, today: today)
            let production = CycleCalculator.overview(periods: periods, today: today, engine: EvidencePredictionEngine())
            #expect(baseline.estimate?.center == production.estimate?.center)
            #expect(baseline.estimate?.earliest == production.estimate?.earliest)
            #expect(baseline.estimate?.latest == production.estimate?.latest)
        }
        let stable = CycleCalculator.overview(periods: try history([28, 29, 30, 28, 29, 30]), today: today, engine: EvidencePredictionEngine())
        #expect(stable.estimate?.confidence == .moderate)
        let missed = CycleCalculator.overview(periods: try history([28, 28, 28, 28, 28, 35]), today: today, engine: EvidencePredictionEngine())
        #expect(missed.estimate?.confidence == .low)
    }

    private func replay(errors: [Int], withheld: Bool = false) throws -> PredictionReplay {
        let day = try LocalDay(key: 20200101)
        var rows = try errors.map { error in
            let target = CycleInterval(id: UUID(), start: day, nextStart: try day.adding(days: 28 + error))
            let estimate = try CyclePrediction(center: day.adding(days: 28), earliest: day.adding(days: 26),
                                               latest: day.adding(days: 30), confidence: .low, sourceLengths: [28, 28, 28])
            return PredictionReplayRow(target: target, sources: [], outcome: .available(estimate))
        }
        if withheld {
            rows.append(PredictionReplayRow(target: CycleInterval(id: UUID(), start: day, nextStart: try day.adding(days: 28)),
                                            sources: [], outcome: .wideVariation))
        }
        return PredictionReplay(rows: rows)
    }

    @Test func exactConfidenceGatesAndRollingLimit() throws {
        func confidence(_ errors: [Int], lengths: [Int] = Array(repeating: 28, count: 6), withheld: Bool = false) throws -> PredictionConfidence {
            PredictionEvidence.assess(sourceLengths: lengths, replay: try replay(errors: errors, withheld: withheld)).confidence
        }
        #expect(try confidence([0, 0]) == .low)
        #expect(try confidence([0, 0, 0]) == .moderate)
        #expect(try confidence([0, 0, 0], lengths: [28, 28, 28]) == .low)
        #expect(try confidence([0, 0, 0], lengths: [28, 28, 28, 28, 28, 35]) == .moderate)
        #expect(try confidence([0, 0, 0], lengths: [28, 28, 28, 28, 28, 36]) == .low)
        #expect(try confidence([0, 0, 0], withheld: true) == .low)
        #expect(try confidence([0, 0, 0, 0, 15]) == .moderate) // 4/5 covered, MAE exactly 3.
        #expect(try confidence([0, 0, 0, 0, 16]) == .low)
        #expect(try confidence([0, 0, 0, 3]) == .low) // 3/4 below 80%.
        #expect(try confidence([30, 0, 0, 0, 0, 0, 0]) == .moderate) // Only last six checks.
        let actual = try PredictionBacktester.evaluate(periods: history(Array(repeating: 28, count: 12)), today: today)
        let evidence = PredictionEvidence.assess(sourceLengths: Array(repeating: 28, count: 6), replay: actual)
        #expect(actual.warmUpCount == 3 && evidence.recentReplay.rows.count == 6)
        #expect(evidence.recentReplay.warmUpCount == 0 && evidence.confidence == .moderate)
    }

    @Test func invalidDatesAndArithmeticFailuresStayVisible() throws {
        let day = try LocalDay(key: 20200101)
        #expect(throws: TrackingError.duplicateStart) { try PredictionBacktester.evaluate(periods: [Period(start: day), Period(start: day)], today: today) }
        #expect(throws: TrackingError.futureDate) { try PredictionBacktester.evaluate(periods: [Period(start: today.adding(days: 1))], today: today) }
        let end = try LocalDay(key: 99991231)
        let periods = try history([28, 28, 28, 1], start: 99991007)
        let report = try PredictionBacktester.evaluate(periods: periods, today: end)
        #expect(report.withheldCount == 1)
        #expect(report.rows.last?.outcome == .unavailable(.invalidDay))
        let invalid = CycleInterval(id: UUID(), start: day, nextStart: day)
        #expect(throws: TrackingError.invalidData) { try PredictionBacktester.evaluate(intervals: [invalid]) }
    }

    @Test func leapDSTAndUnknownEndUseCivilStartDatesOnly() throws {
        var periods = try history([28, 28, 28, 28, 28, 28], start: 20240202)
        let before = try PredictionBacktester.evaluate(periods: periods, today: today)
        for index in periods.indices { periods[index].end = try periods[index].start.adding(days: 3) }
        #expect(try PredictionBacktester.evaluate(periods: periods, today: today) == before)
        #expect(before.coveredCount == 3 && before.meanAbsoluteError == 0)
    }

    @Test func reproducibleSyntheticComparison() throws {
        let fixtures: [(String, [Int])] = [
            ("constant", Array(repeating: 28, count: 12)),
            ("alternating", [26, 32, 26, 32, 26, 32, 26, 32, 26, 32, 26, 32]),
            ("drift", Array(24...35)),
            ("shift", [28, 28, 28, 28, 28, 35, 35, 35, 35, 35, 35, 35]),
            ("long-gap", [28, 28, 28, 28, 56, 28, 28, 28, 28, 28, 28, 28]),
            ("broad", [20, 40, 25, 45, 21, 42, 24, 44, 20, 40, 25, 45])
        ]
        // Golden totals keep the checked-in comparison table reproducible, not just diagnostic output.
        let expected: [String: (scored: Int, covered: Int, withheld: Int, span: Int, errors: [Int])] = [
            "constant": (9, 9, 0, 36, [0, 0, 0]),
            "alternating": (9, 9, 0, 90, [33, 29, 30]),
            "drift": (9, 9, 0, 75, [25, 25, 24]),
            "shift": (9, 8, 0, 71, [24, 24, 18]),
            "long-gap": (3, 2, 6, 12, [28, 28, 28]),
            "broad": (0, 0, 9, 0, [0, 0, 0])
        ]
        for (name, lengths) in fixtures {
            let golden = try #require(expected[name])
            for (index, candidate) in PredictionCandidate.allCases.enumerated() {
                let report = try PredictionBacktester.evaluate(periods: history(lengths), today: today, engine: ComparisonPredictionEngine(candidate: candidate))
                #expect(report.rows.count == lengths.count)
                #expect(report.rows.count == report.scored.count + report.warmUpCount + report.withheldCount)
                #expect(report.scored.count == golden.scored && report.coveredCount == golden.covered && report.withheldCount == golden.withheld)
                #expect(report.scored.compactMap(\.windowSpan).reduce(0, +) == golden.span)
                #expect(report.scored.compactMap(\.signedError).map { abs($0) }.reduce(0, +) == golden.errors[index])
                print("PHASE4 \(name) \(candidate.rawValue) scored=\(report.scored.count) covered=\(report.coveredCount) withheld=\(report.withheldCount) MAE=\(report.meanAbsoluteError ?? -1) span=\(report.meanWindowSpan ?? -1)")
            }
        }
    }
}

@MainActor struct PhaseFourStateTests {
    @Test func editsDeletesResetAndDateContextRecomputeEvidence() throws {
        let today = try LocalDay(key: 20260929)
        var now = today.formattingDate
        let repository = try SwiftDataPeriodRepository.inMemory()
        let session = TrackerSession(repository: { repository }, clock: { now }, timeZone: { .gmt })
        session.load()
        let periods = try (0..<7).map { Period(start: try today.adding(days: -180 + $0 * 28)) }
        #expect(session.save(periods, completingOnboarding: true) == nil)
        let initial = session.predictionReplay
        #expect(initial?.scored.count == 3 && session.overview?.estimate?.confidence == .moderate)
        #expect(session.saveSymptom(SymptomEntry(day: today, kind: .headache)) == nil)
        #expect(session.predictionReplay == initial)
        var edit = periods.last!
        edit.start = try edit.start.adding(days: 7)
        #expect(session.update(edit) == nil)
        #expect(session.predictionReplay != initial && session.overview?.estimate?.confidence == .low)
        now = try today.adding(days: -30).formattingDate
        session.refresh()
        #expect(session.predictionReplay == nil && session.overview?.estimate == nil)
        now = today.formattingDate
        session.refresh()
        #expect(session.predictionReplay != nil)
        #expect(session.delete(id: edit.id) == nil && session.predictionReplay?.scored.count == 2)
        #expect(session.deleteAll() == nil && session.predictionReplay?.rows.isEmpty == true)
    }
}
