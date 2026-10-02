import Foundation

nonisolated struct PreparedRecordAnswer: Identifiable, Equatable, Sendable {
    let id: String
    let question: String
    let answer: String
}

nonisolated enum PreparedRecordAnswers {
    static func build(snapshot: TrackerSnapshot, today: LocalDay) -> [PreparedRecordAnswer] {
        let periods = snapshot.periods.filter { $0.start <= today }.sorted { $0.start < $1.start }
        let lengths = Array(zip(periods, periods.dropFirst()).map { $0.start.days(until: $1.start) }.suffix(6))
        let cycleAnswer: String
        if lengths.isEmpty {
            cycleAnswer = "There is no completed start-to-start interval yet. Two recorded starts are needed to measure a cycle length; an entered typical length is not a measured cycle."
        } else {
            let mean = Double(lengths.reduce(0, +)) / Double(lengths.count)
            cycleAnswer = "Your \(lengths.count) most recent completed interval(s) average \(mean.formatted(.number.precision(.fractionLength(1)))) days. Missing period records can lengthen a measured interval."
        }
        let observations = snapshot.symptoms.filter { $0.day <= today && $0.day.days(until: today) < 90 }
        let grouped: [SymptomKind: [SymptomEntry]] = Dictionary(grouping: observations, by: \.kind)
        var counts: [(kind: SymptomKind, days: Int)] = []
        for (kind, entries) in grouped {
            counts.append((kind: kind, days: Set(entries.map(\.day)).count))
        }
        counts.sort {
            if $0.days == $1.days { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.days > $1.days
        }
        let symptomAnswer = counts.isEmpty
            ? "No observations are logged in the last 90 days. This does not mean symptoms were absent."
            : counts.prefix(3).map { "\($0.kind.title): \($0.days) logged day(s)" }.joined(separator: ". ")
                + ". These counts cover the last 90 days, not unlogged symptoms."
        return [
            PreparedRecordAnswer(id: "starts", question: "How many periods have I recorded?",
                answer: "You have \(periods.count) recorded period start(s). \(periods.filter { $0.end != nil }.count) have a confirmed end. Missing ends stay unknown."),
            PreparedRecordAnswer(id: "lengths", question: "What do my cycle lengths show?", answer: cycleAnswer),
            PreparedRecordAnswer(id: "symptoms", question: "Which observations have I logged most?", answer: symptomAnswer)
        ]
    }
}
