import Foundation

nonisolated enum AIContextError: Error, LocalizedError {
    case preferences, insufficientRecords, unsupportedQuestion, invalidText
    var errorDescription: String? {
        switch self {
        case .preferences: "Complete activity, exercise, diet, allergy status and wellness goals in Settings → Profile → Wellness preferences. Explicitly choosing none is OK; unanswered choices are not assumed."
        case .insufficientRecords: "There aren’t enough confirmed records for this request. No dates or missing observations will be guessed."
        case .unsupportedQuestion: "Choose a supported scope and ask about those records. Cecy can explain recorded cycle lengths, a symptom’s recorded-day count, or its timing near period starts—not diagnoses, causes, pregnancy or fertility."
        case .invalidText: "Enter a question or description using 1–2,000 characters."
        }
    }
}

nonisolated enum CycleQuestionScope: String, CaseIterable, Identifiable, Sendable {
    case cycleLengths, symptomFrequency, beforePeriod, nearStart
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cycleLengths: "Cycle length and variability"
        case .symptomFrequency: "Symptom logs · last 90 days"
        case .beforePeriod: "Symptom · three days before"
        case .nearStart: "Symptom · start day and next two days"
        }
    }
    func suggestedQuestion(kind: SymptomKind) -> String {
        switch self {
        case .cycleLengths: "How long and variable are my recorded cycles?"
        case .symptomFrequency: "How many days did I log \(kind.title.lowercased()) in the last 90 days?"
        case .beforePeriod: "Did I log \(kind.timingTitle.lowercased()) in the three days before my periods?"
        case .nearStart: "Did I log \(kind.timingTitle.lowercased()) on my period start day or the next two days?"
        }
    }
}

/// Only allowlisted aggregates leave this layer. Never encode TrackerSnapshot, profile,
/// record IDs, civil dates, private notes, sexual activity, or HealthKit metadata as context.
nonisolated enum AIContextBuilder {
    static let caveat = "Missing logs do not mean a symptom was absent. Recorded intervals can be longer when period starts are missing. These are descriptive records, not diagnoses or predictions."

    static func normalization(_ text: String) throws -> AIRequest {
        try validateText(text)
        return .symptoms(SymptomNormalizationContext(text: text))
    }
    static func validateText(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 2_000 else { throw AIContextError.invalidText }
    }

    static func insight(_ insight: CycleInsight) throws -> AIRequest {
        var facts = AIInsightFacts(metric: metric(insight.category), units: "days", evidence: insight.evidence.rawValue, caveat: caveat)
        let type: String
        switch insight.category {
        case .symptomTiming:
            guard let raw = insight.id.split(separator: ".").last, let kind = SymptomKind(rawValue: String(raw)),
                  !insight.timing.isEmpty else { throw AIContextError.insufficientRecords }
            type = "symptom_timing"
            facts.symptom = AISymptomType(kind: kind)
            facts.startsAnalyzed = insight.timing.count
            facts.matchingStarts = insight.matchedStarts
            let offsets = insight.timing.flatMap { support in support.logDays.map { support.start.days(until: $0) } }
            facts.timingWindow = offsets.allSatisfy { $0 < 0 } ? "three days before a recorded start" : "start day and next two days"
        default:
            guard let old = insight.previousMetric, let recent = insight.recentMetric,
                  old.isFinite, recent.isFinite else { throw AIContextError.insufficientRecords }
            type = insight.category == .cycleLength ? "cycle_length_change"
                : insight.category == .cycleVariability ? "cycle_variability_change" : "period_length_change"
            facts.previousMetric = old
            facts.recentMetric = recent
            facts.previousRecordCount = insight.previousValues.count
            facts.recentRecordCount = insight.recentValues.count
        }
        return .insight(InsightExplanationContext(insightType: type, facts: facts))
    }
    private static func metric(_ category: InsightCategory) -> String {
        switch category {
        case .symptomTiming: "recorded symptom timing; Poor sleep and Low energy only"
        case .cycleLength: "mean recorded cycle interval"
        case .cycleVariability: "population standard deviation of recorded cycle intervals"
        case .bleedingDuration: "mean confirmed inclusive bleeding duration"
        }
    }

    static func wellness(snapshot: TrackerSnapshot, today: LocalDay) throws -> AIRequest {
        guard let p = snapshot.profile?.wellnessPreferences, let activity = p.activityLevel,
              let exercises = p.preferredExercises, let diet = p.dietaryPreference,
              p.foodAllergyStatus != .notAnswered, let goals = p.goals else { throw AIContextError.preferences }
        try p.validate()
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        let symptoms = snapshot.symptoms.filter { $0.day == today }.compactMap { entry -> AISymptom? in
            if entry.kind == .sleepQuality || entry.kind == .energyLevel {
                // Only explicit adverse ratings can be described as symptoms. Severity is unknown.
                guard entry.value == 1 else { return nil }
                return AISymptom(type: AISymptomType(kind: entry.kind), severity: nil)
            }
            let severity: AISeverity? = entry.value.map { $0 == 1 ? .mild : $0 == 2 ? .moderate : .severe }
            return AISymptom(type: AISymptomType(kind: entry.kind), severity: severity)
        }.sorted { $0.type.rawValue < $1.type.rawValue }
        let overview = CycleCalculator.overview(periods: snapshot.periods, today: today, engine: EvidencePredictionEngine())
        let activityWire = activity == .beginner ? "beginner" : activity == .moderatelyActive ? "moderately_active" : "very_active"
        let exerciseWire = exercises.map { exercise in
            exercise == .strengthTraining ? "strength_training" : exercise == .homeWorkouts ? "home_workouts" : exercise.rawValue
        }.sorted()
        return .wellness(WellnessRecommendationContext(cycleDay: overview.currentDay, symptoms: symptoms,
            activityLevel: activityWire, preferredExercises: exerciseWire,
            dietaryPreference: diet == .noPreference ? "none" : diet.rawValue,
            foodAllergies: p.foodAllergies.sorted(), userGoals: goals.map { $0 == .manageSymptoms ? "manage_symptoms" : "stay_active" }.sorted()))
    }

    static func summary(snapshot: TrackerSnapshot, start: LocalDay, today: LocalDay) throws -> AIRequest {
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        let periods = snapshot.periods.sorted { $0.start < $1.start }
        guard let index = periods.firstIndex(where: { $0.start == start }), index + 1 < periods.count,
              let duration = periods[index].duration else { throw AIContextError.insufficientRecords }
        let next = periods[index + 1].start
        let lengths = zip(periods.prefix(index + 2), periods.prefix(index + 2).dropFirst()).map { $0.start.days(until: $1.start) }
        guard let stats = RecordedStatistics(lengths: Array(lengths.suffix(6))) else { throw AIContextError.insufficientRecords }
        let logs = snapshot.symptoms.filter { $0.day >= start && $0.day < next && $0.kind.qualifiesForTiming(value: $0.value) }
        let counts = Dictionary(grouping: logs, by: \.kind)
        let kinds = counts.keys.sorted { lhs, rhs in
            let a = counts[lhs]!.count, b = counts[rhs]!.count
            return a == b ? lhs.rawValue < rhs.rawValue : a > b
        }
        // All listed symptoms really occurred; 'common' is explicitly just up to three most logged.
        let observations = kinds.map { "\($0.timingTitle): \(counts[$0]!.count) recorded days in this interval." }
            + ["Common symptoms means up to three most logged types, not an inferred pattern.",
               "Average uses \(stats.count) completed intervals ending no later than this cycle.", caveat]
        return .summary(CycleSummaryContext(periodLabel: "Selected completed cycle", cycleLength: start.days(until: next),
            averageCycleLength: stats.mean, periodLength: duration,
            commonSymptoms: kinds.prefix(3).map { AISymptomType(kind: $0) }, observations: observations))
    }

    static func question(_ question: String, scope: CycleQuestionScope, kind: SymptomKind,
                         snapshot: TrackerSnapshot, today: LocalDay) throws -> AIRequest {
        try validateText(question)
        // Deliberately bounded local routing, not a broad chatbot intent classifier.
        // Other wording stays local and asks for clarification rather than uploading a whole history.
        guard supports(question, scope: scope, kind: kind) else { throw AIContextError.unsupportedQuestion }
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        var facts = AIQuestionFacts(scope: scope.rawValue, caveat: caveat)
        if scope == .cycleLengths {
            let periods = snapshot.periods.sorted { $0.start < $1.start }
            let lengths = Array(zip(periods, periods.dropFirst()).map { $0.start.days(until: $1.start) }.suffix(6))
            guard let stats = RecordedStatistics(lengths: lengths) else { throw AIContextError.insufficientRecords }
            facts.cyclesAnalyzed = stats.count
            facts.averageCycleLength = stats.mean
            facts.minimumCycleLength = stats.minimum
            facts.maximumCycleLength = stats.maximum
            facts.populationStandardDeviationDays = stats.standardDeviation
        } else {
            facts.symptom = AISymptomType(kind: kind)
            if scope == .symptomFrequency {
                let start = try today.adding(days: -89)
                facts.daysAnalyzed = 90
                facts.recordedDays = snapshot.symptoms.filter { $0.kind == kind && $0.day >= start && $0.day <= today }.count
            } else {
                let offsets = scope == .beforePeriod ? -3 ... -1 : 0...2
                let support = CycleInsightEngine.timingSupport(periods: snapshot.periods, symptoms: snapshot.symptoms,
                                                               today: today, kind: kind, offsets: offsets)
                guard !support.isEmpty else { throw AIContextError.insufficientRecords }
                facts.cyclesAnalyzed = support.count
                facts.matchingStarts = support.filter { !$0.logDays.isEmpty }.count
                facts.timingWindow = scope == .beforePeriod ? "three days before recorded start" : "recorded start and next two days"
                let recordedOffsets = support.flatMap { item in item.logDays.map { item.start.days(until: $0) } }
                facts.minimumRecordedOffsetDays = recordedOffsets.min()
                facts.maximumRecordedOffsetDays = recordedOffsets.max()
            }
        }
        return .question(CycleQuestionContext(question: question, facts: facts))
    }

    static func supports(_ question: String, scope: CycleQuestionScope, kind: SymptomKind) -> Bool {
        let text = question.lowercased()
        let blocked = ["pregnan", "fertil", "ovulat", "diagnos", "pcos", "endometri", "medicat", "treatment", "cure", "cause", "why", "normal", "all histor", "all record", "sex", "tomorrow", "next period"]
        guard !blocked.contains(where: { text.contains($0) }) else { return false }
        if text == scope.suggestedQuestion(kind: kind).lowercased() { return true }
        let tokens = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if scope != .symptomFrequency && tokens.contains("last") { return false }
        let quantities: Set<String> = ["one", "two", "three", "ninety", "1", "2", "3", "90"]
        let permittedQuantities: Set<String>
        switch scope {
        case .cycleLengths: permittedQuantities = []
        case .symptomFrequency: permittedQuantities = ["ninety", "90"]
        case .beforePeriod: permittedQuantities = ["three", "3"]
        case .nearStart: permittedQuantities = ["two", "2"]
        }
        guard tokens.filter({ quantities.contains($0) }).allSatisfy({ permittedQuantities.contains($0) }) else { return false }
        let allowed: Set<String> = ["do", "does", "did", "i", "my", "me", "get", "have", "usually", "often", "how", "many", "much", "what", "are", "is", "was", "were", "the", "a", "an", "and", "or", "of", "in", "on", "to", "at", "for", "with", "it", "been", "has", "before", "after", "start", "starts", "day", "days", "period", "periods", "cycle", "cycles", "recorded", "record", "records", "log", "logged", "logs", "last", "recent", "three", "two", "ninety", "long", "length", "lengths", "average", "variable", "variability", "consistent", "compare"]
        let symptomWords = Set((kind.title + " " + kind.timingTitle).lowercased().split(separator: " ").map(String.init))
        guard tokens.allSatisfy({ allowed.contains($0) || permittedQuantities.contains($0) || (scope != .cycleLengths && (symptomWords.contains($0) || symptomWords.contains(String($0.dropLast())))) }) else { return false }
        if scope == .cycleLengths { return text.contains("cycle") && ["long", "length", "variable", "variability", "average", "consistent"].contains(where: { text.contains($0) }) }
        guard symptomWords.contains(where: { text.contains($0) }) else { return false }
        switch scope {
        case .beforePeriod: return text.contains("before") && !text.contains("after")
        case .nearStart: return (text.contains("start") || text.contains("after")) && !text.contains("before")
        case .symptomFrequency: return !text.contains("before") && !text.contains("after") && !text.contains("start") && (text.contains("log") || text.contains("record"))
        case .cycleLengths: return false
        }
    }
}
