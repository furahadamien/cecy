import SwiftUI

/// Expanded presentation of the Today selection, not a second source of calendar state.
struct ExpandableMonthCalendar: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    let today: LocalDay
    let activityIndex: DayActivityIndex
    let forecast: CycleForecast
    @Binding var selection: LocalDay
    @State private var month: LocalDay

    init(today: LocalDay, activityIndex: DayActivityIndex, forecast: CycleForecast, selection: Binding<LocalDay>) {
        self.today = today
        self.activityIndex = activityIndex
        self.forecast = forecast
        _selection = selection
        _month = State(initialValue: selection.wrappedValue.monthStart)
    }

    private var calendar: Calendar {
        var value = LocalDay.calendar
        value.locale = locale
        return value
    }
    private var days: [LocalDay] { (0..<month.daysInMonth).compactMap { try? month.adding(days: $0) } }
    private var leading: Int { (month.weekday - calendar.firstWeekday + 7) % 7 }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .disabled((try? month.adding(months: -1)) == nil)
                    .accessibilityLabel("Previous month").accessibilityIdentifier("todayPreviousMonth")
                Spacer()
                Text(DayText.month(month)).font(.subheadline.weight(.semibold))
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .disabled((try? month.adding(months: 1)) == nil)
                    .accessibilityLabel("Next month").accessibilityIdentifier("todayNextMonth")
            }
            if dynamicTypeSize.isAccessibilitySize {
                dateList
            } else {
                ViewThatFits(in: .horizontal) {
                    monthGrid.frame(minWidth: 308)
                    dateList
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todayExpandedCalendar")
        .onChange(of: selection) { _, day in month = day.monthStart }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 0), count: 7), spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                Text(calendar.veryShortStandaloneWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
                    .id("weekday-\(index)")
            }
            ForEach(0..<leading, id: \.self) { index in Color.clear.frame(height: 44).id("blank-\(index)") }
            ForEach(days) { day in dateButton(day, asList: false) }
        }
    }
    private var dateList: some View {
        VStack(spacing: 6) { ForEach(days) { day in dateButton(day, asList: true) } }
    }
    private func dateButton(_ day: LocalDay, asList: Bool) -> some View {
        let palette = TrackerPalette(scheme: colorScheme)
        let markers = activityIndex.markers(on: day)
        let period = forecast.period(on: day)
        let ovulation = forecast.ovulation(on: day)
        let predicted = period != nil || forecast.bleeding(on: day) != nil
        return Button { selection = day } label: {
            VStack(spacing: 4) {
                Text(asList ? DayText.full(day) : day.day.formatted())
                    .font(.body.weight(day == selection ? .semibold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(day == selection ? palette.accent : day == today ? palette.accent : .primary)
                    .background(day == selection ? palette.sage : .clear, in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        if predicted {
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(palette.recorded,
                                              style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                                .padding(CalendarOutlineMetrics.outerInset)
                        }
                        if ovulation != nil {
                            RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 4]))
                                .padding(predicted ? CalendarOutlineMetrics.nestedInset : CalendarOutlineMetrics.outerInset)
                        }
                    }
                DayActivityIcons(markers: DayActivityMarker.calendar(recorded: markers, forecast: forecast, day: day))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DayText.full(day)). \(day == today ? "Today. " : "")\(markers.isEmpty ? "No recorded activities" : markers.map(\.title).joined(separator: ", "))\(period != nil ? ". Estimated start window" : "")\(ovulation != nil ? ". Possible ovulation, calendar estimate only" : "")\(ovulation?.ovulationWarnings.isEmpty == false ? ". Timing may not apply with your cycle context" : "")\(period?.isLaterProjection == true || ovulation?.isLaterProjection == true ? ". Future-cycle projection assumes unrecorded periods" : "")")
        .accessibilityAddTraits(day == selection ? .isSelected : [])
        .accessibilityValue(forecast.additionalDayDescription(day))
        .accessibilityIdentifier("todayMonthDate_\(day.key)")
    }
    private func move(_ offset: Int) {
        if let next = try? month.adding(months: offset) { month = next.monthStart }
    }
}
