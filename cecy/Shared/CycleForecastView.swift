import SwiftUI

struct TodayEstimatesCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let forecast: CycleForecast
    let today: LocalDay
    var periods: [Period] = []
    var body: some View {
        TrackerCard {
            Text("Today’s estimates").font(TrackerTypography.sectionTitle).accessibilityAddTraits(.isHeader)
            let bleeding = forecast.bleeding(on: today)
            let fertile = forecast.fertile(on: today)
            let ovulation = forecast.ovulation(on: today)
            let period = forecast.period(on: today)
            let status = TodayCurrentPeriodStatus(periods: periods, forecast: forecast, today: today)
            if let status {
                Label { Text(status.title).font(.headline) } icon: {
                    Image(systemName: "drop.fill").foregroundStyle(.red)
                }.accessibilityIdentifier("todayEstimatePeriodStatus")
            }
            if period != nil { Label("Within a possible period-start window", systemImage: "circle.dashed") }
            if fertile != nil { Label("Within an estimated fertile window", systemImage: "leaf") }
            if ovulation != nil { Label("Possible ovulation today · Not confirmed", systemImage: "circle.dotted") }
            if status == nil && fertile == nil && ovulation == nil && period == nil {
                HStack(spacing: 16) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2).foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(TrackerPalette(scheme: colorScheme).accent.opacity(0.4),
                                                      style: StrokeStyle(lineWidth: 1, dash: [2, 4])))
                        .accessibilityHidden(true)
                    Text("No estimate for today").font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(TrackerPalette(scheme: colorScheme).sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 22))
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
    var todayStyle = false
    var calendarStyle = false

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 20) {
            if let notice = cycle.starterNotice {
                Text(notice).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("forecastStarterNotice")
            }
            if cycle.referenceNotice != nil || !cycle.ovulationWarnings.isEmpty {
                SelectionFlowLayout {
                    if cycle.referenceNotice != nil {
                        Text("Reference estimate").accessibilityIdentifier("forecastReferenceNotice")
                    }
                    if !cycle.ovulationWarnings.isEmpty {
                        Label {
                            Text("Timing uncertain").accessibilityIdentifier("forecastTimingUncertain")
                        } icon: {
                            Image(systemName: "questionmark.circle").accessibilityHidden(true)
                        }
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: calendarStyle ? 12 : 20) {
            VStack(alignment: .leading, spacing: calendarStyle ? 8 : 12) {
                Label(cycle.isLaterProjection ? "Following period start · Projection" : "Possible period start · Estimate",
                      systemImage: "circle.dashed")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(palette.recorded)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notBefore == nil ? "Start window" : "Remaining start window")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(DayText.range(max(notBefore ?? cycle.period.earliest, cycle.period.earliest), cycle.period.latest))
                        .font(calendarStyle ? .headline : TrackerTypography.sectionTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("forecastPeriodWindow_\(cycle.index)")
                    Text("Around \(DayText.short(cycle.period.center))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(calendarStyle ? 12 : 16)
            .background(palette.recordedSurface, in: RoundedRectangle(cornerRadius: TrackerLayout.controlRadius, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("forecastPeriodSection_\(cycle.index)")

            if let bleeding = cycle.bleeding {
                ForecastDateRow(title: "Expected bleeding dates", value: DayText.range(bleeding.start, bleeding.end),
                                symbol: "drop", accent: palette.recorded, identifier: "forecastBleedingDates_\(cycle.index)")
            } else {
                Text("Bleeding duration unavailable")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Divider()

            if let ovulation = cycle.ovulation {
                ForecastDateRow(title: cycle.isLaterProjection ? "Possible ovulation · Projection" : "Possible ovulation · Estimate",
                                value: "Around \(DayText.short(ovulation.center))", symbol: "circle.dotted",
                                accent: palette.accent, identifier: "forecastOvulation_\(cycle.index)")
                if let fertile = cycle.fertileWindow {
                    if todayStyle || calendarStyle { Divider() }
                    ForecastDateRow(title: "Estimated fertile window", value: DayText.range(fertile.start, fertile.end),
                                    symbol: "leaf", accent: palette.accent, identifier: "forecastFertileWindow_\(cycle.index)")
                }
            } else {
                Text("Ovulation and fertile dates unavailable")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projectedCycle_\(cycle.index)")
    }
}

/// A quiet label and prominent date, aligned consistently without another nested card.
private struct ForecastDateRow: View {
    let title: String
    let value: String
    let symbol: String
    let accent: Color
    let identifier: String
    @ScaledMetric(relativeTo: .body) private var iconSize = 18.0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: iconSize + 18, height: iconSize + 18)
                .background(accent.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier)
                Text(value).font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier)_value")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}

struct UpcomingCycleForecastView: View {
    let forecast: CycleForecast
    let today: LocalDay
    var todayStyle = false
    var calendarStyle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Upcoming cycle forecast")
                .font(calendarStyle ? .system(.title3, design: .serif, weight: .semibold) : todayStyle ? TrackerTypography.sectionTitle : .headline)
                .accessibilityAddTraits(.isHeader)
            if let cycle = forecast.nextPeriod(onOrAfter: today) {
                ProjectedCycleDetails(cycle: cycle, notBefore: today, todayStyle: todayStyle, calendarStyle: calendarStyle)
                if let next = forecast.nextOvulation(onOrAfter: today), next.index != cycle.index {
                    Divider()
                    DisclosureGroup {
                        ProjectedCycleDetails(cycle: next, notBefore: today, todayStyle: todayStyle, calendarStyle: calendarStyle).padding(.top, 16)
                    } label: {
                        Text("Next projected ovulation")
                            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("nextProjectedOvulation")
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
