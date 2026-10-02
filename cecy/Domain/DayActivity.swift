import Foundation

nonisolated struct DayActivityMarker: Identifiable, Equatable, Sendable {
    let id: String
    let symbol: String
    let title: String

    static func recorded(on day: LocalDay, in snapshot: TrackerSnapshot) -> [Self] {
        var markers: [Self] = []
        if let period = snapshot.periods.first(where: { $0.contains(day) }) {
            markers.append(Self(id: "period", symbol: "drop.fill", title: period.start == day ? "Period start" : "Confirmed bleeding"))
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
}