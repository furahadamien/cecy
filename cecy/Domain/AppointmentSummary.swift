import Foundation

nonisolated struct RecordingCoverage: Equatable, Sendable {
    let start: LocalDay
    let end: LocalDay
    let answers: [DailyBleedingObservation]
    var totalDays: Int { start.days(until: end) + 1 }
    var loggedDays: Int { answers.count }
    var unloggedDays: Int { totalDays - loggedDays }
    func count(_ state: DailyBleedingState) -> Int { answers.filter { $0.state == state }.count }

    init(snapshot: TrackerSnapshot, start: LocalDay, end: LocalDay) throws {
        guard start <= end else { throw TrackingError.invalidData }
        try DailyBleedingValidation.validate(snapshot.dailyBleeding, periods: snapshot.periods)
        self.start = start
        self.end = end
        answers = DailyBleedingValidation.sorted(snapshot.dailyBleeding.filter { $0.day >= start && $0.day <= end })
    }
}

nonisolated struct AppointmentSummaryOptions: Equatable, Sendable {
    var periods = true
    var dailyAnswers = true
    var symptoms = false
    var context = false
    var notes = false
    var trends = false
    var treatments = false
    var concerns: [String] = []
    var questions: [String] = []
    var hasSection: Bool { periods || dailyAnswers || symptoms || context || trends || treatments || !concerns.isEmpty || !questions.isEmpty }
}

nonisolated struct AppointmentSummaryDocument: Equatable, Sendable {
    struct Section: Equatable, Identifiable, Sendable {
        enum Kind: String, Sendable {
            case dailyAnswers = "DAILY ANSWERS"
            case periods = "RECORDED PERIODS"
            case symptoms = "SYMPTOMS AND WELLNESS"
            case context = "CURRENT SELF-REPORTED CONTEXT"
            case trends = "RECORDED TRENDS"
            case concerns = "TOP CONCERNS AND QUESTIONS"
            case treatments = "MEDICATION, CONTRACEPTION AND FACTORS"
        }
        let kind: Kind
        let lines: [String]
        var id: Kind { kind }
    }

    let title: String
    let dateRange: String
    let notice: String
    let sections: [Section]

    var text: String {
        var lines = [title, dateRange, notice]
        for section in sections { lines += ["", section.kind.rawValue] + section.lines }
        return lines.joined(separator: "\n") + "\n"
    }
}

nonisolated enum AppointmentSummary {
    /// No identity, sexual activity, partner answers, IDs, predictions, or remote generation.
    /// Dates are stable civil dates. Identical records and options produce identical text.
    static func text(snapshot: TrackerSnapshot, start: LocalDay, end: LocalDay,
                     options: AppointmentSummaryOptions) throws -> String {
        try document(snapshot: snapshot, start: start, end: end, options: options).text
    }

    static func document(snapshot: TrackerSnapshot, start: LocalDay, end: LocalDay,
                         options: AppointmentSummaryOptions) throws -> AppointmentSummaryDocument {
        guard start <= end, options.hasSection else { throw TrackingError.invalidData }
        try PeriodValidation.validate(snapshot.periods)
        try SymptomValidation.validate(snapshot.symptoms)
        let coverage = try RecordingCoverage(snapshot: snapshot, start: start, end: end)
        let date = TrackerExport.civilDate
        var sections: [AppointmentSummaryDocument.Section] = []
        if options.dailyAnswers {
            var lines = ["Days logged: \(coverage.loggedDays) of \(coverage.totalDays)",
                         "Not logged: \(coverage.unloggedDays)"]
            for state in DailyBleedingState.allCases { lines.append("\(state.title): \(coverage.count(state))") }
            lines.append("Not logged does not mean no bleeding. Not sure is a recorded uncertain answer.")
            for answer in coverage.answers {
                lines.append("\(date(answer.day)): \(answer.state.title)" + (answer.flow.map { " · \($0.title) flow" } ?? ""))
            }
            if coverage.answers.isEmpty { lines.append("No daily answers recorded in this range.") }
            sections.append(.init(kind: .dailyAnswers, lines: lines))
        }
        if options.periods {
            let periods = snapshot.periods.sorted { $0.start < $1.start }
            let included = periods.filter { $0.start <= end && ($0.end ?? $0.start) >= start }
            var lines = ["Periods overlapping these dates; original dates shown. Daily answers are counted separately."]
            for period in included {
                var line = "\(date(period.start)) – " + (period.end.map(date) ?? "end not recorded")
                if let duration = period.duration { line += " · \(duration) confirmed days" }
                else if let latest = snapshot.potentialEnd(for: period), latest > period.start {
                    line += " · latest recorded bleeding day \(date(latest))"
                }
                if let flow = period.flow { line += " · overall \(flow.title.lowercased()) flow" }
                lines.append(line)
                if options.notes, let note = period.notes { lines.append("Note: \(note)") }
            }
            if included.isEmpty { lines.append("No periods recorded in this range.") }
            let lengths = zip(periods, periods.dropFirst()).filter { $0.start >= start && $1.start <= end }
                .map { $0.start.days(until: $1.start) }
            if let stats = RecordedStatistics(lengths: lengths) {
                lines.append("\(stats.count) completed start-to-start intervals within these dates: \(lengths.map(String.init).joined(separator: ", ")) days.")
                lines.append("Recorded interval range: \(stats.minimum)–\(stats.maximum) days. Missing starts can lengthen intervals.")
            } else { lines.append("No completed start-to-start intervals within these dates.") }
            lines.append("Unknown ends and the current open interval are not assumed complete.")
            sections.append(.init(kind: .periods, lines: lines))
        }
        if options.symptoms {
            let symptoms = SymptomValidation.sorted(snapshot.symptoms.filter { $0.day >= start && $0.day <= end })
            var lines = ["\(symptoms.count) entries on \(Set(symptoms.map(\.day)).count) days."]
            for entry in symptoms {
                lines.append("\(date(entry.day)): \(entry.kind.title)" + (entry.ratingLabel.map { " · \($0)" } ?? ""))
                if options.notes, let note = entry.notes { lines.append("Note: \(note)") }
            }
            if symptoms.isEmpty { lines.append("No symptom entries recorded in this range.") }
            sections.append(.init(kind: .symptoms, lines: lines))
        }
        if options.context {
            var lines = ["Current profile answers, not a dated history or diagnosis."]
            if let profile = snapshot.profile {
                lines.append("Cycle predictability: \(profile.predictability.title)")
                let context = CycleContext.allCases.filter { profile.cycleContext.contains($0) }
                lines += context.map(\.title)
                if context.isEmpty { lines.append("No cycle context recorded.") }
            } else { lines.append("No profile context recorded.") }
            sections.append(.init(kind: .context, lines: lines))
        }
        if options.trends {
            let periods = snapshot.periods.filter { $0.start >= start && $0.start <= end }.sorted { $0.start < $1.start }
            let symptoms = snapshot.symptoms.filter { $0.day >= start && $0.day <= end }
            let counts = Dictionary(grouping: symptoms, by: \.kind).mapValues(\.count)
            var lines = ["Coverage: \(coverage.loggedDays) of \(coverage.totalDays) days have a daily bleeding answer.",
                         "Period starts: " + (periods.isEmpty ? "none recorded" : periods.map { date($0.start) }.joined(separator: ", "))]
            let ranked = counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            lines += ranked.prefix(8).map { "\($0.key.title): \($0.value) entr\($0.value == 1 ? "y" : "ies") " + String(repeating: "■", count: min($0.value, 12)) }
            if counts.isEmpty { lines.append("No symptom trend can be shown for this range.") }
            lines.append("Bars count saved entries, not days when a symptom was absent. Unlogged days remain unknown.")
            sections.append(.init(kind: .trends, lines: lines))
        }
        let selectedConcerns = options.concerns.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let selectedQuestions = options.questions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !selectedConcerns.isEmpty || !selectedQuestions.isEmpty {
            guard (selectedConcerns + selectedQuestions).allSatisfy({ $0.count <= 500 }) else { throw TrackingError.noteTooLong }
            var lines = selectedConcerns.map { "Concern: \($0)" }
            lines += selectedQuestions.map { "Question: \($0)" }
            sections.append(.init(kind: .concerns, lines: lines))
        }
        if options.treatments {
            let treatments = snapshot.treatments.filter { $0.start <= end && ($0.end ?? end) >= start }
            let factors = snapshot.cycleFactors.filter { $0.start <= end && ($0.end ?? end) >= start }
            var lines = treatments.map {
                "\($0.category.title): \($0.name)" + ($0.dose.map { " · \($0)" } ?? "")
                    + " · \(date($0.start)) – \($0.end.map(date) ?? "ongoing")"
            }
            lines += factors.map {
                "Factor: \($0.kind.title) · \(date($0.start)) – \($0.end.map(date) ?? "ongoing")"
                    + ($0.excludesFromForecast ? " · excluded from forecast intervals" : "")
            }
            if lines.isEmpty { lines.append("No medication, contraception, or dated factors recorded in this range.") }
            lines.append("Self-reported records only; no effectiveness, interaction, or pregnancy-risk calculation.")
            sections.append(.init(kind: .treatments, lines: lines))
        }
        return AppointmentSummaryDocument(title: "Cecy · Appointment summary",
            dateRange: "\(date(start)) – \(date(end))",
            notice: "Saved entries only. Records may be incomplete; not a medical interpretation.",
            sections: sections)
    }
}
