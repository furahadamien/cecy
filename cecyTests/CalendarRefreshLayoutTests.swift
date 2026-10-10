import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct CalendarRefreshLayoutTests {
    @Test func legendKeepsAllMeaningsWithoutEstimatedBleedingDroplet() {
        let items = CalendarSymbolLegend.items
        #expect(items.map(\.id) == ["period", "estimate", "ovulation", "fertile", "sex", "symptoms", "bleeding"])
        #expect(!items.contains { $0.symbol == "drop" })
        #expect(items.first { $0.id == "estimate" }?.symbol == "circle.dashed")
        #expect(items.first { $0.id == "bleeding" }?.description.contains("Not a period start") == true)
        #expect(items.first { $0.id == "ovulation" }?.description.contains("Not confirmed") == true)
    }

    @Test(arguments: [280.0, 358.0, 600.0], [ColorScheme.light, .dark])
    func calendarSurfacesFitWithoutChangingRecords(width: Double, scheme: ColorScheme) throws {
        let today = try LocalDay(key: 20260929)
        for history in [false, true] {
            let session = TrackerSession.preview(withHistory: history)
            let records = session.snapshot.periods
            for size in [DynamicTypeSize.large, .xxxLarge, .accessibility5] {
                let content = VStack(spacing: 16) {
                    CalendarSymbolLegend()
                    RecordedDayCard(session: session, day: records.last?.start ?? today, today: today)
                        .environment(\.calendarRecordStyle, true)
                    TrackerCard {
                        UpcomingCycleForecastView(forecast: session.cycleForecast, today: today, calendarStyle: true)
                    }
                }
                .environment(\.dynamicTypeSize, size).environment(\.colorScheme, scheme)
                let host = UIHostingController(rootView: content)
                host.traitOverrides.accessibilityContrast = .high
                let measured = host.sizeThatFits(in: CGSize(width: width, height: 30_000))
                #expect(measured.width.isFinite && measured.height.isFinite)
                #expect(measured.width <= width + 1)
                #expect(measured.height > 0 && measured.height < 30_000)
                #expect(session.snapshot.periods == records)
            }
        }
    }
}