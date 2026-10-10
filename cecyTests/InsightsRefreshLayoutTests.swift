import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct InsightsRefreshLayoutTests {
    @Test func coverageVisualsUseExplicitCountsNotPeriodRanges() throws {
        let today = try LocalDay(key: 20261009)
        let start = try today.adding(days: -29)
        let snapshot = TrackerSnapshot(periods: [Period(start: start, end: today)])
        let coverage = try RecordingCoverage(snapshot: snapshot, start: start, end: today)
        #expect(coverage.loggedDays == 0 && coverage.unloggedDays == 30)
        #expect(RecordingCoverageDisplay.fraction(1, total: 30) == 1.0 / 30)
        #expect(RecordingCoverageDisplay.fraction(90, total: 90) == 1)
        #expect(RecordingCoverageDisplay.fraction(0, total: 0) == 0)
    }

    @Test(arguments: [280.0, 350.0, 600.0], [ColorScheme.light, .dark])
    func insightsCardsFitWithoutMutatingData(width: Double, scheme: ColorScheme) throws {
        let today = try LocalDay(key: 20260929)
        for history in [false, true] {
            let session = TrackerSession.preview(withHistory: history)
            let periods = session.snapshot.periods
            for size in [DynamicTypeSize.large, .accessibility5] {
                let content = VStack(spacing: 16) {
                    RecordingCoverageCard(session: session, today: today)
                    ForTodayCard(session: session, today: today)
                }.environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
                let host = UIHostingController(rootView: content)
                let measured = host.sizeThatFits(in: CGSize(width: width, height: 30_000))
                #expect(measured.width.isFinite && measured.height.isFinite)
                #expect(measured.width <= width + 1)
                #expect(measured.height > 0 && measured.height < 30_000)
                #expect(session.snapshot.periods == periods)
                #expect(!session.privacy.dailyInsightsEnabled)
            }
        }
    }
}