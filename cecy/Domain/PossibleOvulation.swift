import Foundation

/// Inclusive civil-day interval, not a probability distribution or a health record.
nonisolated struct ForecastInterval: Equatable, Sendable {
    let start: LocalDay
    let end: LocalDay
    func contains(_ day: LocalDay) -> Bool { start <= day && day <= end }
}

nonisolated struct BleedingDurationEstimate: Equatable, Sendable {
    let days: Int
    let minimum: Int
    let maximum: Int
    let measuredCount: Int

    static func calculate(periods: [Period], profile: LocalProfile?, latestStart: LocalDay) -> Self? {
        // Only explicit end dates, never an assumed end derived from the profile.
        let values = Array(periods.filter { $0.start <= latestStart }
            .sorted { $0.start < $1.start }.compactMap(\.duration).suffix(6)).sorted()
        if let first = values.first, let last = values.last, first > 0 {
            let middle = values.count / 2
            let median = values.count.isMultiple(of: 2)
                ? (Double(values[middle - 1]) + Double(values[middle])) / 2 : Double(values[middle])
            return Self(days: Int(median.rounded(.toNearestOrAwayFromZero)), minimum: first,
                        maximum: last, measuredCount: values.count)
        }
        guard let days = profile?.typicalPeriodDays, CycleSetupPolicy.periodDays.contains(days) else { return nil }
        return Self(days: days, minimum: days, maximum: days, measuredCount: 0)
    }
}

nonisolated struct ForecastWindow: Equatable, Sendable {
    let center: LocalDay
    let earliest: LocalDay
    let latest: LocalDay
    func contains(_ day: LocalDay) -> Bool { earliest <= day && day <= latest }
}

nonisolated struct ProjectedCycle: Identifiable, Equatable, Sendable {
    let index: Int
    let period: ForecastWindow
    let ovulation: ForecastWindow?
    var bleeding: ForecastInterval?
    var bleedingEnvelope: ForecastInterval?
    var bleedingDuration: BleedingDurationEstimate?
    var fertileWindow: ForecastInterval?
    var fertileEnvelope: ForecastInterval?
    var ovulationWarnings: [String] = []
    var ovulationBasis: String = "Calendar estimate only; ovulation is not confirmed."
    var referenceNotice: String?
    var id: Int { index }
    var isLaterProjection: Bool { index > 0 }
    var assumption: String {
        isLaterProjection
            ? "Projection assumes earlier estimated periods occur near their predicted dates. No period has been added to your records."
            : "Estimate based on your latest recorded start and available cycle lengths."
    }

    func contains(_ day: LocalDay) -> Bool {
        period.contains(day) || bleeding?.contains(day) == true
            || ovulation?.center == day || fertileWindow?.contains(day) == true
    }
}

/// Display-only projections. Never used to manufacture records, advance an overdue
/// primary estimate, schedule extra reminders, or score prediction accuracy.
nonisolated struct CycleForecast: Equatable, Sendable {
    var cycles: [ProjectedCycle] = []
    var ovulationUnavailableReason: String?

    func nextPeriod(onOrAfter day: LocalDay) -> ProjectedCycle? {
        cycles.first { $0.period.center >= day }
    }

    func period(on day: LocalDay) -> ProjectedCycle? { cycles.first { $0.period.contains(day) } }
    // An uncertainty envelope is not a series of ovulation days or a fertile window.
    func ovulation(on day: LocalDay) -> ProjectedCycle? { cycles.first { $0.ovulation?.center == day } }
    func bleeding(on day: LocalDay) -> ProjectedCycle? { cycles.first { $0.bleeding?.contains(day) == true } }
    func fertile(on day: LocalDay) -> ProjectedCycle? { cycles.first { $0.fertileWindow?.contains(day) == true } }
    func additionalDayDescription(_ day: LocalDay) -> String {
        var parts: [String] = []
        if bleeding(on: day) != nil { parts.append("Expected bleeding day, not recorded") }
        if let cycle = fertile(on: day) {
            parts.append("Estimated fertile window, not confirmed; other days are not safe days")
            if !cycle.ovulationWarnings.isEmpty { parts.append("Timing may not apply with your cycle context") }
        }
        if cycles.contains(where: { $0.isLaterProjection && $0.contains(day) }) {
            parts.append("Future-cycle projection assumes unrecorded periods")
        }
        return parts.isEmpty ? "" : ". " + parts.joined(separator: ". ")
    }
    func nextOvulation(onOrAfter day: LocalDay) -> ProjectedCycle? {
        cycles.first { cycle in
            guard let center = cycle.ovulation?.center else { return false }
            return center >= day
        }
    }

    static func calculate(overview: CycleOverview, profile: LocalProfile?, periods: [Period] = [],
                          asOf today: LocalDay? = nil) -> CycleForecast {
        let eligible = ForecastAvailabilityPolicy.applying(to: overview)
        guard let start = eligible.latestStart, let estimate = eligible.estimate else {
            return CycleForecast(ovulationUnavailableReason: "Ovulation timing unavailable.")
        }
        // Exactly the same rounded median (or entered usual length) as the period engine.
        let length = start.days(until: estimate.center)
        guard length > 0 else { return CycleForecast() }
        let warnings = OvulationNotice.contextWarnings(profile?.cycleContext ?? [])
        let duration = BleedingDurationEstimate.calculate(periods: periods, profile: profile, latestStart: start)
        let basis = estimate.basis == .usualCycle
            ? "Based on your entered \(length)-day typical cycle, not measured cycle history."
            : "Based on \(estimate.sourceLengths.count) measured start-to-start interval(s). Period dates alone cannot reliably identify ovulation."
        var result = CycleForecast()
        // Retain the original three for calendar history, plus the cycle preceding
        // today's next center and three upcoming centers. Bounded work even after years.
        let elapsed = today.map { estimate.center.days(until: $0) } ?? 0
        let nextIndex = elapsed > 0 ? (elapsed + length - 1) / length : 0
        let indices = Set(0..<3).union(max(0, nextIndex - 1)...(nextIndex + 2)).sorted()
        for index in indices {
            // Propagate each cycle's start-offset uncertainty; never claim independent
            // errors or statistical coverage. The primary period window stays unchanged.
            guard let center = try? estimate.center.adding(days: index * length),
                  let earliest = try? start.adding(days: (index + 1) * start.days(until: estimate.earliest)),
                  let latest = try? start.adding(days: (index + 1) * start.days(until: estimate.latest)) else { break }
            let period = ForecastWindow(center: center, earliest: earliest, latest: latest)
            guard let previousStart = try? start.adding(days: index * length) else { break }
            var ovulation: ForecastWindow?
            // NHS describes roughly 10–16 days between ovulation and the next period.
            // This is not an individually measured luteal phase or a guaranteed bound.
            if let ovulationCenter = try? center.adding(days: -14),
               let lower = try? earliest.adding(days: -16),
               let upper = try? latest.adding(days: -10),
               let fertileStart = try? ovulationCenter.adding(days: -5),
               fertileStart >= previousStart, ovulationCenter < center {
                ovulation = ForecastWindow(center: ovulationCenter, earliest: lower, latest: upper)
            }
            var cycle = ProjectedCycle(index: index, period: period, ovulation: ovulation,
                                       ovulationWarnings: warnings, ovulationBasis: basis)
            if let duration, duration.maximum < length,
               let end = try? center.adding(days: duration.days - 1),
               let envelopeEnd = try? latest.adding(days: duration.maximum - 1) {
                cycle.bleedingDuration = duration
                cycle.bleeding = ForecastInterval(start: center, end: end)
                cycle.bleedingEnvelope = ForecastInterval(start: earliest, end: envelopeEnd)
            }
            if let ovulation,
               let fertileStart = try? ovulation.center.adding(days: -5),
               let envelopeStart = try? ovulation.earliest.adding(days: -5) {
                cycle.fertileWindow = ForecastInterval(start: fertileStart, end: ovulation.center)
                cycle.fertileEnvelope = ForecastInterval(start: envelopeStart, end: ovulation.latest)
            }
            result.cycles.append(cycle)
        }
        if result.cycles.allSatisfy({ $0.ovulation == nil }), result.ovulationUnavailableReason == nil {
            result.ovulationUnavailableReason = "Cycle length or uncertainty does not support a separate ovulation estimate."
        }
        return result
    }
}

nonisolated extension CycleOverview {
    /// First-cycle compatibility accessor. Calendars use the full cached forecast.
    var possibleOvulation: LocalDay? {
        CycleForecast.calculate(overview: self, profile: nil).cycles.first?.ovulation?.center
    }
}

nonisolated enum OvulationNotice {
    static let explanation = "The single green dotted date estimates ovulation about 14 days before a projected period; it does not detect it. Leaf markers show an estimated six-day fertile window ending on that date, not six days of ovulation. Timing uncertainty uses an approximate 10–16-day offset and can extend beyond the highlighted days. Period history cannot measure your individual ovulation timing, even with regular cycles. Context such as hormonal contraception can make these estimates inapplicable. Later projections are less certain. Unmarked days are not safe days. Do not use these estimates for contraception, diagnosis or as the sole guide for conception."

    static func contextWarnings(_ contexts: Set<CycleContext>) -> [String] {
        CycleContext.allCases.filter { contexts.contains($0) }.compactMap { context in
            switch context {
            case .hormonalBirthControl:
                "Hormonal birth control: some methods prevent ovulation and bleeding may not indicate a natural cycle. Cecy does not know your method; this date may not apply and is not a prediction that you will ovulate."
            case .recentlyStoppedBirthControl:
                "Recently stopped birth control: ovulation can return before cycle timing becomes predictable. This calendar date is especially uncertain."
            case .postpartum:
                "Postpartum: ovulation can return before the first period. Previous cycle lengths may not describe your current timing."
            case .breastfeeding:
                "Breastfeeding: ovulation may be delayed or unpredictable, but can still occur. A calendar date cannot establish protection from pregnancy."
            case .perimenopause:
                "Perimenopause: cycles and ovulation can become irregular, and some cycles may have no ovulation. This is only a calendar reference."
            default: nil
            }
        }
    }
}
