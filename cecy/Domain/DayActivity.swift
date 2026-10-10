import Foundation

nonisolated struct DayActivityMarker: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let title: String

    /// Presentation only: predictions never become recorded activities.
    static func calendar(recorded: [Self], forecast: CycleForecast, day: LocalDay) -> [Self] {
        var estimates: [Self] = []
        if !recorded.contains(where: { $0.id == "period" || $0.id == "dailyBleeding" }), forecast.bleeding(on: day) != nil {
            estimates.append(Self(id: "forecast.bleeding", symbol: "drop", title: "Estimated period day, not recorded"))
        }
        if forecast.fertile(on: day) != nil {
            estimates.append(Self(id: "forecast.fertile", symbol: "leaf", title: "Estimated fertile window"))
        }
        let symptoms = recorded.filter { $0.id.hasPrefix("symptom.") }
        var compact = recorded.filter { !$0.id.hasPrefix("symptom.") }
        if !symptoms.isEmpty {
            let position = compact.firstIndex { $0.id == "sexualActivity" } ?? compact.endIndex
            compact.insert(Self(id: "symptoms", symbol: "waveform.path.ecg",
                                title: symptoms.map(\.title).joined(separator: ", ")), at: position)
        }
        return estimates + compact
    }

    static func recorded(on day: LocalDay, in snapshot: TrackerSnapshot) -> [Self] {
        var markers: [Self] = []
        let period = PeriodLogSelection.existing(on: day, periods: snapshot.periods, dailyBleeding: snapshot.dailyBleeding)
        if let period {
            markers.append(Self(id: "period", symbol: "drop.fill", title: period.start == day ? "Period start" : "Confirmed bleeding"))
        }
        if let answer = snapshot.dailyBleeding.first(where: { $0.day == day }),
           !isPeriodDay(answer, periods: snapshot.periods) {
            markers.append(daily(answer))
        }
        let kinds = Set(snapshot.symptoms.filter { $0.day == day }.map(\.kind))
        for kind in SymptomKind.allCases where kinds.contains(kind) {
            markers.append(Self(id: "symptom.\(kind.rawValue)", symbol: kind.symbol, title: kind.title))
        }
        if let activity = snapshot.sexualActivities.first(where: { $0.day == day }) {
            markers.append(Self(id: "sexualActivity", symbol: "heart.fill", title: "Sexual activity: \(activity.summary)"))
        }
        return markers
    }

    static func daily(_ answer: DailyBleedingObservation) -> Self {
        Self(id: "dailyBleeding", symbol: answer.state.symbol, title: "Daily answer: \(answer.state.title)")
    }

    static func isPeriodDay(_ answer: DailyBleedingObservation, periods: [Period]) -> Bool {
        guard answer.state == .bleeding, let id = answer.periodID,
              let period = periods.first(where: { $0.id == id }) else { return false }
        return DailyBleedingValidation.canAssociate(answer.day, with: period, periods: periods)
    }
}

/// Bounded lookups for calendar cells. Confirmed spans are not expanded into stored days.
nonisolated struct DayActivityIndex: Equatable, Sendable {
    private let periods: [Period]
    private let observations: [LocalDay: [DayActivityMarker]]

    init(snapshot: TrackerSnapshot = TrackerSnapshot()) {
        periods = snapshot.periods.sorted { $0.start < $1.start }
        var values: [LocalDay: [DayActivityMarker]] = [:]
        for (day, entries) in Dictionary(grouping: snapshot.symptoms, by: \.day) {
            let kinds = Set(entries.map(\.kind))
            values[day] = SymptomKind.allCases.filter { kinds.contains($0) }.map {
                DayActivityMarker(id: "symptom.\($0.rawValue)", symbol: $0.symbol, title: $0.title)
            }
        }
        for (day, entries) in Dictionary(grouping: snapshot.sexualActivities, by: \.day) {
            if let activity = entries.first {
                values[day, default: []].append(DayActivityMarker(id: "sexualActivity", symbol: "heart.fill",
                    title: "Sexual activity: \(activity.summary)"))
            }
        }
        for answer in snapshot.dailyBleeding {
            let marker = DayActivityMarker.isPeriodDay(answer, periods: periods)
                ? DayActivityMarker(id: "period", symbol: "drop.fill", title: "Confirmed bleeding")
                : .daily(answer)
            values[answer.day, default: []].insert(marker, at: 0)
        }
        observations = values
    }

    /// A bounded page of actual logs, including confirmed bleeding days only.
    func loggedDays(before boundary: LocalDay? = nil, limit: Int = 30) -> [LocalDay] {
        guard limit > 0 else { return [] }
        var days = Set(observations.keys.filter { day in boundary.map { day < $0 } ?? true }
            .sorted(by: >).prefix(limit))
        for period in periods.reversed() {
            var day = period.end ?? period.start
            if let boundary, day >= boundary {
                guard let previous = try? boundary.adding(days: -1) else { continue }
                day = previous
            }
            for _ in 0..<limit {
                guard day >= period.start else { break }
                days.insert(day)
                guard day > period.start, let previous = try? day.adding(days: -1) else { break }
                day = previous
            }
            days = Set(days.sorted(by: >).prefix(limit))
            if days.count == limit, let oldest = days.min(), period.start <= oldest { break }
        }
        return days.sorted(by: >)
    }

    func markers(on day: LocalDay) -> [DayActivityMarker] {
        var lower = 0
        var upper = periods.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if periods[middle].start <= day { lower = middle + 1 } else { upper = middle }
        }
        var result = observations[day] ?? []
        if lower > 0, periods[lower - 1].contains(day) {
            let period = periods[lower - 1]
            result.removeAll { $0.id == "period" }
            result.insert(DayActivityMarker(id: "period", symbol: "drop.fill",
                title: period.start == day ? "Period start" : "Confirmed bleeding"), at: 0)
        }
        return result
    }
}
