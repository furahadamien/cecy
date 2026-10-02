import Foundation

/// Presentation-sized subsets of recorded evidence; never predictions or inferred missing days.
nonisolated enum InsightChartData {
    struct ObservationCount: Identifiable, Equatable, Sendable {
        let kind: SymptomKind
        let days: Int
        var id: SymptomKind { kind }
    }

    static func recentIntervals(_ intervals: [CycleInterval], today: LocalDay) -> [CycleInterval] {
        Array(intervals.filter { $0.nextStart <= today && $0.length > 0 }
            .sorted { $0.start < $1.start }.suffix(12))
    }

    static func observationCounts(_ entries: [SymptomEntry], today: LocalDay) -> [ObservationCount] {
        let recent = entries.filter { (0..<90).contains($0.day.days(until: today)) }
        return Dictionary(grouping: recent, by: \.kind).map { kind, records in
            ObservationCount(kind: kind, days: Set(records.map(\.day)).count)
        }.sorted {
            $0.days == $1.days ? $0.kind.rawValue < $1.kind.rawValue : $0.days > $1.days
        }
    }
}
