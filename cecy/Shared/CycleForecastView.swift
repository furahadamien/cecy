import SwiftUI

struct ProjectedCycleDetails: View {
    @Environment(\.colorScheme) private var colorScheme
    let cycle: ProjectedCycle
    var notBefore: LocalDay? = nil

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            if let notice = cycle.referenceNotice {
                Text(notice).font(.footnote).accessibilityIdentifier("forecastReferenceNotice")
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
                    Text("Six estimated days, not six days of ovulation. Fertility may occur outside these dates.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(cycle.ovulationBasis).font(.footnote).foregroundStyle(.secondary)
                ForEach(cycle.ovulationWarnings, id: \.self) { warning in
                    Text(warning).font(.footnote)
                        .accessibilityIdentifier("ovulationContextWarning")
                }
                DisclosureGroup("Timing uncertainty") {
                    Text("Ovulation timing: \(DayText.range(ovulation.earliest, ovulation.latest))")
                    if let envelope = cycle.fertileEnvelope {
                        Text("Fertile-window timing envelope: \(DayText.range(envelope.start, envelope.end))")
                    }
                    Text("These are illustrative timing bounds, not measured confidence intervals or the duration of ovulation. Actual timing can fall outside them. No dates are identified as safe days.")
                }
                .font(.footnote)
                .accessibilityIdentifier("ovulationUncertainty_\(cycle.index)")
            } else {
                Text("Ovulation and fertile dates are unavailable: this cycle length does not support the calendar assumption.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Label(cycle.isLaterProjection ? "Following period start · Projection" : "Possible period start · Estimate",
                  systemImage: "circle.dashed")
                .font(.subheadline.weight(.semibold)).foregroundStyle(palette.recorded)
            Text("Around \(DayText.short(cycle.period.center))").font(.subheadline.weight(.semibold))
            Text("\(notBefore == nil ? "Start window" : "Remaining start window"): \(DayText.range(max(notBefore ?? cycle.period.earliest, cycle.period.earliest), cycle.period.latest))").font(.subheadline)
            if let bleeding = cycle.bleeding, let duration = cycle.bleedingDuration {
                Label("Expected bleeding dates", systemImage: "drop")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(palette.recorded)
                Text(DayText.range(bleeding.start, bleeding.end)).font(.subheadline)
                Text(duration.measuredCount == 0
                     ? "Uses your entered \(duration.days)-day period length. These are not recorded bleeding days."
                     : "Uses a \(duration.days)-day median from \(duration.measuredCount) confirmed period duration(s). These are not recorded bleeding days.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let envelope = cycle.bleedingEnvelope {
                    DisclosureGroup("Bleeding timing uncertainty") {
                        Text(DayText.range(envelope.start, envelope.end))
                        Text("Combines start uncertainty and recorded duration variation—not a prediction of continuous bleeding throughout this range. Duration may differ next time.")
                    }.font(.footnote)
                }
            } else {
                Text("Bleeding duration is unknown or does not fit this cycle. Add a typical period length or confirm actual end dates.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text(cycle.assumption).font(.footnote).foregroundStyle(.secondary)
            Text("Calendar estimates only—not confirmed ovulation or contraception guidance.")
                .font(.caption).foregroundStyle(.secondary)
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
                Text(forecast.ovulationUnavailableReason
                     ?? "There is not enough usable information for an upcoming forecast. Review actual period starts or your typical cycle length.")
                    .font(.subheadline)
            }
            DisclosureGroup("How this forecast works") {
                Text("Up to six recent cycle lengths determine the period estimate; confirmed end dates refine bleeding duration. Upcoming projections remain visible as time passes without creating missing records. If history cannot support an estimate, a saved typical length can provide an explicitly labelled reference. More data may widen rather than narrow estimates; these ranges are not measured probabilities.")
                Text(OvulationNotice.explanation)
                Text("A projected date does not mean missed periods occurred. Your original record-based estimate, statistics and reminders stay separate from these calendar projections. Record actual starts and bleeding days to refine the forecast.")
            }.font(.footnote)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("upcomingCycleForecast")
    }
}
