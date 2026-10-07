import Foundation
import Testing
@testable import cecy

struct DailyBleedingPresentationTests {
    @Test func allDailyStatesAgreeAcrossIndexedAndDirectMarkers() throws {
        let today = try LocalDay(key: 20261007)
        for state in DailyBleedingState.allCases {
            let snapshot = TrackerSnapshot(symptoms: [SymptomEntry(day: today, kind: .cramps)],
                dailyBleeding: [DailyBleedingObservation(day: today, state: state)])
            let index = DayActivityIndex(snapshot: snapshot)
            #expect(index.markers(on: today) == DayActivityMarker.recorded(on: today, in: snapshot))
            #expect(index.markers(on: today).first?.title == "Daily answer: \(state.title)")
            #expect(index.loggedDays() == [today])
            #expect(index.markers(on: try today.adding(days: -1)).isEmpty)
        }
    }

    @Test func multiYearDailyRecordsPageWithoutInventingCoverage() throws {
        let start = try LocalDay(key: 20200101)
        let answers = try stride(from: 0, to: 2500, by: 2).map {
            DailyBleedingObservation(day: try start.adding(days: $0), state: .unsure)
        }
        let index = DayActivityIndex(snapshot: TrackerSnapshot(dailyBleeding: answers))
        let first = index.loggedDays()
        let second = index.loggedDays(before: first.last)
        #expect(first.count == 30 && second.count == 30 && Set(first + second).count == 60)
        #expect(first + second == answers.suffix(60).reversed().map(\.day))
    }

    @Test func correctingPeriodOnlyProposesUnlinkingAndPreservesDailyFacts() throws {
        let day = try LocalDay(key: 20261007)
        let period = Period(start: try day.adding(days: -2), end: day)
        let answer = DailyBleedingObservation(day: day, state: .bleeding, flow: .heavy, periodID: period.id)
        let snapshot = TrackerSnapshot(periods: [period], dailyBleeding: [answer])
        var review = BleedingReconciliation(snapshot: snapshot)
        var shortened = period; shortened.end = try day.adding(days: -1)
        review.replacePeriod(shortened)
        #expect(review.detachedAnswers == [answer])
        #expect(review.observations[0].flow == .heavy && review.observations[0].id == answer.id)
        #expect(review.expectedObservations == snapshot.dailyBleeding && snapshot.periods == [period])
        try DailyBleedingValidation.validate(review.observations, periods: review.periods, asOf: day)
    }
}