import Testing
@testable import cecy

struct DailyLogTests {
    @Test func combinesTypesOnOneDayAndIncludesOnlyConfirmedDates() throws {
        let start = try LocalDay(key: 20260902)
        let next = try start.adding(days: 1)
        let openStart = try LocalDay(key: 20260929)
        let snapshot = TrackerSnapshot(periods: [Period(start: start, end: next), Period(start: openStart)],
            symptoms: [SymptomEntry(day: start, kind: .cramps), SymptomEntry(day: start, kind: .headache)],
            sexualActivities: [SexualActivityEntry(day: start, activities: [.other])])
        let index = DayActivityIndex(snapshot: snapshot)
        #expect(index.loggedDays() == [openStart, next, start])
        #expect(index.markers(on: start).map(\.id) == ["period", "symptom.cramps", "symptom.headache", "sexualActivity"])
        #expect(index.markers(on: next).map(\.id) == ["period"])
        #expect(index.markers(on: try openStart.adding(days: 1)).isEmpty)
        #expect(index.loggedDays(before: start).isEmpty)
        #expect(DayActivityIndex().loggedDays().isEmpty)
        #expect(index.loggedDays(limit: 0).isEmpty)
    }

    @Test func pagesAcrossLeapDayWithoutDuplicatesOrMissingDays() throws {
        let start = try LocalDay(key: 20240227)
        let end = try LocalDay(key: 20240302)
        let later = try LocalDay(key: 20240305)
        let index = DayActivityIndex(snapshot: TrackerSnapshot(periods: [Period(start: start, end: end)],
            symptoms: [SymptomEntry(day: later, kind: .headache), SymptomEntry(day: start, kind: .cramps)]))
        let first = index.loggedDays(limit: 3)
        let second = index.loggedDays(before: first.last, limit: 3)
        #expect(first.map(\.key) == [20240305, 20240302, 20240301])
        #expect(second.map(\.key) == [20240229, 20240228, 20240227])
        #expect(index.loggedDays(before: second.last, limit: 3).isEmpty)
        #expect(Set(first + second).count == 6)
    }

    @Test func longConfirmedSpanStillReturnsBoundedPages() throws {
        let start = try LocalDay(key: 19000101)
        let end = try LocalDay(key: 20260929)
        let index = DayActivityIndex(snapshot: TrackerSnapshot(periods: [Period(start: start, end: end)]))
        let days = index.loggedDays()
        #expect(days.count == 30)
        #expect(days.first == end)
        #expect(days.last == (try end.adding(days: -29)))
        #expect(index.loggedDays(before: days.last).first == (try end.adding(days: -30)))
    }

    @Test func boundedPagesMatchRecordedMarkersAcrossMixedHistory() throws {
        let start = try LocalDay(key: 20240101)
        let periods = try stride(from: 0, to: 180, by: 28).map {
            Period(start: try start.adding(days: $0), end: try start.adding(days: $0 + 4))
        }
        let symptoms = try stride(from: 1, to: 200, by: 3).map {
            SymptomEntry(day: try start.adding(days: $0), kind: .headache)
        }
        let snapshot = TrackerSnapshot(periods: periods, symptoms: symptoms)
        let expected = try (0..<200).map { try start.adding(days: $0) }
            .filter { !DayActivityMarker.recorded(on: $0, in: snapshot).isEmpty }.reversed()
        let index = DayActivityIndex(snapshot: snapshot)
        var actual: [LocalDay] = []
        for _ in 0..<30 {
            let page = index.loggedDays(before: actual.last, limit: 7)
            if page.isEmpty { break }
            actual += page
        }
        #expect(actual == Array(expected))
    }
}
