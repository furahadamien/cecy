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
    var hasSection: Bool { periods || dailyAnswers || symptoms || context }
}

nonisolated enum AppointmentSummary {
    /// No identity, sexual activity, partner answers, IDs, predictions, or remote generation.
    /// Dates are stable civil dates. Identical records and options produce identical text.
    static func text(snapshot: TrackerSnapshot, start: LocalDay, end: LocalDay,
                     options: AppointmentSummaryOptions) throws -> String {
        guard start <= end, options.hasSection else { throw TrackingError.invalidData }
        try PeriodValidation.validate(snapshot.periods)
        try SymptomValidation.validate(snapshot.symptoms)
        let coverage = try RecordingCoverage(snapshot: snapshot, start: start, end: end)
        let date = TrackerExport.civilDate
        var lines = ["Cecy · Appointment summary", "\(date(start)) – \(date(end))",
                     "Saved entries only. Records may be incomplete; not a medical interpretation."]
        if options.dailyAnswers {
            lines += ["", "DAILY ANSWERS", "Days logged: \(coverage.loggedDays) of \(coverage.totalDays)",
                      "Not logged: \(coverage.unloggedDays)"]
            for state in DailyBleedingState.allCases { lines.append("\(state.title): \(coverage.count(state))") }
            lines.append("Not logged does not mean no bleeding. Not sure is a recorded uncertain answer.")
            for answer in coverage.answers {
                lines.append("\(date(answer.day)): \(answer.state.title)" + (answer.flow.map { " · \($0.title) flow" } ?? ""))
            }
            if coverage.answers.isEmpty { lines.append("No daily answers recorded in this range.") }
        }
        if options.periods {
            let periods = snapshot.periods.sorted { $0.start < $1.start }
            let included = periods.filter { $0.start <= end && ($0.end ?? $0.start) >= start }
            lines += ["", "RECORDED PERIODS", "Periods overlapping these dates; original dates shown. Daily answers are counted separately."]
            for period in included {
                var line = "\(date(period.start)) – " + (period.end.map(date) ?? "end not recorded")
                if let duration = period.duration { line += " · \(duration) confirmed days" }
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
        }
        if options.symptoms {
            let symptoms = SymptomValidation.sorted(snapshot.symptoms.filter { $0.day >= start && $0.day <= end })
            lines += ["", "SYMPTOMS AND WELLNESS", "\(symptoms.count) entries on \(Set(symptoms.map(\.day)).count) days."]
            for entry in symptoms {
                lines.append("\(date(entry.day)): \(entry.kind.title)" + (entry.ratingLabel.map { " · \($0)" } ?? ""))
                if options.notes, let note = entry.notes { lines.append("Note: \(note)") }
            }
            if symptoms.isEmpty { lines.append("No symptom entries recorded in this range.") }
        }
        if options.context {
            lines += ["", "CURRENT SELF-REPORTED CONTEXT", "Current profile answers, not a dated history or diagnosis."]
            if let profile = snapshot.profile {
                lines.append("Cycle predictability: \(profile.predictability.title)")
                let context = CycleContext.allCases.filter { profile.cycleContext.contains($0) }
                lines += context.map(\.title)
                if context.isEmpty { lines.append("No cycle context recorded.") }
            } else { lines.append("No profile context recorded.") }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}