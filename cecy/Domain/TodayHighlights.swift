import Foundation

// MARK: - Dynamic cards shown between Today's insights and the upcoming forecast
//
// Built only from the user's own records. At most two cards show, most relevant first,
// so the page changes from day to day without getting longer.

/// The last time the period estimate moved, kept on this device so Today can explain it.
nonisolated struct EstimateShift: Codable, Equatable, Sendable {
    enum Reason: String, Codable, Sendable { case period, factor, records }
    var fromKey: Int
    var toKey: Int
    var dayKey: Int
    var reason: Reason

    func validate() throws {
        _ = try LocalDay(key: fromKey); _ = try LocalDay(key: toKey); _ = try LocalDay(key: dayKey)
    }

    /// Compares the previous and new estimate centers; `nil` when nothing moved.
    static func detect(previousCenter: LocalDay?, newCenter: LocalDay?, previous: TrackerSnapshot,
                       current: TrackerSnapshot, today: LocalDay) -> EstimateShift? {
        guard let previousCenter, let newCenter, previousCenter != newCenter else { return nil }
        let reason: Reason = previous.periods != current.periods ? .period
            : (previous.cycleFactors != current.cycleFactors || previous.p2.lifeStages != current.p2.lifeStages) ? .factor
            : .records
        return EstimateShift(fromKey: previousCenter.key, toKey: newCenter.key, dayKey: today.key, reason: reason)
    }
}

nonisolated enum TodayHighlight: Identifiable, Equatable, Sendable {
    case estimateMoved(days: Int, earlier: Bool, reason: EstimateShift.Reason, center: LocalDay)
    case windowApproaching(days: Int, earliest: LocalDay, latest: LocalDay)
    case cycleRecap(length: Int, periodDays: Int?, symptoms: [SymptomKind], factors: [CycleFactorKind])
    case lastCycleEcho(cycleDay: Int, symptoms: [SymptomKind])
    case activeContext(cycleDay: Int?, factors: [CycleFactorKind], stages: [LifeStageKind])
    case coverage(logged: Int, days: Int)

    var id: String {
        switch self {
        case .estimateMoved: "estimateMoved"
        case .windowApproaching: "windowApproaching"
        case .cycleRecap: "cycleRecap"
        case .lastCycleEcho: "lastCycleEcho"
        case .activeContext: "activeContext"
        case .coverage: "coverage"
        }
    }
}

nonisolated enum TodayHighlights {
    static let maximumCards = 2
    static let coverageDays = 7

    static func make(today: LocalDay, snapshot: TrackerSnapshot, overview: CycleOverview,
                     shift: EstimateShift?) -> [TodayHighlight] {
        var cards: [TodayHighlight] = []
        if let value = estimateMoved(today: today, overview: overview, shift: shift) { cards.append(value) }
        if let value = windowApproaching(today: today, overview: overview) { cards.append(value) }
        if let value = cycleRecap(today: today, snapshot: snapshot, overview: overview) { cards.append(value) }
        if let value = lastCycleEcho(today: today, snapshot: snapshot, overview: overview) { cards.append(value) }
        if let value = activeContext(today: today, snapshot: snapshot, overview: overview) { cards.append(value) }
        if cards.count < maximumCards { cards.append(coverage(today: today, snapshot: snapshot)) }
        return Array(cards.prefix(maximumCards))
    }

    static func estimateMoved(today: LocalDay, overview: CycleOverview, shift: EstimateShift?) -> TodayHighlight? {
        guard let shift, case .available(let estimate) = overview.prediction, estimate.center.key == shift.toKey,
              let shiftDay = try? LocalDay(key: shift.dayKey), let from = try? LocalDay(key: shift.fromKey),
              (0...2).contains(shiftDay.days(until: today)) else { return nil }
        let moved = from.days(until: estimate.center)
        guard moved != 0 else { return nil }
        return .estimateMoved(days: abs(moved), earlier: moved < 0, reason: shift.reason, center: estimate.center)
    }

    static func windowApproaching(today: LocalDay, overview: CycleOverview) -> TodayHighlight? {
        guard case .available(let estimate) = overview.prediction else { return nil }
        let days = today.days(until: estimate.earliest)
        guard (1...3).contains(days) else { return nil }
        return .windowApproaching(days: days, earliest: estimate.earliest, latest: estimate.latest)
    }

    /// The interval that ended when the current cycle began.
    static func previousInterval(_ overview: CycleOverview) -> CycleInterval? {
        guard let latest = overview.latestStart else { return nil }
        return (overview.intervals + overview.excludedIntervals).first { $0.nextStart == latest }
    }

    static func cycleRecap(today: LocalDay, snapshot: TrackerSnapshot, overview: CycleOverview) -> TodayHighlight? {
        guard let latest = overview.latestStart, (0...4).contains(latest.days(until: today)),
              let interval = previousInterval(overview), let lastDay = try? interval.nextStart.adding(days: -1) else { return nil }
        let period = snapshot.periods.first { $0.start == interval.start }
        let periodDays = period.flatMap { snapshot.potentialEnd(for: $0) }.map { interval.start.days(until: $0) + 1 }
        let symptoms = topSymptoms(snapshot.symptoms.filter { $0.day >= interval.start && $0.day <= lastDay }, limit: 3)
        var factors: [CycleFactorKind] = []
        for factor in snapshot.cycleFactors where factor.overlaps(start: interval.start, end: lastDay) && !factors.contains(factor.kind) {
            factors.append(factor.kind)
        }
        return .cycleRecap(length: interval.length, periodDays: periodDays, symptoms: symptoms, factors: factors)
    }

    static func lastCycleEcho(today: LocalDay, snapshot: TrackerSnapshot, overview: CycleOverview) -> TodayHighlight? {
        guard let cycleDay = overview.currentDay, cycleDay >= 6,
              let previous = previousInterval(overview), cycleDay <= previous.length,
              let target = try? previous.start.adding(days: cycleDay - 1),
              let from = try? target.adding(days: -1), let through = try? target.adding(days: 1) else { return nil }
        let symptoms = topSymptoms(snapshot.symptoms.filter { $0.day >= from && $0.day <= through && $0.day < previous.nextStart }, limit: 3)
        guard !symptoms.isEmpty else { return nil }
        return .lastCycleEcho(cycleDay: cycleDay, symptoms: symptoms)
    }

    static func activeContext(today: LocalDay, snapshot: TrackerSnapshot, overview: CycleOverview) -> TodayHighlight? {
        var factors: [CycleFactorKind] = []
        for factor in snapshot.cycleFactors where factor.start <= today && (factor.end.map { $0 >= today } ?? true) {
            if !factors.contains(factor.kind) { factors.append(factor.kind) }
        }
        var stages: [LifeStageKind] = []
        for episode in snapshot.p2.lifeStages where episode.contains(today) && !stages.contains(episode.kind) {
            stages.append(episode.kind)
        }
        // Life stages already appear as factors in forecasts; show each meaning once.
        factors.removeAll { kind in stages.contains { $0.factorKind == kind } }
        guard !factors.isEmpty || !stages.isEmpty else { return nil }
        return .activeContext(cycleDay: overview.currentDay, factors: factors, stages: stages)
    }

    static func coverage(today: LocalDay, snapshot: TrackerSnapshot) -> TodayHighlight {
        var days = Set<LocalDay>()
        let start = (try? today.adding(days: -(coverageDays - 1))) ?? today
        func add(_ day: LocalDay) { if day >= start && day <= today { days.insert(day) } }
        snapshot.symptoms.forEach { add($0.day) }
        snapshot.dailyBleeding.forEach { add($0.day) }
        snapshot.sexualActivities.forEach { add($0.day) }
        snapshot.p2.biomarkers.forEach { add($0.day) }
        snapshot.treatmentAdherence.forEach { add($0.day) }
        var day = start
        while day <= today {
            if snapshot.resolvedPeriods.contains(where: { $0.contains(day) }) { days.insert(day) }
            guard let next = try? day.adding(days: 1) else { break }
            day = next
        }
        return .coverage(logged: days.count, days: coverageDays)
    }

    /// Most frequently logged first; ties follow the catalog order so results are stable.
    static func topSymptoms(_ entries: [SymptomEntry], limit: Int) -> [SymptomKind] {
        var counts: [SymptomKind: Int] = [:]
        for entry in entries { counts[entry.kind, default: 0] += 1 }
        let order = Dictionary(uniqueKeysWithValues: SymptomKind.allCases.enumerated().map { ($1, $0) })
        return counts.keys.sorted { (counts[$0]!, -(order[$0] ?? 0)) > (counts[$1]!, -(order[$1] ?? 0)) }
            .prefix(limit).map { $0 }
    }
}
