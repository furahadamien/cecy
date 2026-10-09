import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct TodayRefreshLayoutTests {
    @Test(arguments: [280.0, 353.0, 600.0], [ColorScheme.light, .dark])
    func phaseTilesAndEstimatesFitWithAndWithoutHistory(width: Double, scheme: ColorScheme) throws {
        let today = try LocalDay(key: 20260929)
        for hasHistory in [true, false] {
            let session = TrackerSession.preview(withHistory: hasHistory)
            let original = session.snapshot.periods
            let overview = CycleCalculator.overview(periods: original, today: today, profile: session.snapshot.profile)
            for size in [DynamicTypeSize.large, .xxxLarge, .accessibility5] {
                let content = VStack(spacing: 24) {
                    CyclePhaseRingView(session: session, today: today, overview: overview)
                    TodayEstimatesCard(forecast: session.cycleForecast, today: today)
                    TrackerCard {
                        UpcomingCycleForecastView(forecast: session.cycleForecast, today: today, todayStyle: true)
                    }
                }
                .environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, scheme)
                let host = UIHostingController(rootView: content)
                host.traitOverrides.accessibilityContrast = .high
                let measured = host.sizeThatFits(in: CGSize(width: width, height: 30_000))
                #expect(measured.width.isFinite && measured.height.isFinite)
                #expect(measured.width <= width + 1)
                #expect(measured.height > 0 && measured.height < 30_000)
                #expect(session.snapshot.periods == original)
            }
        }
    }
}