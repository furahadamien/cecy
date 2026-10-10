import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct ForecastCardLayoutTests {
    @Test(arguments: [280.0, 600.0], [ColorScheme.light, .dark])
    func forecastSectionsFitWithoutFixedHeightOrHorizontalClipping(width: Double, scheme: ColorScheme) throws {
        let today = try LocalDay(key: 20261229)
        let start = try LocalDay(key: 20261202)
        for hasBleedingDuration in [true, false] {
            var profile = LocalProfile()
            profile.typicalCycleDays = 28
            profile.typicalPeriodDays = hasBleedingDuration ? 5 : nil
            profile.cycleContext = [.hormonalBirthControl]
            let overview = CycleCalculator.overview(periods: [Period(start: start)], today: today, profile: profile)
            let forecast = CycleForecast.calculate(overview: overview, profile: profile)
            let cycle = try #require(forecast.cycles.last)
            #expect(!cycle.ovulationWarnings.isEmpty)
            func height(_ size: DynamicTypeSize) -> CGFloat {
                let view = VStack(spacing: 24) {
                    TrackerCard { UpcomingCycleForecastView(forecast: forecast, today: today) }
                    TrackerCard { ProjectedCycleDetails(cycle: cycle) }
                    TrackerCard { UpcomingCycleForecastView(forecast: forecast, today: today, calendarStyle: true) }
                    TrackerCard { ProjectedCycleDetails(cycle: cycle, calendarStyle: true) }
                }
                .environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, scheme)
                let host = UIHostingController(rootView: view)
                host.traitOverrides.accessibilityContrast = .high
                let measured = host.sizeThatFits(in: CGSize(width: width, height: 20_000))
                #expect(measured.width.isFinite && measured.height.isFinite)
                #expect(measured.width <= width + 1)
                #expect(measured.height > 0 && measured.height < 20_000)
                return measured.height
            }
            #expect(height(.accessibility5) > height(.large))
        }
    }
}
