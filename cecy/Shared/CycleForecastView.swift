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


/// One forecast row. Each row opens a short explanation sheet.
struct ForecastItem: Identifiable {
    let id: String
    let caption: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color
    let fill: Color
    let explanation: String
}

extension TrackerPalette {
    /// Ovulation rows use a soft purple so they read apart from bleeding and fertile rows.
    var ovulation: Color {
        scheme == .dark ? Color(red: 0.80, green: 0.72, blue: 0.96) : Color(red: 0.42, green: 0.30, blue: 0.62)
    }
    var ovulationSurface: Color {
        scheme == .dark ? Color(red: 0.20, green: 0.17, blue: 0.27) : Color(red: 0.94, green: 0.92, blue: 0.98)
    }
}

/// Small capsules for the forecast's reliability notes. They are labels, not buttons.
struct ForecastBadges: View {
    let cycle: ProjectedCycle?

    var body: some View {
        if let cycle, cycle.referenceNotice != nil || !cycle.ovulationWarnings.isEmpty {
            SelectionFlowLayout {
                if cycle.referenceNotice != nil {
                    badge(Text("Reference estimate").accessibilityIdentifier("forecastReferenceNotice"), symbol: "info.circle")
                }
                if !cycle.ovulationWarnings.isEmpty {
                    badge(Text("Timing uncertain").accessibilityIdentifier("forecastTimingUncertain"), symbol: "questionmark.circle")
                }
            }
        }
    }

    private func badge(_ text: some View, symbol: String) -> some View {
        Label { text } icon: { Image(systemName: symbol).accessibilityHidden(true) }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.05), in: Capsule())
    }
}

private struct ForecastRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconSize = 20.0
    let item: ForecastItem
    var prominent = false
    var compact = false
    let action: () -> Void

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let badgeSize: CGFloat = prominent ? (compact ? 48 : 56) : (compact ? 42 : 48)
        let icon = Image(systemName: item.symbol)
            .font(.system(size: min(prominent ? iconSize + 4 : iconSize, 30), weight: .medium))
            .foregroundStyle(item.tint)
            .frame(width: badgeSize, height: badgeSize)
            .background(prominent ? item.tint.opacity(0.10) : item.fill, in: Circle())
            .accessibilityHidden(true)
        let chevron = Image(systemName: "chevron.forward")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        let text = VStack(alignment: .leading, spacing: 4) {
            Text(item.caption.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(prominent ? item.tint : .secondary)
            Text(item.value)
                .font(prominent ? (compact ? .headline : .title3.weight(.bold)) : .body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(item.detail)
                .font(.subheadline)
                .foregroundStyle(prominent ? item.tint : .secondary)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // Give the text the full width at the largest sizes.
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { icon; Spacer(minLength: 8); chevron }
                        text
                    }
                } else {
                    HStack(spacing: compact ? 12 : 16) { icon; text; chevron }
                }
            }
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, prominent ? (compact ? 14 : 20) : (compact ? 12 : 16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(prominent ? palette.recordedSurface : palette.surface, in: shape)
            .overlay(alignment: .bottomTrailing) {
                if prominent {
                    // A soft decorative curve, as in the period-window design.
                    Circle().fill(item.tint.opacity(0.06))
                        .frame(width: 150, height: 150)
                        .offset(x: 60, y: 80)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(prominent ? item.tint.opacity(0.12) : Color.primary.opacity(contrast == .increased ? 0.45 : 0.07),
                                   lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.caption), estimate. \(item.value). \(item.detail)")
        .accessibilityHint("Shows what this estimate means")
        .accessibilityIdentifier(item.id)
    }
}

private struct ForecastDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ForecastItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: item.symbol)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(item.tint)
                            .frame(width: 52, height: 52)
                            .background(item.fill, in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.value).font(.title3.weight(.bold))
                            Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(item.explanation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("forecastDetailExplanation")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle(item.caption)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("forecastDetailSheet")
    }
}

struct ProjectedCycleDetails: View {
    @Environment(\.colorScheme) private var colorScheme
    let cycle: ProjectedCycle
    var notBefore: LocalDay? = nil
    var todayStyle = false
    var calendarStyle = false
    var showsBadges = true
    @State private var selected: ForecastItem?

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: calendarStyle ? 10 : 12) {
            if showsBadges { ForecastBadges(cycle: cycle) }
            let period = periodItem(palette)
            // The period start window is the forecast; separate expected bleeding dates were removed as redundant.
            ForecastRow(item: period, prominent: true, compact: calendarStyle) { selected = period }
            if let ovulation = ovulationItem(palette) {
                ForecastRow(item: ovulation, compact: calendarStyle) { selected = ovulation }
                if let fertile = fertileItem(palette) {
                    ForecastRow(item: fertile, compact: calendarStyle) { selected = fertile }
                }
            } else {
                Text("Ovulation and fertile dates unavailable")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let notice = cycle.starterNotice {
                Text(notice).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("forecastStarterNotice")
            }
            if !cycle.isLaterProjection, !cycle.inferredStarts.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "calendar.badge.exclamationmark").accessibilityHidden(true)
                    Text(inferredNotice)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("forecastInferredNotice")
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .sheet(item: $selected) { ForecastDetailSheet(item: $0) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("projectedCycle_\(cycle.index)")
    }

    private var inferredNotice: String {
        let dates = cycle.inferredStarts.map(DayText.monthDay).joined(separator: " and ")
        let subject = cycle.inferredStarts.count == 1 ? "a period that wasn’t logged" : "periods that weren’t logged"
        return "This estimate assumes \(subject), around \(dates). Log it if you remember the date."
    }

    private func periodItem(_ palette: TrackerPalette) -> ForecastItem {
        let start = max(notBefore ?? cycle.period.earliest, cycle.period.earliest)
        let center = cycle.period.center
        let detail = center >= start ? "Most likely \(DayText.short(center))" : "Could start any day now"
        var explanation = center >= start
            ? "Your period will most likely start around \(DayText.short(center)). It could start on any day in this window."
            : "Your period could start any day now. The window ends \(DayText.short(cycle.period.latest))."
        if cycle.isLaterProjection { explanation = "This is a rough projection for a later cycle. " + explanation }
        return ForecastItem(id: "forecastPeriodSection_\(cycle.index)",
                            caption: cycle.isLaterProjection ? "Following period start" : "Period start window",
                            value: DayText.range(start, cycle.period.latest), detail: detail,
                            symbol: "drop", tint: palette.recorded, fill: palette.recordedSurface,
                            explanation: explanation)
    }

    private func ovulationItem(_ palette: TrackerPalette) -> ForecastItem? {
        guard let ovulation = cycle.ovulation else { return nil }
        var explanation = "Ovulation may happen around \(DayText.short(ovulation.center)). Cecy estimates this from your cycle dates. It isn't confirmed."
        if !cycle.ovulationWarnings.isEmpty { explanation += " Your cycles vary so this could be off by a few days." }
        return ForecastItem(id: "forecastOvulation_\(cycle.index)", caption: "Possible ovulation",
                            value: "Around \(DayText.short(ovulation.center))",
                            detail: cycle.isLaterProjection ? "Projection · Timing may vary" : "Timing may vary",
                            symbol: "circle.dotted", tint: palette.ovulation, fill: palette.ovulationSurface,
                            explanation: explanation)
    }

    private func fertileItem(_ palette: TrackerPalette) -> ForecastItem? {
        guard let fertile = cycle.fertileWindow else { return nil }
        return ForecastItem(id: "forecastFertileWindow_\(cycle.index)", caption: "Estimated fertile window",
                            value: DayText.range(fertile.start, fertile.end), detail: "Not for birth control",
                            symbol: "leaf", tint: palette.accent, fill: palette.sage,
                            explanation: "These are the days around your estimated ovulation. Don't rely on them to prevent pregnancy.")
    }
}

struct UpcomingCycleForecastView: View {
    let forecast: CycleForecast
    let today: LocalDay
    var todayStyle = false
    var calendarStyle = false

    var body: some View {
        let cycle = forecast.nextPeriod(onOrAfter: today)
        VStack(alignment: .leading, spacing: calendarStyle ? 14 : 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    heading
                    Spacer(minLength: 0)
                    ForecastBadges(cycle: cycle).fixedSize()
                }
                VStack(alignment: .leading, spacing: 10) {
                    heading
                    ForecastBadges(cycle: cycle)
                }
            }
            if let cycle {
                ProjectedCycleDetails(cycle: cycle, notBefore: today, todayStyle: todayStyle,
                                      calendarStyle: calendarStyle, showsBadges: false)
                if let next = forecast.nextOvulation(onOrAfter: today), next.index != cycle.index {
                    DisclosureGroup {
                        ProjectedCycleDetails(cycle: next, notBefore: today, todayStyle: todayStyle, calendarStyle: calendarStyle)
                            .padding(.top, 12)
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

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Upcoming cycle forecast")
                .font(calendarStyle ? .system(.title3, design: .serif, weight: .semibold) : todayStyle ? TrackerTypography.sectionTitle : .headline)
                .accessibilityAddTraits(.isHeader)
            Text("What to expect in your next cycle.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
