import Foundation

// MARK: - daily_insights_v2 request (catalog v2, schema v2)

nonisolated enum DailyInsightSectionKind: String, Codable, CaseIterable, Sendable {
    case selfCare = "self_care", food, movement, hydration, recovery, skincare
    var title: String {
        switch self {
        case .selfCare: "Self-care"
        case .food: "Food"
        case .movement: "Movement"
        case .hydration: "Hydration"
        case .recovery: "Recovery"
        case .skincare: "Skincare"
        }
    }
    var symbol: String {
        switch self {
        case .selfCare: "heart"
        case .food: "fork.knife"
        case .movement: "figure.walk"
        case .hydration: "drop"
        case .recovery: "leaf"
        case .skincare: "sparkle"
        }
    }
}

nonisolated enum DailyInsightPhaseBasis: String, Codable, Sendable {
    case recordedBleeding = "recorded_bleeding", estimated, unknown
}

/// Declaration order is the canonical wire order.
nonisolated enum DailyInsightLimitation: String, Codable, CaseIterable, Sendable {
    case cycleDayUnavailable = "cycle_day_unavailable"
    case insufficientCycleHistory = "insufficient_cycle_history"
    case irregularCycle = "irregular_cycle"
    case overduePeriod = "overdue_period"
    case phaseBoundaryUncertain = "phase_boundary_uncertain"
    case conflictingEvidence = "conflicting_evidence"
}

nonisolated struct DailyInsightPhase: Encodable, Equatable, Sendable {
    let value: String?
    let basis: DailyInsightPhaseBasis
    let limitations: [DailyInsightLimitation]
    init(value: CyclePhase?, basis: DailyInsightPhaseBasis, limitations: Set<DailyInsightLimitation>) {
        self.value = value?.rawValue
        self.basis = basis
        self.limitations = DailyInsightLimitation.allCases.filter(limitations.contains)
    }
    enum CodingKeys: String, CodingKey { case value, basis, limitations }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(value, forKey: .value)
        try values.encode(basis, forKey: .basis)
        try values.encode(limitations, forKey: .limitations)
    }
}

nonisolated struct DailyInsightBleeding: Encodable, Equatable, Sendable {
    let state: String
    let flow: String?
    init(state: DailyBleedingState, flow: PeriodFlow?) {
        self.state = switch state {
        case .bleeding: "bleeding"
        case .spotting: "spotting"
        case .noBleeding: "no_bleeding"
        case .unsure: "unsure"
        }
        self.flow = state == .bleeding ? flow?.rawValue : nil
    }
    enum CodingKeys: String, CodingKey { case state, flow }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(state, forKey: .state)
        try values.encode(flow, forKey: .flow)
    }
}

nonisolated struct DailyInsightPreferences: Encodable, Equatable, Sendable {
    let activityLevel: String?
    let preferredExercises: [String]?
    let dietaryPreference: String?
    let foodAllergies: [String]?
    let userGoals: [String]?

    /// Unanswered values are sent as explicit nulls so the backend can mark sections unavailable.
    init(_ p: WellnessPreferences?) {
        activityLevel = p?.activityLevel.map { $0 == .beginner ? "beginner" : $0 == .moderatelyActive ? "moderately_active" : "very_active" }
        preferredExercises = p?.preferredExercises.map { set in
            set.map { $0 == .strengthTraining ? "strength_training" : $0 == .homeWorkouts ? "home_workouts" : $0.rawValue }.sorted()
        }
        dietaryPreference = p?.dietaryPreference.map { $0 == .noPreference ? "none" : $0.rawValue }
        foodAllergies = switch p?.foodAllergyStatus {
        case .noneKnown?: []
        case .listed?: p?.foodAllergies.sorted()
        default: nil
        }
        userGoals = p?.goals.map { $0.map { $0 == .manageSymptoms ? "manage_symptoms" : "stay_active" }.sorted() }
    }
    enum CodingKeys: String, CodingKey { case activityLevel, preferredExercises, dietaryPreference, foodAllergies, userGoals }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(activityLevel, forKey: .activityLevel)
        try values.encode(preferredExercises, forKey: .preferredExercises)
        try values.encode(dietaryPreference, forKey: .dietaryPreference)
        try values.encode(foodAllergies, forKey: .foodAllergies)
        try values.encode(userGoals, forKey: .userGoals)
    }
}

nonisolated struct DailyInsightsContext: Encodable, Equatable, Sendable {
    static let allSections = DailyInsightSectionKind.allCases
    var schemaVersion = 2
    let cycleDay: Int?
    let phase: DailyInsightPhase
    let symptoms: [AISymptom]
    let dailyBleeding: DailyInsightBleeding?
    let preferences: DailyInsightPreferences
    var requestedSections: [DailyInsightSectionKind] = allSections

    enum CodingKeys: String, CodingKey { case schemaVersion, cycleDay, phase, symptoms, dailyBleeding, preferences, requestedSections }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(cycleDay, forKey: .cycleDay) // Explicit nulls; omission is invalid.
        try values.encode(phase, forKey: .phase)
        try values.encode(symptoms, forKey: .symptoms)
        try values.encode(dailyBleeding, forKey: .dailyBleeding)
        try values.encode(preferences, forKey: .preferences)
        try values.encode(requestedSections, forKey: .requestedSections)
    }
    var hasSevereSymptom: Bool { symptoms.contains { $0.severity == .severe } }
}

nonisolated extension DailyInsightsContext: AIRequestContext {
    func validateForAI() throws {
        let require = AIRequestValidation.require
        try require(schemaVersion == 2)
        if let cycleDay { try require((1...100).contains(cycleDay)) }
        // Phase invariants from the backend contract.
        try require(phase.limitations.count <= 6 && Set(phase.limitations).count == phase.limitations.count)
        try require(phase.value.map { CyclePhase(rawValue: $0) != nil } ?? true)
        switch phase.basis {
        case .unknown: try require(phase.value == nil)
        case .estimated: try require(phase.value != nil)
        case .recordedBleeding: try require(phase.value == CyclePhase.menstrual.rawValue && dailyBleeding?.state == "bleeding")
        }
        if phase.basis == .estimated, phase.value != CyclePhase.menstrual.rawValue, dailyBleeding?.state == "bleeding" {
            try require(phase.limitations.contains(.conflictingEvidence))
        }
        try require(symptoms.count <= 39 && Set(symptoms.map(\.type)).count == symptoms.count)
        try require(symptoms.allSatisfy { $0.type.kind.usesSeverity || $0.severity == nil })
        if let dailyBleeding { try require(dailyBleeding.state == "bleeding" || dailyBleeding.flow == nil) }
        if let list = preferences.preferredExercises { try require(list.count <= 9 && Set(list).count == list.count) }
        if let goals = preferences.userGoals { try require(goals.count <= 2 && Set(goals).count == goals.count) }
        if let allergies = preferences.foodAllergies {
            try require(allergies.count <= 20)
            for item in allergies {
                try require((1...80).contains(item.count) && !item.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) })
            }
        }
        try require((1...6).contains(requestedSections.count) && Set(requestedSections).count == requestedSections.count)
    }
}

// MARK: - Response

nonisolated struct DailyInsightSection: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case available, unavailable }
    enum Reason: String, Codable, Sendable {
        case missingPreferences = "missing_preferences", insufficientContext = "insufficient_context", safetyLimit = "safety_limit"
    }
    let kind: DailyInsightSectionKind
    let status: Status
    let suggestions: [String]
    let unavailableReason: Reason?

    init(kind: DailyInsightSectionKind, suggestions: [String]) {
        self.kind = kind; status = .available; self.suggestions = suggestions; unavailableReason = nil
    }
    init(kind: DailyInsightSectionKind, unavailable reason: Reason) {
        self.kind = kind; status = .unavailable; suggestions = []; unavailableReason = reason
    }
    enum CodingKeys: String, CodingKey { case kind, status, suggestions, unavailableReason }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(DailyInsightSectionKind.self, forKey: .kind)
        status = try values.decode(Status.self, forKey: .status)
        suggestions = try values.decode([String].self, forKey: .suggestions)
        unavailableReason = try values.decode(Reason?.self, forKey: .unavailableReason) // Required, nullable.
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(kind, forKey: .kind)
        try values.encode(status, forKey: .status)
        try values.encode(suggestions, forKey: .suggestions)
        try values.encode(unavailableReason, forKey: .unavailableReason)
    }
    func validate() throws {
        switch status {
        case .available:
            guard unavailableReason == nil, (1...6).contains(suggestions.count) else { throw AIServiceError.invalidResponse }
            try AIResponseValidation.list(suggestions, maximum: 6, textMaximum: 200)
        case .unavailable:
            guard unavailableReason != nil, suggestions.isEmpty else { throw AIServiceError.invalidResponse }
        }
    }
}

nonisolated struct DailyInsightsResult: AIValidatedResponse, Equatable {
    let schemaVersion: Int
    let sections: [DailyInsightSection]
    let explanation: String
    let safetyMessage: String?

    init(sections: [DailyInsightSection], explanation: String, safetyMessage: String?) {
        schemaVersion = 2; self.sections = sections; self.explanation = explanation; self.safetyMessage = safetyMessage
    }
    enum CodingKeys: String, CodingKey { case schemaVersion, sections, explanation, safetyMessage }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        sections = try values.decode([DailyInsightSection].self, forKey: .sections)
        explanation = try values.decode(String.self, forKey: .explanation)
        safetyMessage = try values.decode(String?.self, forKey: .safetyMessage) // Required, nullable.
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(sections, forKey: .sections)
        try values.encode(explanation, forKey: .explanation)
        try values.encode(safetyMessage, forKey: .safetyMessage)
    }

    func validate() throws {
        guard schemaVersion == 2, (1...6).contains(sections.count),
              Set(sections.map(\.kind)).count == sections.count else { throw AIServiceError.invalidResponse }
        for section in sections { try section.validate() }
        try AIResponseValidation.text(explanation, maximum: 1_000)
        try AIResponseValidation.safety(safetyMessage)
    }

    /// Request-dependent checks: exact order, and severe-symptom safety obligations.
    func validate(for context: DailyInsightsContext) throws {
        try validate()
        guard sections.map(\.kind) == context.requestedSections else { throw AIServiceError.invalidResponse }
        if context.hasSevereSymptom {
            guard safetyMessage != nil else { throw AIServiceError.invalidResponse }
            if let movement = sections.first(where: { $0.kind == .movement }), movement.unavailableReason != .safetyLimit {
                throw AIServiceError.invalidResponse
            }
        }
    }
}

// MARK: - Builder

nonisolated extension AIContextBuilder {
    /// Only today's symptoms, today's bleeding answer, a cycle day, an uncertainty-preserving phase
    /// and preferences are sent. No dates, identifiers, notes, sexual activity or history.
    static func dailyInsights(snapshot: TrackerSnapshot, today: LocalDay, overview: CycleOverview?,
                              forecast: CycleForecast) throws -> AIRequest {
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        if let p = snapshot.profile?.wellnessPreferences { try p.validate() }
        let symptoms = todaySymptoms(snapshot: snapshot, today: today)
        let latest = snapshot.periods.map(\.start).filter { $0 <= today }.max()
        let cycleDay = latest.map { $0.days(until: today) + 1 }.flatMap { (1...100).contains($0) ? $0 : nil }

        let answer = snapshot.dailyBleeding.first { $0.day == today }
        let periodToday = snapshot.periods.contains { period in
            period.start == today || (period.end.map { period.start <= today && today <= $0 } ?? false)
        }
        let bleeding: DailyInsightBleeding? = answer.map { DailyInsightBleeding(state: $0.state, flow: $0.flow) }
            ?? (periodToday ? DailyInsightBleeding(state: .bleeding, flow: nil) : nil)
        let bleedingToday = bleeding?.state == "bleeding"
        let recordedPeriodBleeding = bleedingToday && (periodToday || answer?.periodID != nil)

        let phase: DailyInsightPhase
        if recordedPeriodBleeding {
            phase = DailyInsightPhase(value: .menstrual, basis: .recordedBleeding, limitations: [])
        } else {
            phase = estimatedPhase(snapshot: snapshot, today: today, overview: overview, forecast: forecast,
                                   cycleDay: cycleDay, bleedingToday: bleedingToday)
        }
        let context = DailyInsightsContext(cycleDay: cycleDay, phase: phase, symptoms: symptoms, dailyBleeding: bleeding,
                                           preferences: DailyInsightPreferences(snapshot.profile?.wellnessPreferences))
        try context.validateForAI()
        return .dailyInsights(context)
    }

    private static func todaySymptoms(snapshot: TrackerSnapshot, today: LocalDay) -> [AISymptom] {
        snapshot.symptoms.filter { $0.day == today }.compactMap { entry -> AISymptom? in
            guard let type = AISymptomType(kind: entry.kind) else { return nil }
            if !entry.kind.usesSeverity {
                // Only explicit adverse ratings describe a symptom. Severity is unknown.
                guard entry.value == 1 else { return nil }
                return AISymptom(type: type, severity: nil)
            }
            let severity: AISeverity? = entry.value.map { $0 == 1 ? .mild : $0 == 2 ? .moderate : .severe }
            return AISymptom(type: type, severity: severity)
        }.sorted { $0.type.rawValue < $1.type.rawValue }
    }

    /// Never confirms ovulation or hormones; an estimate is always labelled as such with its limits.
    private static func estimatedPhase(snapshot: TrackerSnapshot, today: LocalDay, overview: CycleOverview?,
                                       forecast: CycleForecast, cycleDay: Int?, bleedingToday: Bool) -> DailyInsightPhase {
        var limits: Set<DailyInsightLimitation> = []
        if cycleDay == nil { limits.insert(.cycleDayUnavailable) }
        switch overview?.prediction {
        case .insufficientHistory?, nil: limits.insert(.insufficientCycleHistory)
        case .wideVariation?: limits.insert(.irregularCycle)
        default: break
        }
        if overview?.intervals.isEmpty ?? true { limits.insert(.insufficientCycleHistory) }
        if let estimate = overview?.estimate, today > estimate.latest { limits.insert(.overduePeriod) }

        let timeline = overview.flatMap {
            CyclePhaseTimeline.make(overview: $0, forecast: forecast, periods: snapshot.periods,
                                    profile: snapshot.profile, today: today)
        }
        if let timeline, let current = timeline.currentPhase, !limits.contains(.overduePeriod) {
            limits.insert(.phaseBoundaryUncertain)
            if bleedingToday && current != .menstrual { limits.insert(.conflictingEvidence) }
            return DailyInsightPhase(value: current, basis: .estimated, limitations: limits)
        }
        if let timeline, let day = timeline.markerDay, timeline.currentDayHasAnswer,
           timeline.segments.first(where: { $0.days.contains(day) })?.phase == .menstrual {
            limits.insert(.conflictingEvidence) // Estimated bleeding, but today's answer says otherwise.
        }
        if limits.isEmpty { limits.insert(.phaseBoundaryUncertain) }
        return DailyInsightPhase(value: nil, basis: .unknown, limitations: limits)
    }
}
