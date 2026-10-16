import Foundation

// MARK: - Life stages (P2.1 / P2.2)

nonisolated enum LifeStageKind: String, Codable, CaseIterable, Sendable {
    case cycleChange, postpartum, breastfeeding

    var title: String {
        switch self {
        case .cycleChange: String(localized: "Perimenopause or cycle change")
        case .postpartum: String(localized: "Postpartum recovery")
        case .breastfeeding: String(localized: "Breastfeeding or chestfeeding")
        }
    }

    var symbol: String {
        switch self {
        case .cycleChange: "arrow.triangle.2.circlepath"
        case .postpartum: "figure.and.child.holdinghands"
        case .breastfeeding: "heart.circle"
        }
    }

    var relevantSymptoms: [SymptomKind] {
        switch self {
        case .cycleChange:
            [.hotFlashes, .nightSweats, .vaginalDryness, .sleepQuality, .insomnia,
             .moodChanges, .brainFog, .urinaryDiscomfort, .libido]
        case .postpartum:
            [.pelvicPain, .fatigue, .sleepQuality, .lowMood, .anxiety, .breastTenderness]
        case .breastfeeding:
            [.breastTenderness, .vaginalDryness, .fatigue, .sleepQuality, .lowMood]
        }
    }

    /// Postpartum and feeding gaps distort cycle averages, so they are excluded by default.
    /// Cycle change is the pattern being observed, so it stays included by default.
    var defaultExcludesForecast: Bool { self != .cycleChange }

    var factorKind: CycleFactorKind {
        switch self {
        case .cycleChange: .perimenopause
        case .postpartum: .postpartum
        case .breastfeeding: .breastfeeding
        }
    }

}

nonisolated enum FeedingContext: String, Codable, CaseIterable, Sendable {
    case breastfeeding, chestfeeding, pumping, formula, combination, notRecorded
    var title: String {
        switch self {
        case .breastfeeding: String(localized: "Breastfeeding")
        case .chestfeeding: String(localized: "Chestfeeding")
        case .pumping: String(localized: "Pumping")
        case .formula: String(localized: "Formula feeding")
        case .combination: String(localized: "Combination feeding")
        case .notRecorded: String(localized: "Prefer not to record")
        }
    }
}

nonisolated struct LifeStageEpisode: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var kind: LifeStageKind
    var start: LocalDay
    var end: LocalDay?
    var feedingContext: FeedingContext?
    /// `nil` uses the kind's default; an explicit value records the user's choice.
    var forecastExclusion: Bool?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), kind: LifeStageKind, start: LocalDay, end: LocalDay? = nil,
         feedingContext: FeedingContext? = nil, forecastExclusion: Bool? = nil, notes: String? = nil,
         createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.feedingContext = feedingContext
        self.forecastExclusion = forecastExclusion
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var excludesFromForecast: Bool { forecastExclusion ?? kind.defaultExcludesForecast }
    func contains(_ day: LocalDay) -> Bool { start <= day && (end.map { day <= $0 } ?? true) }
    func overlaps(start rangeStart: LocalDay, end rangeEnd: LocalDay) -> Bool {
        start <= rangeEnd && (end ?? rangeEnd) >= rangeStart
    }
}

nonisolated enum PostpartumBleedingState: String, Codable, CaseIterable, Sendable {
    case lochia, spotting, bleeding, notSure
    var title: String {
        switch self {
        case .lochia: String(localized: "Postpartum discharge (lochia)")
        case .spotting: String(localized: "Spotting")
        case .bleeding: String(localized: "Bleeding — not recorded as a period")
        case .notSure: String(localized: "Not sure")
        }
    }
}

nonisolated struct PostpartumBleedingEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var day: LocalDay
    var state: PostpartumBleedingState
    var flow: PeriodFlow?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), day: LocalDay, state: PostpartumBleedingState,
         flow: PeriodFlow? = nil, notes: String? = nil,
         createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.state = state
        self.flow = flow
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

// MARK: - Biomarkers (P2.3)

nonisolated enum BiomarkerKind: String, Codable, CaseIterable, Sendable {
    case basalBodyTemperature, lhTest, cervicalMucus, restingHeartRate, sleepDuration, pregnancyTest
    var title: String {
        switch self {
        case .basalBodyTemperature: String(localized: "Basal body temperature")
        case .lhTest: String(localized: "LH / ovulation test")
        case .cervicalMucus: String(localized: "Cervical mucus or discharge")
        case .restingHeartRate: String(localized: "Resting heart rate")
        case .sleepDuration: String(localized: "Sleep duration")
        case .pregnancyTest: String(localized: "Pregnancy test")
        }
    }
    /// Canonical stored unit. Temperatures are always stored in °C.
    var unit: String? {
        switch self {
        case .basalBodyTemperature: "°C"
        case .restingHeartRate: "bpm"
        case .sleepDuration: String(localized: "hours")
        default: nil
        }
    }
    var supportsNumericValue: Bool { unit != nil }
    var allowedResults: [BiomarkerResult] {
        switch self {
        case .lhTest, .pregnancyTest: [.negative, .positive, .high, .invalid, .notSure]
        case .cervicalMucus: [.dry, .sticky, .creamy, .watery, .eggWhite, .notSure]
        default: []
        }
    }

    func displayUnit(_ system: MeasurementSystem) -> String? {
        self == .basalBodyTemperature && system == .imperial ? "°F" : unit
    }
    func displayValue(_ stored: Double, system: MeasurementSystem) -> Double {
        self == .basalBodyTemperature && system == .imperial ? stored * 9 / 5 + 32 : stored
    }
    func storedValue(_ display: Double, system: MeasurementSystem) -> Double {
        self == .basalBodyTemperature && system == .imperial ? (display - 32) * 5 / 9 : display
    }
}

nonisolated enum BiomarkerResult: String, Codable, CaseIterable, Sendable {
    case negative, positive, high, invalid, dry, sticky, creamy, watery, eggWhite, notSure
    var title: String {
        switch self {
        case .negative: String(localized: "Negative")
        case .positive: String(localized: "Positive")
        case .high: String(localized: "High")
        case .invalid: String(localized: "Invalid")
        case .dry: String(localized: "Dry")
        case .sticky: String(localized: "Sticky")
        case .creamy: String(localized: "Creamy")
        case .watery: String(localized: "Watery")
        case .eggWhite: String(localized: "Egg-white")
        case .notSure: String(localized: "Not sure")
        }
    }
}

nonisolated enum RecordProvenance: String, Codable, Sendable {
    case manual, appleHealth
    var title: String {
        switch self {
        case .manual: String(localized: "Entered in Cecy")
        case .appleHealth: String(localized: "Imported from Apple Health")
        }
    }
}

nonisolated struct BiomarkerEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var day: LocalDay
    var kind: BiomarkerKind
    var numericValue: Double?
    var result: BiomarkerResult?
    var provenance: RecordProvenance
    var sourceName: String?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), day: LocalDay, kind: BiomarkerKind,
         numericValue: Double? = nil, result: BiomarkerResult? = nil,
         provenance: RecordProvenance = .manual, sourceName: String? = nil, notes: String? = nil,
         createdAt: Date = Date(), updatedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.kind = kind
        self.numericValue = numericValue
        self.result = result
        self.provenance = provenance
        self.sourceName = sourceName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var valueText: String { valueText(system: .metric) }

    func valueText(system: MeasurementSystem) -> String {
        if let numericValue, let unit = kind.displayUnit(system) {
            let shown = kind.displayValue(numericValue, system: system)
            return "\(shown.formatted(.number.precision(.fractionLength(0...2)))) \(unit)"
        }
        return result?.title ?? String(localized: "No result recorded")
    }
}

nonisolated struct BiomarkerPoint: Equatable, Sendable {
    let day: LocalDay
    let value: Double
}

/// Descriptive statistics over saved readings only. Never used for forecasts or fertility status.
nonisolated struct BiomarkerTrend: Equatable, Sendable {
    let kind: BiomarkerKind
    let start: LocalDay
    let end: LocalDay
    let points: [BiomarkerPoint]
    let resultCounts: [BiomarkerResult: Int]
    let recordedDays: Int
    var totalDays: Int { start.days(until: end) + 1 }
    var minimum: Double? { points.map(\.value).min() }
    var maximum: Double? { points.map(\.value).max() }

    static func make(kind: BiomarkerKind, entries: [BiomarkerEntry], through end: LocalDay, days: Int = 90) -> BiomarkerTrend {
        let start = (try? end.adding(days: -(max(1, days) - 1))) ?? end
        let selected = entries.filter { $0.kind == kind && $0.day >= start && $0.day <= end }
            .sorted { ($0.day, $0.createdAt) < ($1.day, $1.createdAt) }
        let points = selected.compactMap { entry in entry.numericValue.map { BiomarkerPoint(day: entry.day, value: $0) } }
        var counts: [BiomarkerResult: Int] = [:]
        for entry in selected { if let result = entry.result { counts[result, default: 0] += 1 } }
        return BiomarkerTrend(kind: kind, start: start, end: end, points: points, resultCounts: counts,
                              recordedDays: Set(selected.map(\.day)).count)
    }

    func summary(system: MeasurementSystem) -> String {
        let coverage = String(localized: "Recorded on \(recordedDays) of \(totalDays) days.")
        if let minimum, let maximum, let unit = kind.displayUnit(system) {
            let low = kind.displayValue(minimum, system: system).formatted(.number.precision(.fractionLength(0...2)))
            let high = kind.displayValue(maximum, system: system).formatted(.number.precision(.fractionLength(0...2)))
            return coverage + " " + String(localized: "Range \(low)–\(high) \(unit).")
        }
        let results = kind.allowedResults.compactMap { result in resultCounts[result].map { "\(result.title): \($0)" } }
        return results.isEmpty ? coverage : coverage + " " + results.joined(separator: " · ")
    }
}

// MARK: - Insight quality (P2.7)

nonisolated enum InsightFeedbackReason: String, Codable, CaseIterable, Sendable {
    case usefulEvidence, easyToUnderstand, repetitive, insufficientEvidence, notRelevant, unclear
    var title: String {
        switch self {
        case .usefulEvidence: String(localized: "The evidence was useful")
        case .easyToUnderstand: String(localized: "It was easy to understand")
        case .repetitive: String(localized: "It felt repetitive")
        case .insufficientEvidence: String(localized: "There was not enough evidence")
        case .notRelevant: String(localized: "It was not relevant")
        case .unclear: String(localized: "It was unclear")
        }
    }
    var isPositive: Bool { self == .usefulEvidence || self == .easyToUnderstand }
}

nonisolated struct InsightFeedback: Codable, Equatable, Identifiable, Sendable {
    var id: String { insightID }
    /// Evidence fingerprint of the rated insight, so changed evidence can resurface.
    let insightID: String
    var helpful: Bool
    var reasons: Set<InsightFeedbackReason>
    var updatedAt: Date
}

nonisolated enum InsightQuality {
    /// Stable while the supporting evidence is unchanged; changes when new records alter the observation.
    static func fingerprint(_ insight: CycleInsight) -> String {
        let values = (insight.previousValues + [-1] + insight.recentValues).map(String.init).joined(separator: ",")
        return "\(insight.id)|\(insight.rangeStart.key)-\(insight.rangeEnd.key)|\(insight.matchedStarts)/\(insight.timing.count)|\(values)"
    }

    /// Hides insights marked not helpful until their evidence changes. Material changes come first.
    static func arrange(_ insights: [CycleInsight], feedback: [InsightFeedback]) -> (visible: [CycleInsight], hidden: [CycleInsight]) {
        let dismissed = Set(feedback.filter { !$0.helpful }.map(\.insightID))
        let hidden = insights.filter { dismissed.contains(fingerprint($0)) }
        let visible = Array(insights.enumerated()).filter { !dismissed.contains(fingerprint($0.element)) }.sorted { lhs, rhs in
            let left = rank(lhs.element), right = rank(rhs.element)
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
        return (visible, hidden)
    }

    private static func rank(_ insight: CycleInsight) -> Int {
        (insight.category == .symptomTiming ? 2 : 0) + (insight.evidence == .repeated ? 0 : 1)
    }

    static func coverage(_ insight: CycleInsight) -> String {
        if insight.timing.isEmpty {
            return String(localized: "Compares \(insight.previousValues.count) earlier and \(insight.recentValues.count) recent completed records.")
        }
        return String(localized: "\(insight.matchedStarts) of \(insight.timing.count) eligible period starts had a matching observation nearby.")
    }

    static func strengthening(_ insight: CycleInsight) -> String {
        if !insight.timing.isEmpty {
            return insight.matchedStarts < insight.timing.count
                ? String(localized: "Logging this symptom around upcoming period starts would make this clearer. Unlogged days stay unknown.")
                : String(localized: "Each additional period start with nearby logging keeps this view current.")
        }
        return String(localized: "Each newly completed cycle updates the recent group. Dated factors such as illness or travel help explain unusual intervals.")
    }
}

// MARK: - Storage payload

nonisolated struct P2Data: Codable, Equatable, Sendable {
    var lifeStages: [LifeStageEpisode] = []
    var postpartumBleeding: [PostpartumBleedingEntry] = []
    var biomarkers: [BiomarkerEntry] = []
    var insightFeedback: [InsightFeedback] = []

    var isEmpty: Bool { lifeStages.isEmpty && postpartumBleeding.isEmpty && biomarkers.isEmpty && insightFeedback.isEmpty }

    func activeLifeStages(on day: LocalDay) -> [LifeStageEpisode] {
        lifeStages.filter { $0.contains(day) }.sorted { $0.start > $1.start }
    }
}

nonisolated enum P2RecordValidation {
    static func validate(_ data: P2Data, asOf today: LocalDay? = nil) throws {
        guard Set(data.lifeStages.map(\.id)).count == data.lifeStages.count,
              Set(data.postpartumBleeding.map(\.id)).count == data.postpartumBleeding.count,
              Set(data.biomarkers.map(\.id)).count == data.biomarkers.count,
              Set(data.insightFeedback.map(\.insightID)).count == data.insightFeedback.count else {
            throw TrackingError.invalidData
        }
        for episode in data.lifeStages {
            guard episode.end.map({ $0 >= episode.start }) ?? true,
                  (episode.notes?.count ?? 0) <= PeriodValidation.maximumNoteLength,
                  episode.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  episode.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                  episode.updatedAt >= episode.createdAt,
                  episode.kind == .postpartum || episode.feedingContext == nil else { throw TrackingError.invalidData }
            if let today, episode.start > today || (episode.end.map { $0 > today } ?? false) { throw TrackingError.futureDate }
        }
        for entry in data.postpartumBleeding {
            guard entry.state == .bleeding || entry.flow == nil,
                  (entry.notes?.count ?? 0) <= PeriodValidation.maximumNoteLength,
                  entry.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt >= entry.createdAt,
                  data.lifeStages.contains(where: { $0.kind == .postpartum && $0.contains(entry.day) }) else {
                throw TrackingError.invalidData
            }
            if let today, entry.day > today { throw TrackingError.futureDate }
        }
        for entry in data.biomarkers {
            guard (entry.notes?.count ?? 0) <= PeriodValidation.maximumNoteLength,
                  (entry.sourceName?.count ?? 0) <= 120,
                  entry.createdAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt.timeIntervalSinceReferenceDate.isFinite,
                  entry.updatedAt >= entry.createdAt else { throw TrackingError.invalidData }
            switch entry.kind {
            case .basalBodyTemperature:
                guard entry.result == nil, entry.numericValue.map({ $0.isFinite && (30...45).contains($0) }) == true else { throw TrackingError.invalidData }
            case .restingHeartRate:
                guard entry.result == nil, entry.numericValue.map({ $0.isFinite && (20...250).contains($0) }) == true else { throw TrackingError.invalidData }
            case .sleepDuration:
                guard entry.result == nil, entry.numericValue.map({ $0.isFinite && (0...24).contains($0) }) == true else { throw TrackingError.invalidData }
            case .lhTest, .pregnancyTest, .cervicalMucus:
                guard entry.numericValue == nil, entry.result.map(entry.kind.allowedResults.contains) == true else { throw TrackingError.invalidData }
            }
            if let today, entry.day > today { throw TrackingError.futureDate }
        }
        for feedback in data.insightFeedback {
            guard !feedback.insightID.isEmpty, feedback.insightID.count <= 400,
                  feedback.updatedAt.timeIntervalSinceReferenceDate.isFinite else { throw TrackingError.invalidData }
        }
    }

    static func sorted(_ data: P2Data) -> P2Data {
        var value = data
        value.lifeStages.sort { ($0.start, $0.createdAt, $0.id.uuidString) < ($1.start, $1.createdAt, $1.id.uuidString) }
        value.postpartumBleeding.sort { ($0.day, $0.createdAt, $0.id.uuidString) < ($1.day, $1.createdAt, $1.id.uuidString) }
        value.biomarkers.sort { ($0.day, $0.kind.rawValue, $0.id.uuidString) < ($1.day, $1.kind.rawValue, $1.id.uuidString) }
        value.insightFeedback.sort { $0.insightID < $1.insightID }
        return value
    }
}

// MARK: - Forecast integration

nonisolated enum P2Forecast {
    /// Life stages contribute visible, reversible forecast exclusions. Raw period records never change,
    /// and postpartum bleeding and biomarkers are never forecast inputs.
    static func factors(for snapshot: TrackerSnapshot) -> [CycleFactor] {
        let existing = Set(snapshot.cycleFactors.map(\.id))
        let derived = snapshot.p2.lifeStages.filter { $0.excludesFromForecast && !existing.contains($0.id) }.map {
            CycleFactor(id: $0.id, kind: $0.kind.factorKind, start: $0.start, end: $0.end,
                        excludesFromForecast: true, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        return snapshot.cycleFactors + derived
    }
}

// MARK: - Life-stage summaries

nonisolated struct SymptomCount: Equatable, Sendable {
    let kind: SymptomKind
    let count: Int
}

/// Describes saved records and coverage. Never a diagnosis, hormone estimate, or return-of-cycle prediction.
nonisolated struct LifeStageSummary: Equatable, Sendable {
    let kind: LifeStageKind
    let start: LocalDay
    let end: LocalDay
    let recordedDays: Int
    let dailyAnswerDays: Int
    let relevantSymptoms: [SymptomCount]
    let postpartumBleedingDays: Int
    let periodStartsDuring: [LocalDay]
    let intervalsBefore: [Int]
    let intervalsDuring: [Int]
    let firstPeriodAfterStart: LocalDay?
    let excludedFromForecast: Bool
    var totalDays: Int { start.days(until: end) + 1 }

    static func make(episode: LifeStageEpisode, snapshot: TrackerSnapshot, through day: LocalDay) -> LifeStageSummary {
        let end = max(episode.start, min(episode.end ?? day, day))
        let inRange: (LocalDay) -> Bool = { $0 >= episode.start && $0 <= end }
        let symptoms = snapshot.symptoms.filter { inRange($0.day) }
        let counts = episode.kind.relevantSymptoms.compactMap { kind -> SymptomCount? in
            let count = Set(symptoms.filter { $0.kind == kind }.map(\.day)).count
            return count == 0 ? nil : SymptomCount(kind: kind, count: count)
        }
        let starts = snapshot.periods.map(\.start).sorted()
        let pairs = Array(zip(starts, starts.dropFirst()))
        let before = pairs.filter { $0.1 <= episode.start }.suffix(6).map { $0.0.days(until: $0.1) }
        let during = pairs.filter { inRange($0.0) && inRange($0.1) }.map { $0.0.days(until: $0.1) }
        return LifeStageSummary(kind: episode.kind, start: episode.start, end: end,
            recordedDays: Set(symptoms.map(\.day)).count,
            dailyAnswerDays: Set(snapshot.dailyBleeding.filter { inRange($0.day) }.map(\.day)).count,
            relevantSymptoms: counts,
            postpartumBleedingDays: Set(snapshot.p2.postpartumBleeding.filter { inRange($0.day) }.map(\.day)).count,
            periodStartsDuring: starts.filter(inRange),
            intervalsBefore: Array(before), intervalsDuring: during,
            firstPeriodAfterStart: starts.first { $0 > episode.start },
            excludedFromForecast: episode.excludesFromForecast)
    }

    /// Plain statements about saved records.
    func observations(format: (LocalDay) -> String) -> [String] {
        var lines = [String(localized: "Daily bleeding answers on \(dailyAnswerDays) of \(totalDays) days. Unlogged days remain unknown.")]
        switch kind {
        case .cycleChange:
            lines.append(String(localized: "Period starts recorded in this stage: \(periodStartsDuring.count)."))
            if intervalsBefore.count >= 2, intervalsDuring.count >= 2,
               let beforeLow = intervalsBefore.min(), let beforeHigh = intervalsBefore.max(),
               let duringLow = intervalsDuring.min(), let duringHigh = intervalsDuring.max() {
                lines.append(String(localized: "Recorded intervals before: \(beforeLow)–\(beforeHigh) days. During: \(duringLow)–\(duringHigh) days. Missing starts can lengthen intervals."))
            } else {
                lines.append(String(localized: "At least two completed intervals before and during this stage are needed to compare bleeding patterns."))
            }
        case .postpartum, .breastfeeding:
            if let first = firstPeriodAfterStart {
                lines.append(String(localized: "First period start recorded after \(format(start)): \(format(first))."))
            } else {
                lines.append(String(localized: "No period start recorded since \(format(start)). Cecy does not predict when periods return."))
            }
            if kind == .postpartum {
                lines.append(String(localized: "Postpartum bleeding recorded on \(postpartumBleedingDays) days, kept separate from periods."))
            }
        }
        if excludedFromForecast {
            lines.append(String(localized: "Intervals overlapping this stage are excluded from forecast averages. You can change this."))
        }
        return lines
    }
}

nonisolated enum LifeStageCheckIn {
    /// Symptom choices relevant to stages active on `day`, most recent stage first.
    static func symptoms(for data: P2Data, on day: LocalDay) -> [SymptomKind] {
        var seen = Set<SymptomKind>()
        return data.activeLifeStages(on: day).flatMap(\.kind.relevantSymptoms).filter { seen.insert($0).inserted }
    }
}

// MARK: - Apple ecosystem (P2.4)

nonisolated enum AppleEcosystemCapability: String, CaseIterable, Sendable {
    case appIntents, healthBiomarkerRead, healthWriteBack, widgets, watchQuickLog

    var title: String {
        switch self {
        case .appIntents: String(localized: "Shortcuts and Siri")
        case .healthBiomarkerRead: String(localized: "Read biomarkers from Apple Health")
        case .healthWriteBack: String(localized: "Save records to Apple Health")
        case .widgets: String(localized: "Home and Lock Screen widgets")
        case .watchQuickLog: String(localized: "Apple Watch quick logging")
        }
    }

    /// Only capabilities that never commit health data without in-app review are enabled.
    var isEnabledInThisBuild: Bool { self == .appIntents }

    var boundary: String {
        switch self {
        case .appIntents: String(localized: "“Open daily check-in” opens Cecy’s check-in. Nothing is saved until you review it and tap Save, and app lock still applies.")
        case .healthBiomarkerRead: String(localized: "Requires granular per-type Health authorization and signed-device validation.")
        case .healthWriteBack: String(localized: "Requires per-type opt-in, provenance, deduplication, and loop-prevention acceptance.")
        case .widgets: String(localized: "Requires a WidgetKit target and a discreet lock-screen privacy review.")
        case .watchQuickLog: String(localized: "Requires a signed watchOS target and independent privacy and accessibility acceptance.")
        }
    }
}
