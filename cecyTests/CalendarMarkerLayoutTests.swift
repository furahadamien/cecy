import SwiftUI
import Testing
@testable import cecy

@MainActor struct CalendarMarkerLayoutTests {
    private func fixture() throws -> (LocalDay, CycleForecast) {
        let day = try LocalDay(key: 20261001)
        var profile = LocalProfile()
        profile.typicalCycleDays = 28
        profile.typicalPeriodDays = 5
        return (day, CycleForecast.calculate(
            overview: CycleCalculator.overview(periods: [Period(start: day)], today: day, profile: profile),
            profile: profile))
    }

    @Test func forecastAndActivityMarkersShareOneCollectionWithoutReplacingRecords() throws {
        let (start, forecast) = try fixture()
        let day = try start.adding(days: 28)
        let recorded = [DayActivityMarker(id: "period", symbol: "drop.fill", title: "Period start"),
                        DayActivityMarker(id: "sexualActivity", symbol: "heart.fill", title: "Sexual activity"),
                        DayActivityMarker(id: "symptom.cramps", symbol: "bolt", title: "Cramps")]
        let combined = DayActivityMarker.calendar(recorded: recorded, forecast: forecast, day: day)
        #expect(combined.count == 4)
        #expect(combined.first?.id == "forecast.bleeding" && combined.first?.symbol == "drop")
        #expect(Array(combined.dropFirst()) == recorded)
        #expect(Set(combined.map(\.id)).count == combined.count)
    }

    @Test func fertileMarkerAppearsInFirstRowWithExistingActivity() throws {
        let (start, forecast) = try fixture()
        let day = try start.adding(days: 9)
        let recorded = [DayActivityMarker(id: "sexualActivity", symbol: "heart.fill", title: "Sexual activity")]
        let combined = DayActivityMarker.calendar(recorded: recorded, forecast: forecast, day: day)
        #expect(combined.map(\.id) == ["forecast.fertile", "sexualActivity"])
        #expect(combined.first?.symbol == "leaf")
        #expect(DayActivityMarker.calendar(recorded: recorded, forecast: forecast, day: start) == recorded)
    }

    @Test func eagerGridReservesAllRowsAndKeepsSingleRowForecastCompact() {
        let marker = DayActivityMarker(id: "forecast.fertile", symbol: "leaf", title: "Estimated fertile window")
        let single = UIHostingController(rootView: DayActivityIcons(markers: [marker]))
        let dense = (0..<17).map { DayActivityMarker(id: "marker.\($0)", symbol: "drop", title: "Synthetic") }
        let multiple = UIHostingController(rootView: DayActivityIcons(markers: dense))
        let reserved = UIHostingController(rootView: DayActivityIcons(markers: [], minimumRows: 6))
        let proposal = CGSize(width: 48, height: 500)
        #expect(single.sizeThatFits(in: proposal).height == 12)
        #expect(multiple.sizeThatFits(in: proposal).height == 82)
        #expect(reserved.sizeThatFits(in: proposal).height == 82)
    }
}
