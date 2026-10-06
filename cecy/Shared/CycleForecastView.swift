import SwiftUI

struct TodayEstimatesCard: View {
    let forecast: CycleForecast
    let today: LocalDay
    var body: some View {
        TrackerCard {
            Text("Today’s estimates").font(.headline).accessibilityAddTraits(.isHeader)
            let bleeding = forecast.bleeding(on: today)
            let fertile = forecast.fertile(on: today)
            let ovulation = forecast.ovulation(on: today)
            let period = forecast.period(on: today)
            if bleeding != nil { Label("Expected bleeding day · Not recorded", systemImage: "drop") }
            if period != nil { Label("Within a possible period-start window", systemImage: "circle.dashed") }
            if fertile != nil { Label("Within an estimated fertile window", systemImage: "leaf") }
            if ovulation != nil { Label("Possible ovulation today · Not confirmed", systemImage: "circle.dotted") }
            if bleeding == nil && fertile == nil && ovulation == nil && period == nil {
                Text("No estimate for today").font(.subheadline)
            }
            if let cycle = fertile ?? ovulation ?? period ?? bleeding, !cycle.ovulationWarnings.isEmpty {
                Text("Timing uncertain").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todayEstimates")
    }
}

struct ProjectedCycleDetails: View {
    @Environment(\.colorScheme) private var colorScheme
    let cycle: ProjectedCycle
    var notBefore: LocalDay? = nil

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            if cycle.referenceNotice != nil {
                Text("Reference estimate").font(.footnote).accessibilityIdentifier("forecastReferenceNotice")
            }
            if !cycle.ovulationWarnings.isEmpty {
                Text("Timing uncertain").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("forecastTimingUncertain")
            }
            if let ovulation = cycle.ovulation {
                Label(cycle.isLaterProjection ? "Possible ovulation · Projection" : "Possible ovulation · Estimate",
                      systemImage: "circle.dotted")
                    .font(.headline).foregroundStyle(palette.accent)
                Text("Around \(DayText.short(ovulation.center))").font(.subheadline.weight(.semibold))
                if let fertile = cycle.fertileWindow {
                    Label("Estimated fertile window", systemImage: "leaf")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(palette.accent)
                        .accessibilityIdentifier("forecastFertileWindow_\(cycle.index)")
                    Text(DayText.range(fertile.start, fertile.end)).font(.subheadline)
                }
            } else {
                Text("Ovulation and fertile dates unavailable")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Label(cycle.isLaterProjection ? "Following period start · Projection" : "Possible period start · Estimate",
                  systemImage: "circle.dashed")
                .font(.subheadline.weight(.semibold)).foregroundStyle(palette.recorded)
            Text("Around \(DayText.short(cycle.period.center))").font(.subheadline.weight(.semibold))
            Text("\(notBefore == nil ? "Start window" : "Remaining start window"): \(DayText.range(max(notBefore ?? cycle.period.earliest, cycle.period.earliest), cycle.period.latest))").font(.subheadline)
            if let bleeding = cycle.bleeding {
                Label("Expected bleeding dates", systemImage: "drop")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(palette.recorded)
                Text(DayText.range(bleeding.start, bleeding.end)).font(.subheadline)
            } else {
                Text("Bleeding duration unavailable")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projectedCycle_\(cycle.index)")
    }
}

struct UpcomingCycleForecastView: View {
    let forecast: CycleForecast
    let today: LocalDay

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming cycle forecast").font(.headline).accessibilityAddTraits(.isHeader)
            if let cycle = forecast.nextPeriod(onOrAfter: today) {
                ProjectedCycleDetails(cycle: cycle, notBefore: today)
                if let next = forecast.nextOvulation(onOrAfter: today), next.index != cycle.index {
                    DisclosureGroup("Next projected ovulation") { ProjectedCycleDetails(cycle: next, notBefore: today) }
                }
            } else {
                Text("Forecast unavailable")
                    .font(.subheadline)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upcomingCycleForecast")
    }
}
