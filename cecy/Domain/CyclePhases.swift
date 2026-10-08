import Foundation

nonisolated enum CyclePhase: String, CaseIterable, Identifiable, Sendable {
    case menstrual, follicular, ovulation, luteal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .menstrual: "Menstrual"
        case .follicular: "Follicular"
        case .ovulation: "Estimated ovulation"
        case .luteal: "Luteal"
        }
    }
    var symbol: String {
        switch self {
        case .menstrual: "drop.fill"
        case .follicular: "leaf"
        case .ovulation: "circle.dotted"
        case .luteal: "moon"
        }
    }
    var explanation: String {
        switch self {
        case .menstrual: "During a period, energy may feel lower."
        case .follicular: "After bleeding ends, energy may begin to rise."
        case .ovulation: "Fertility may be higher around this estimated date. Ovulation is not confirmed."
        case .luteal: "As the next period approaches, PMS symptoms may appear."
        }
    }
    var experiences: String {
        switch self {
        case .menstrual: "Some people notice cramps, tiredness or lower back discomfort."
        case .follicular: "Some notice changing energy, mood or discharge; others notice little change."
        case .ovulation: "Some notice changes in discharge or sex drive. Symptoms cannot confirm ovulation."
        case .luteal: "Some notice breast tenderness, bloating, cravings or mood changes."
        }
    }
}

nonisolated struct CyclePhaseSegment: Identifiable, Equatable, Sendable {
    let phase: CyclePhase
    let days: ClosedRange<Int>
    var id: CyclePhase { phase }
    var count: Int { days.upperBound - days.lowerBound + 1 }
}

/// A day-proportional visualization, not a separate prediction engine or record.
/// Menstruation is biologically part of the follicular phase; the ring separates
/// bleeding days from the remaining follicular days for readability.
nonisolated struct CyclePhaseTimeline: Equatable, Sendable {
    let start: LocalDay
    let length: Int
    let cycleDay: Int
    let segments: [CyclePhaseSegment]
    let recordedBleeding: ClosedRange<Int>
    let fertileDays: ClosedRange<Int>?
    let warnings: [String]
    let bleedingIsEstimated: Bool
    var currentDayHasAnswer = false

    var markerDay: Int? { (1...length).contains(cycleDay) ? cycleDay : nil }
    var currentPhase: CyclePhase? {
        if recordedBleeding.contains(cycleDay) { return .menstrual }
        guard warnings.isEmpty, let day = markerDay else { return nil }
        let phase = segments.first { $0.days.contains(day) }?.phase
        return currentDayHasAnswer && phase == .menstrual ? nil : phase
    }
    var currentIsRecorded: Bool { recordedBleeding.contains(cycleDay) }

    static func make(overview: CycleOverview, forecast: CycleForecast, periods: [Period],
                     profile: LocalProfile?, today: LocalDay) -> Self? {
        guard let start = overview.latestStart, let estimate = overview.estimate,
              let cycle = forecast.cycles.first(where: { $0.index == 0 }), cycle.referenceNotice == nil,
              cycle.period.center == estimate.center, let ovulation = cycle.ovulation,
              let period = periods.first(where: { $0.start == start }) else { return nil }
        let length = start.days(until: estimate.center)
        let ovulationDay = start.days(until: ovulation.center) + 1
        let knownDays = period.duration
        guard let bleedingDays = knownDays ?? BleedingDurationEstimate.calculate(periods: periods, profile: profile, latestStart: start)?.days,
              length > 0, bleedingDays > 0, bleedingDays < ovulationDay, ovulationDay < length else { return nil }
        var segments = [CyclePhaseSegment(phase: .menstrual, days: 1...bleedingDays)]
        if bleedingDays + 1 < ovulationDay {
            segments.append(CyclePhaseSegment(phase: .follicular, days: (bleedingDays + 1)...(ovulationDay - 1)))
        }
        segments.append(CyclePhaseSegment(phase: .ovulation, days: ovulationDay...ovulationDay))
        segments.append(CyclePhaseSegment(phase: .luteal, days: (ovulationDay + 1)...length))
        let fertile = cycle.fertileWindow.flatMap { range -> ClosedRange<Int>? in
            let lower = max(1, start.days(until: range.start) + 1)
            let upper = min(length, start.days(until: range.end) + 1)
            return lower <= upper ? lower...upper : nil
        }
        return Self(start: start, length: length, cycleDay: start.days(until: today) + 1, segments: segments,
                    recordedBleeding: 1...(knownDays ?? 1), fertileDays: fertile,
                    warnings: cycle.ovulationWarnings, bleedingIsEstimated: knownDays == nil,
                    currentDayHasAnswer: forecast.answeredDays.contains(today))
    }

    func dateRange(for phase: CyclePhase) -> ForecastInterval? {
        guard let days = segments.first(where: { $0.phase == phase })?.days,
              let first = try? start.adding(days: days.lowerBound - 1),
              let last = try? start.adding(days: days.upperBound - 1) else { return nil }
        return ForecastInterval(start: first, end: last)
    }

    /// Reuse the existing evidence threshold and start-relative logs. Do not invent
    /// ovulation-linked patterns from symptoms or use missing logs as absence.
    static func patterns(for phase: CyclePhase, insights: [CycleInsight]) -> [CycleInsight] {
        guard phase == .menstrual || phase == .luteal else { return [] }
        return Array(insights.filter { insight in
            guard insight.category == .symptomTiming, insight.matchedStarts >= 3 else { return false }
            let offsets = insight.timing.flatMap { item in item.logDays.map { item.start.days(until: $0) } }
            return !offsets.isEmpty && (phase == .luteal ? offsets.allSatisfy { $0 < 0 } : offsets.allSatisfy { $0 >= 0 })
        }.prefix(3))
    }
}
