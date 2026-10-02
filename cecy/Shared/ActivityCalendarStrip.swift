import SwiftUI

/// Distinct symbols for predictions: never reuse the filled recorded-period drop.
struct ForecastDayIcons: View {
    @Environment(\.colorScheme) private var colorScheme
    let forecast: CycleForecast
    let day: LocalDay

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        HStack(spacing: 4) {
            if forecast.bleeding(on: day) != nil {
                Image(systemName: "drop").foregroundStyle(palette.recorded)
            }
            if forecast.fertile(on: day) != nil {
                Image(systemName: "leaf").foregroundStyle(palette.accent)
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .accessibilityHidden(true)
    }
}

struct DayActivityIcons: View {
    @Environment(\.colorScheme) private var colorScheme
    let markers: [DayActivityMarker]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 4) {
            ForEach(markers) { marker in
                Image(systemName: marker.symbol).font(.system(size: 10, weight: .medium))
                    .foregroundStyle(marker.id == "period"
                                     ? TrackerPalette(scheme: colorScheme).recorded
                                     : marker.id == "sexualActivity"
                                        ? TrackerPalette(scheme: colorScheme).sexualActivity
                                        : TrackerPalette(scheme: colorScheme).accent)
            }
        }
        .frame(minHeight: 10)
        // The containing date button reads the full list, not unlabeled tiny images.
        .accessibilityHidden(true)
    }
}

struct ActivityCalendarStrip: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var dayWidth = 48.0
    let today: LocalDay
    let activityIndex: DayActivityIndex
    let forecast: CycleForecast
    @Binding var selection: LocalDay
    @State private var lower = -30
    @State private var upper = 30
    @State private var centeredDay: Int?
    @State private var expanded = false

    private var days: [LocalDay] { (lower...upper).compactMap { try? today.adding(days: $0) } }
    private var visibleDay: LocalDay { centeredDay.flatMap { try? LocalDay(key: $0) } ?? selection }
    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 8) {
                        Text(expanded ? "Calendar" : DayText.month(visibleDay)).font(.headline)
                            .accessibilityIdentifier("todayStripMonth")
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
                    }.frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Collapse calendar" : "Expand calendar")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("expandTodayCalendar")
                Spacer()
                Button("Today") {
                    expanded = false
                    selection = today
                    lower = min(lower, -30); upper = max(upper, 30)
                    centeredDay = today.key
                }.frame(minHeight: 44).accessibilityIdentifier("stripReturnToToday")
            }
            if expanded {
                ExpandableMonthCalendar(today: today, activityIndex: activityIndex, forecast: forecast, selection: $selection)
            } else {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 6) {
                    ForEach(days) { day in
                        let markers = activityIndex.markers(on: day)
                        let period = forecast.period(on: day)
                        let ovulation = forecast.ovulation(on: day)
                        let predicted = period != nil || forecast.bleeding(on: day) != nil
                        let outlinedEstimate = predicted || ovulation != nil
                        Button { selection = day; centeredDay = day.key } label: {
                            VStack(spacing: 4) {
                                Text(day.formattingDate, format: .dateTime.weekday(.narrow))
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(day.day.formatted()).font(.system(.headline, design: .rounded, weight: day == selection ? .semibold : .regular))
                                    .monospacedDigit()
                                    .frame(width: max(36, dayWidth - 12), height: max(36, dayWidth - 12))
                                    .foregroundStyle(day == selection ? (outlinedEstimate ? palette.accent : palette.background) : day == today ? palette.accent : .primary)
                                    .background(day == selection ? (outlinedEstimate ? palette.sage : palette.accent) : .clear, in: Circle())
                                    .overlay {
                                        if predicted {
                                            Circle().strokeBorder(palette.recorded, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                                                .padding(-3)
                                        }
                                        if ovulation != nil {
                                            Circle().strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 4]))
                                                .padding(predicted ? 1 : -3)
                                        }
                                    }
                                DayActivityIcons(markers: markers)
                                ForecastDayIcons(forecast: forecast, day: day)
                            }
                            .padding(.vertical, 4)
                            .frame(width: max(44, dayWidth), alignment: .top)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).id(day.key)
                        .accessibilityLabel("\(DayText.full(day)). \(day == today ? "Today. " : "")\(markers.isEmpty ? "No recorded activities" : markers.map(\.title).joined(separator: ", "))\(period != nil ? ". Estimated start window" : "")\(ovulation != nil ? ". Possible ovulation, calendar estimate only" : "")\(ovulation?.ovulationWarnings.isEmpty == false ? ". Timing may not apply with your cycle context" : "")\(period?.isLaterProjection == true || ovulation?.isLaterProjection == true ? ". Future-cycle projection assumes unrecorded periods" : "")")
                        .accessibilityValue(forecast.additionalDayDescription(day))
                        .accessibilityAddTraits(day == selection ? .isSelected : [])
                        .accessibilityIdentifier("todayDate_\(day.key)")
                    }
                }.scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $centeredDay, anchor: .center)
            .accessibilityIdentifier("todayDateStrip")
            .onAppear { centeredDay = selection.key }
            .onChange(of: centeredDay) { _, key in
                guard let key, let day = try? LocalDay(key: key) else { return }
                let offset = today.days(until: day)
                if offset < lower + 7 { lower -= 30 }
                if offset > upper - 7 { upper += 30 }
            }
            }
            Divider()
        }
            .onChange(of: selection) { _, day in
                let offset = today.days(until: day)
                if offset < lower || offset > upper {
                    lower = offset - 30; upper = offset + 30
                }
                centeredDay = day.key
            }
            .onChange(of: today) { old, new in
                if selection == old { selection = new; centeredDay = new.key }
            }
        .environment(\.calendar, LocalDay.calendar)
        .environment(\.timeZone, LocalDay.calendar.timeZone)
    }
}

struct TodayCalendarLegend: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ViewThatFits(in: .horizontal) {
            legendItems
            ScrollView(.horizontal) {
                legendItems
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todayCalendarLegend")
    }

    private var legendItems: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        return HStack(spacing: 10) {
            Label("Period", systemImage: "drop.fill").foregroundStyle(palette.recorded)
                .accessibilityLabel("Recorded period")
            Label("Estimate", systemImage: "circle.dashed").foregroundStyle(palette.recorded)
                .accessibilityLabel("Possible starts and expected bleeding, shown with dashed dates")
            Label("Ovulation", systemImage: "circle.dotted").foregroundStyle(palette.accent)
                .accessibilityLabel("One possible ovulation date per cycle, shown with dots; uncertain, not confirmed")
            Label("Bleeding", systemImage: "drop").foregroundStyle(palette.recorded)
                .accessibilityLabel("Expected bleeding, not recorded")
            Label("Fertile", systemImage: "leaf").foregroundStyle(palette.accent)
                .accessibilityLabel("Estimated fertile window; dates outside it are not safe days")
            Label("Symptoms", systemImage: "waveform.path.ecg")
            Label("Sex", systemImage: "heart.fill").foregroundStyle(palette.sexualActivity)
                .accessibilityLabel("Sexual activity")
        }
        .font(.caption2)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
