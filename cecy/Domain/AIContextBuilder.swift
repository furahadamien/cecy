import Foundation

nonisolated enum AIContextError: Error, LocalizedError {
    case preferences, insufficientRecords, unsupportedQuestion, invalidText, invalidQuestion, selectSymptoms
    var errorDescription: String? {
        switch self {
        case .preferences: "Complete activity, exercise, diet, allergy status and wellness goals in Settings → Profile → Wellness preferences. Explicitly choosing none is OK; unanswered choices are not assumed."
        case .insufficientRecords: "There aren’t enough confirmed records for this request. No dates or missing observations will be guessed."
        case .unsupportedQuestion: "Ask about the selected symptoms and time window. Questions about diagnoses or unrelated records aren’t supported."
        case .selectSymptoms: "Select at least one symptom to discuss."
        case .invalidText: "Enter a description using 1–2,000 characters."
        case .invalidQuestion: "Enter a question using 1–100 characters."
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
        case .symptomFrequency: "How many days did I log \((kind == .energyLevel ? kind.timingTitle : kind.title).lowercased()) in the last 90 days?"
        case .beforePeriod: "Did I log \(kind.timingTitle.lowercased()) in the three days before my periods?"
        case .nearStart: "Did I log \(kind.timingTitle.lowercased()) on my period start day or the next two days?"
        }
    }

    var selectedSymptomsQuestion: String {
        switch self {
        case .cycleLengths: "How long and variable are my recorded cycles?"
        case .symptomFrequency: "How many days did I log these symptoms in the last 90 days?"
        case .beforePeriod: "Did I log these symptoms in the three days before my periods?"
        case .nearStart: "Did I log these symptoms on my period start day or the next two days?"
        }
    }

    func initialQuestion(kinds: Set<SymptomKind>) -> String {
        kinds.count == 1 ? suggestedQuestion(kind: kinds.first!) : selectedSymptomsQuestion
    }
}

/// Only allowlisted aggregates leave this layer. Never encode TrackerSnapshot, profile,
/// record IDs, civil dates, private notes, sexual activity, or HealthKit metadata as context.
nonisolated enum AIContextBuilder {
    static let maximumQuestionLength = 100
    static let caveat = "Missing logs do not mean a symptom was absent. Recorded intervals can be longer when period starts are missing. These are descriptive records, not diagnoses or predictions."

    static func normalization(_ text: String) throws -> AIRequest {
        try validateText(text)
        return .symptoms(SymptomNormalizationContext(text: text))
    }
    static func validateText(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.unicodeScalars.count <= 2_000 else { throw AIContextError.invalidText }
    }

    static func validateQuestion(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= maximumQuestionLength, text.unicodeScalars.count <= 1_000 else { throw AIContextError.invalidQuestion }
    }

    static func insight(_ insight: CycleInsight) throws -> AIRequest {
        var facts = AIInsightFacts(metric: metric(insight.category), units: "days", evidence: insight.evidence.rawValue, caveat: caveat)
        let type: String
        switch insight.category {
        case .symptomTiming:
            guard let raw = insight.id.split(separator: ".").last, let kind = SymptomKind(rawValue: String(raw)),
                  let typeValue = AISymptomType(kind: kind), !insight.timing.isEmpty else { throw AIContextError.insufficientRecords }
            type = "symptom_timing"
            facts.symptom = typeValue
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
        case .symptomTiming: "recorded symptom timing; rating observations mean Poor sleep, Low energy, or Low sex drive only"
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
            guard let type = AISymptomType(kind: entry.kind) else { return nil }
            if !entry.kind.usesSeverity {
                // Only explicit adverse ratings can be described as symptoms. Severity is unknown.
                guard entry.value == 1 else { return nil }
                return AISymptom(type: type, severity: nil)
            }
            let severity: AISeverity? = entry.value.map { $0 == 1 ? .mild : $0 == 2 ? .moderate : .severe }
            return AISymptom(type: type, severity: severity)
        }.sorted { $0.type.rawValue < $1.type.rawValue }
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        let cycleDay = snapshot.periods.map(\.start).max().map { $0.days(until: today) + 1 }
        let activityWire = activity == .beginner ? "beginner" : activity == .moderatelyActive ? "moderately_active" : "very_active"
        let exerciseWire = exercises.map { exercise in
            exercise == .strengthTraining ? "strength_training" : exercise == .homeWorkouts ? "home_workouts" : exercise.rawValue
        }.sorted()
        // Omit an out-of-contract cycle day; never clamp it or roll the cycle forward.
        return .wellness(WellnessRecommendationContext(cycleDay: cycleDay.flatMap { (1...100).contains($0) ? $0 : nil }, symptoms: symptoms,
            activityLevel: activityWire, preferredExercises: exerciseWire,
            dietaryPreference: diet == .noPreference ? "none" : diet.rawValue,
            foodAllergies: p.foodAllergies.sorted(), userGoals: goals.map { $0 == .manageSymptoms ? "manage_symptoms" : "stay_active" }.sorted()))
    }

    /// Uses the existing question contract: unknown measurements are omitted, never sent as zero.
    static func recordInsights(snapshot: TrackerSnapshot, today: LocalDay) throws -> AIRequest {
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        let periods = Array(snapshot.periods.sorted { $0.start < $1.start }.suffix(7))
        let windowStart = try today.adding(days: -89)
        let windowLogs = snapshot.symptoms.filter { $0.day >= windowStart && $0.day <= today }
        let logs = windowLogs.filter { isRepresentable($0) }
        guard !periods.isEmpty || !windowLogs.isEmpty else { throw AIContextError.insufficientRecords }
        let lengths = zip(periods, periods.dropFirst()).map { $0.start.days(until: $1.start) }
        let stats = RecordedStatistics(lengths: lengths)
        let durations = periods.compactMap(\.duration)
        let counts = Dictionary(grouping: logs, by: \.kind)
        var facts = AIQuestionFacts(scope: CycleQuestionScope.cycleLengths.rawValue,
            caveat: caveat + " Small samples are not trends. Open intervals are not measured cycles. Sleep and sex-drive counts are ratings, not necessarily adverse. Energy ratings are separately counted; low_energy means low only.")
        facts.recordedStarts = periods.count
        facts.confirmedBleedingDurations = durations
        facts.unknownBleedingEnds = periods.count - durations.count
        let energy = windowLogs.filter { $0.kind == .energyLevel }
        if !energy.isEmpty {
            facts.energyRatingDays = Dictionary(grouping: energy) { entry in
                switch entry.value { case 1: "low"; case 2: "typical"; case 3: "high"; default: "unrated" }
            }.mapValues { Set($0.map(\.day)).count }
        }
        facts.symptoms = SymptomKind.allCases.compactMap { kind in
            guard let entries = counts[kind], let type = AISymptomType(kind: kind) else { return nil }
            return AIQuestionSymptomFacts(symptom: type, cyclesAnalyzed: nil, daysAnalyzed: 90,
                recordedDays: Set(entries.map(\.day)).count, matchingStarts: nil, timingWindow: nil,
                minimumRecordedOffsetDays: nil, maximumRecordedOffsetDays: nil)
        }
        facts.cyclesAnalyzed = lengths.count
        facts.averageCycleLength = stats?.mean
        facts.minimumCycleLength = stats?.minimum
        facts.maximumCycleLength = stats?.maximum
        facts.populationStandardDeviationDays = stats?.standardDeviation
        return .question(CycleQuestionContext(question: "Summarize my recorded facts and unknowns without inferring a pattern.", facts: facts))
    }

    static func summary(snapshot: TrackerSnapshot, start: LocalDay, today: LocalDay) throws -> AIRequest {
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        let periods = snapshot.periods.sorted { $0.start < $1.start }
        guard let index = periods.firstIndex(where: { $0.start == start }) else { throw AIContextError.insufficientRecords }
        guard index + 1 < periods.count, let duration = periods[index].duration else {
            let next = index + 1 < periods.count ? periods[index + 1].start : nil
            let through = try next.map { try $0.adding(days: -1) } ?? today
            let selected = TrackerSnapshot(periods: [periods[index]],
                symptoms: snapshot.symptoms.filter { $0.day >= start && $0.day <= through && AISymptomType(kind: $0.kind) != nil })
            guard case .question(let context) = try recordInsights(snapshot: selected, today: through) else {
                throw AIContextError.insufficientRecords
            }
            // The general sparse description has one start. Include a confirmed next-start
            // interval separately rather than dropping it or inventing a bleeding duration.
            var facts = context.facts
            if let next {
                let length = start.days(until: next)
                facts = AIQuestionFacts(scope: CycleQuestionScope.cycleLengths.rawValue,
                    caveat: "Selected completed interval; bleeding duration unknown. One interval is not a trend. Sleep and sex-drive counts are ratings; energy counts only low ratings. " + caveat,
                    cyclesAnalyzed: 1, averageCycleLength: Double(length), minimumCycleLength: length, maximumCycleLength: length)
                facts.recordedStarts = 1
                facts.unknownBleedingEnds = 1
                facts.symptoms = context.facts.symptoms
                facts.energyRatingDays = context.facts.energyRatingDays
            }
            return .question(CycleQuestionContext(question: "Describe the available records for this cycle, explaining missing measurements without guessing.", facts: facts))
        }
        let next = periods[index + 1].start
        let lengths = zip(periods.prefix(index + 2), periods.prefix(index + 2).dropFirst()).map { $0.start.days(until: $1.start) }
        guard let stats = RecordedStatistics(lengths: Array(lengths.suffix(6))) else { throw AIContextError.insufficientRecords }
        // A valid local record may exceed the specialized summary endpoint's ranges.
        // Describe its exact measurements using scalar facts instead of fabricating replacements.
        if !(1...100).contains(start.days(until: next)) || !(1...100).contains(stats.mean) || !(1...30).contains(duration) {
            let selected = TrackerSnapshot(periods: [periods[index]],
                symptoms: snapshot.symptoms.filter { $0.day >= start && $0.day < next })
            guard case .question(let context) = try recordInsights(snapshot: selected, today: try next.adding(days: -1)) else {
                throw AIContextError.insufficientRecords
            }
            var facts = context.facts
            facts.cyclesAnalyzed = 1
            facts.averageCycleLength = Double(start.days(until: next))
            facts.minimumCycleLength = start.days(until: next)
            facts.maximumCycleLength = start.days(until: next)
            return .question(CycleQuestionContext(question: "Describe this completed interval and its unknowns without inferring a trend.", facts: facts))
        }
        let logs = snapshot.symptoms.filter { $0.day >= start && $0.day < next && $0.kind.qualifiesForTiming(value: $0.value) && AISymptomType(kind: $0.kind) != nil }
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
            commonSymptoms: Array(kinds.compactMap { AISymptomType(kind: $0) }.prefix(3)), observations: packedObservations(observations)))
    }

    static func question(_ question: String, scope: CycleQuestionScope, kind: SymptomKind,
                         snapshot: TrackerSnapshot, today: LocalDay) throws -> AIRequest {
        try validateQuestion(question)
        // Deliberately bounded local routing, not a broad chatbot intent classifier.
        // Other wording stays local and asks for clarification rather than uploading a whole history.
        guard supports(question, scope: scope, kind: kind) else { throw AIContextError.unsupportedQuestion }
        try PeriodValidation.validate(snapshot.periods, asOf: today)
        try SymptomValidation.validate(snapshot.symptoms, asOf: today)
        var facts = AIQuestionFacts(scope: scope.rawValue,
            caveat: caveat + " Timing uses only low sleep, energy and sex-drive ratings; frequency includes all sleep/sex-drive ratings but only low energy.")
        if scope == .cycleLengths {
            let periods = snapshot.periods.sorted { $0.start < $1.start }
            let lengths = Array(zip(periods, periods.dropFirst()).map { $0.start.days(until: $1.start) }.suffix(6))
            guard let stats = RecordedStatistics(lengths: lengths) else {
                guard !periods.isEmpty else { throw AIContextError.insufficientRecords }
                return .question(CycleQuestionContext(question: question,
                    facts: AIQuestionFacts(scope: scope.rawValue,
                        caveat: "\(periods.count) recorded start; no completed interval. Cycle length and variability are unknown. Describe only this limited record; do not substitute a usual length or infer a trend. " + caveat,
                        cyclesAnalyzed: 0)))
            }
            facts.cyclesAnalyzed = stats.count
            facts.averageCycleLength = stats.mean
            facts.minimumCycleLength = stats.minimum
            facts.maximumCycleLength = stats.maximum
            facts.populationStandardDeviationDays = stats.standardDeviation
        } else {
            guard let type = AISymptomType(kind: kind) else { throw AIContextError.unsupportedQuestion }
            facts.symptom = type
            if scope == .symptomFrequency {
                let start = try today.adding(days: -89)
                facts.daysAnalyzed = 90
                facts.recordedDays = snapshot.symptoms.filter { $0.kind == kind && $0.day >= start && $0.day <= today && isRepresentable($0) }.count
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

    static func question(_ text: String, scope: CycleQuestionScope, kinds: Set<SymptomKind>,
                         snapshot: TrackerSnapshot, today: LocalDay) throws -> AIRequest {
        if scope == .cycleLengths {
            return try question(text, scope: scope, kind: .headache, snapshot: snapshot, today: today)
        }
        guard !kinds.isEmpty else { throw AIContextError.selectSymptoms }
        try validateQuestion(text)
        guard supports(text, scope: scope, kinds: kinds) else { throw AIContextError.unsupportedQuestion }
        if kinds.count == 1, let kind = kinds.first {
            return try question(text, scope: scope, kind: kind, snapshot: snapshot, today: today)
        }
        let values = try kinds.sorted { $0.rawValue < $1.rawValue }.map { kind -> AIQuestionSymptomFacts in
            guard let type = AISymptomType(kind: kind) else { throw AIContextError.unsupportedQuestion }
            guard case .question(let context) = try question(scope.suggestedQuestion(kind: kind), scope: scope,
                kind: kind, snapshot: snapshot, today: today) else { throw AIContextError.insufficientRecords }
            let facts = context.facts
            return AIQuestionSymptomFacts(symptom: type, cyclesAnalyzed: facts.cyclesAnalyzed,
                daysAnalyzed: facts.daysAnalyzed, recordedDays: facts.recordedDays, matchingStarts: facts.matchingStarts,
                timingWindow: facts.timingWindow, minimumRecordedOffsetDays: facts.minimumRecordedOffsetDays,
                maximumRecordedOffsetDays: facts.maximumRecordedOffsetDays)
        }
        var facts = AIQuestionFacts(scope: scope.rawValue,
            caveat: caveat + " Timing uses only low sleep, energy and sex-drive ratings; frequency includes all sleep/sex-drive ratings but only low energy.")
        facts.symptoms = values
        return .question(CycleQuestionContext(question: text, facts: facts))
    }

    static func supports(_ question: String, scope: CycleQuestionScope, kind: SymptomKind) -> Bool {
        supports(question, scope: scope, kinds: [kind])
    }

    static func supports(_ question: String, scope: CycleQuestionScope, kinds: Set<SymptomKind>) -> Bool {
        let text = question.lowercased()
        let blocked = ["pregnan", "fertil", "ovulat", "diagnos", "pcos", "endometri", "medicat", "treatment", "cure", "cause", "why", "normal", "all histor", "all record", "sex", "tomorrow", "next period"]
        // Only the exact observation phrase is exempted, and only when selected.
        let screened = kinds.contains(.libido) && scope != .cycleLengths
            ? text.replacingOccurrences(of: "\\bsex drive\\b", with: "libido", options: .regularExpression) : text
        guard !blocked.contains(where: { screened.contains($0) }) else { return false }
        if scope != .cycleLengths && kinds.isEmpty { return false }
        if text == scope.selectedSymptomsQuestion.lowercased() { return true }
        if kinds.count == 1, let kind = kinds.first, text == scope.suggestedQuestion(kind: kind).lowercased() { return true }
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
        let symptomWords = Set(kinds.flatMap { ($0.title + " " + $0.timingTitle).lowercased().split(separator: " ").map(String.init) })
        guard tokens.allSatisfy({ allowed.contains($0) || permittedQuantities.contains($0) || (scope != .cycleLengths && (symptomWords.contains($0) || symptomWords.contains(String($0.dropLast())))) }) else { return false }
        if scope == .cycleLengths { return text.contains("cycle") && ["long", "length", "variable", "variability", "average", "consistent"].contains(where: { text.contains($0) }) }
        guard kinds.allSatisfy({ kind in
            [kind.title, kind.timingTitle].contains { label in
                text.range(of: "\\b" + NSRegularExpression.escapedPattern(for: label.lowercased()) + "s?\\b", options: .regularExpression) != nil
            }
        }) else { return false }
        switch scope {
        case .beforePeriod: return text.contains("before") && !text.contains("after")
        case .nearStart: return (text.contains("start") || text.contains("after")) && !text.contains("before")
        case .symptomFrequency: return !text.contains("before") && !text.contains("after") && !text.contains("start") && (text.contains("log") || text.contains("record"))
        case .cycleLengths: return false
        }
    }

    private static func isRepresentable(_ entry: SymptomEntry) -> Bool {
        AISymptomType(kind: entry.kind) != nil && (entry.kind != .energyLevel || entry.value == 1)
    }

    /// Keep every observation without exceeding the backend's 30-string/500-code-point bounds.
    private static func packedObservations(_ observations: [String]) -> [String] {
        var result: [String] = []
        for observation in observations {
            if let last = result.last, (last + " " + observation).unicodeScalars.count <= 500 {
                result[result.count - 1] = last + " " + observation
            } else { result.append(observation) }
        }
        return result
    }
}
