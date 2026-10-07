import SwiftUI

struct TrackerCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    let session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    let onLog: (LocalDay) -> Void
    @State private var selection: LocalDay
    @State private var showDatePicker = false
    @State private var showHistory = false

    init(session: TrackerSession, today: LocalDay, overview: CycleOverview, onLog: @escaping (LocalDay) -> Void) {
        self.session = session
        self.today = today
        self.overview = overview
        self.onLog = onLog
        _selection = State(initialValue: today)
    }

    private var palette: TrackerPalette { TrackerPalette(scheme: colorScheme) }
    private var days: [LocalDay] {
        (0..<selection.daysInMonth).compactMap { try? selection.monthStart.adding(days: $0) }
    }
    private var calendar: Calendar {
        var value = LocalDay.calendar
        value.locale = locale
        return value
    }
    private var leadingCells: Int { (selection.monthStart.weekday - calendar.firstWeekday + 7) % 7 }
    private var weekdays: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[($0 + calendar.firstWeekday - 1) % 7] }
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = min(geometry.size.width - 32, TrackerLayout.readableWidth)
            let listLayout = contentWidth - 16 < 320 || dynamicTypeSize.isAccessibilitySize
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        TrackerPageHeading(title: "Calendar", subtitle: "Your records and estimates, clearly apart.")
                        if let confirmation = session.confirmation {
                            TrackerCard {
                                Label(confirmation, systemImage: "checkmark.circle")
                                Button("Dismiss confirmation") { session.confirmation = nil }
                            }
                            .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
                        }
                        TrackerCard(padding: 8) {
                            monthControls
                            if listLayout {
                                ForEach(days) { day in
                                    VStack(alignment: .leading, spacing: 12) {
                                        dayButton(day, asList: true)
                                        if day == selection {
                                            // Keep actions and records together at large text sizes.
                                            loggingActions
                                            RecordedDayCard(session: session, day: selection, today: today)
                                                .accessibilityIdentifier("calendarRecordedDayCard")
                                        }
                                    }
                                    .id(day.key)
                                }
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 2, alignment: .top), count: 7), spacing: 8) {
                                    // Sibling ForEach ranges share the grid's identity space.
                                    ForEach(0..<7, id: \.self) { index in
                                        Text(weekdays[index]).font(.caption).accessibilityHidden(true)
                                            .id("weekday-\(index)")
                                    }
                                    ForEach(0..<leadingCells, id: \.self) { index in
                                        Color.clear.frame(height: 44).accessibilityHidden(true)
                                            .id("placeholder-\(index)")
                                    }
                                    ForEach(days) { day in dayButton(day, asList: false) }
                                }
                            }
                            if !listLayout { loggingActions }
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Recorded start or confirmed bleeding day", systemImage: "drop.fill")
                                    .foregroundStyle(palette.recorded)
                                Label("Possible starts / expected bleeding · Dashed border", systemImage: "circle.dashed")
                                    .foregroundStyle(palette.recorded)
                                Label("Possible ovulation · Dotted border", systemImage: "circle.dotted")
                                    .foregroundStyle(palette.accent)
                                Label("Expected bleeding · Not recorded", systemImage: "drop")
                                    .foregroundStyle(palette.recorded)
                                Label("Estimated fertile window", systemImage: "leaf")
                                    .foregroundStyle(palette.accent)
                                Label { Text("Sexual activity") } icon: {
                                    Image(systemName: "heart.fill").foregroundStyle(palette.sexualActivity)
                                }
                                Label("Symptoms · One marker per day", systemImage: "waveform.path.ecg")
                                DailyBleedingLegend()
                            }
                            .font(.footnote).foregroundStyle(.secondary).padding(8)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("calendarLegend")
                        }
                        TrackerCard { UpcomingCycleForecastView(forecast: session.cycleForecast, today: today) }
                        if !listLayout {
                            RecordedDayCard(session: session, day: selection, today: today)
                                .accessibilityIdentifier("calendarRecordedDayCard")
                        }
                        TrackerCard {
                            NavigationLink { SexualActivityHistoryView(session: session) } label: {
                                TrackerNavigationLabel(title: "Sexual activity history", symbol: "heart")
                            }.accessibilityIdentifier("sexualActivityHistory")
                            Divider()
                            Button { showHistory = true } label: {
                                TrackerNavigationLabel(title: "Add previous periods", symbol: "calendar.badge.plus")
                            }.accessibilityIdentifier("addPreviousPeriods")
                        }.buttonStyle(.plain)
                    }
                    .frame(width: max(0, contentWidth), alignment: .leading)
                    .padding(.vertical, TrackerLayout.pageInset)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: selection) { _, value in
                    if listLayout { proxy.scrollTo(value.key, anchor: .top) }
                }
            }
            .background(palette.background.ignoresSafeArea())
        }
        .predictionUpdateProgress()
        .sheet(isPresented: $showDatePicker) {
            CalendarDateSheet(day: selection) { selection = $0 }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HistoryEntryView(session: session, today: session.today ?? today, isOnboarding: false) }
        }
    }

    private var monthControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DayText.month(selection)).font(TrackerTypography.sectionTitle)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("calendarMonth")
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.backward").frame(width: 44, height: 44) }
                    .accessibilityLabel("Previous month").accessibilityIdentifier("previousMonth")
                    .disabled((try? selection.adding(months: -1)) == nil)
                Spacer()
                Button("Today") { selection = today }.frame(minWidth: 44, minHeight: 44)
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.forward").frame(width: 44, height: 44) }
                    .accessibilityLabel("Next month").accessibilityIdentifier("nextMonth")
                    .disabled((try? selection.adding(months: 1)) == nil)
            }
            Button("Go to date") { showDatePicker = true }
                .frame(minHeight: 44).accessibilityIdentifier("goToDate")
        }
        .padding(8)
    }

    private func moveMonth(_ offset: Int) {
        if let day = try? selection.adding(months: offset) { selection = day }
    }

    private func record(on day: LocalDay) -> Period? { session.snapshot.periods.first { $0.contains(day) } }

    private func observationCount(on day: LocalDay) -> Int {
        session.snapshot.symptoms.filter { $0.day == day }.count
            + session.snapshot.sexualActivities.filter { $0.day == day }.count
            + (session.activityIndex.markers(on: day).contains { $0.id == "dailyBleeding" } ? 1 : 0)
    }

    private func status(_ day: LocalDay) -> String {
        var parts: [String] = []
        if day == today { parts.append("Today") }
        if let period = record(on: day) {
            parts.append(period.start == day ? "Recorded period start" : "Confirmed bleeding day")
        } else { parts.append("No recorded period") }
        let count = observationCount(on: day)
        if count > 0 { parts.append("\(count) recorded observations") }
        parts += session.activityIndex.markers(on: day).filter { $0.id != "period" }.map(\.title)
        let period = session.cycleForecast.period(on: day)
        let ovulation = session.cycleForecast.ovulation(on: day)
        if period != nil { parts.append("Possible period start; estimate") }
        if ovulation != nil { parts.append("Possible ovulation; calendar estimate, not confirmed") }
        if ovulation?.ovulationWarnings.isEmpty == false { parts.append("Timing may not apply with your cycle context; review date details") }
        if period?.isLaterProjection == true || ovulation?.isLaterProjection == true {
            parts.append("Future-cycle projection assumes unrecorded periods")
        }
        return parts.joined(separator: ". ") + session.cycleForecast.additionalDayDescription(day)
    }

    private func dayButton(_ day: LocalDay, asList: Bool) -> some View {
        let recorded = record(on: day) != nil
        let predicted = session.cycleForecast.period(on: day) != nil || session.cycleForecast.bleeding(on: day) != nil
        let ovulation = session.cycleForecast.ovulation(on: day) != nil
        let shape = RoundedRectangle(cornerRadius: asList ? 12 : 22, style: .continuous)
        return Button { selection = day } label: {
            VStack(alignment: asList ? .leading : .center, spacing: 4) {
                VStack(alignment: asList ? .leading : .center, spacing: 4) {
                    HStack(spacing: 2) {
                        Text(asList ? DayText.full(day) : day.day.formatted())
                            .fontWeight(selection == day ? .bold : .regular)
                            .underline(selection == day)
                        if day == today { Image(systemName: "circle.fill").font(.system(size: 4)).accessibilityHidden(true) }
                    }
                    if asList {
                        Text(status(day)).font(.footnote)
                    }
                }
                .frame(maxWidth: asList ? .infinity : 44, minHeight: 44, alignment: asList ? .leading : .center)
                .padding(.horizontal, asList ? 8 : 0)
                .background(recorded ? palette.recordedSurface : (selection == day ? palette.sage : .clear), in: shape)
                .overlay {
                    if predicted {
                        shape
                            .strokeBorder(palette.recorded, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .padding(CalendarOutlineMetrics.outerInset)
                    }
                    if ovulation {
                        shape
                            .strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 4]))
                            .padding(predicted ? CalendarOutlineMetrics.nestedInset : CalendarOutlineMetrics.outerInset)
                    } else if !predicted, selection == day {
                        shape
                            .strokeBorder(palette.accent, lineWidth: 1.5)
                            .padding(CalendarOutlineMetrics.outerInset)
                    }
                }
                // Activity markers sit outside the date badge, as on Today.
                if !asList {
                    DayActivityIcons(markers: DayActivityMarker.calendar(
                        recorded: session.activityIndex.markers(on: day),
                        forecast: session.cycleForecast, day: day))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: asList ? .leading : .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DayText.full(day)). \(status(day))")
        .accessibilityAddTraits(day == selection ? [.isSelected] : [])
        .accessibilityIdentifier("calendarDay_\(day.key)")
    }

    private var loggingActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            TrackerCompactLogActions {
                loggingButtons
            }
            .disabled(selection > today)
            DailyBleedingLogButton(session: session, day: selection)
            Text("Log for \(DayText.full(selection))")
                .font(.caption).foregroundStyle(.secondary)
            if selection > today {
                Text("Future dates can be viewed, but not recorded as observations.").font(.footnote)
            }
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendarLoggingActions")
    }

    @ViewBuilder
    private var loggingButtons: some View {
        Button { onLog(selection) } label: {
            Label("Log period", systemImage: "drop")
        }
        .buttonStyle(TrackerCompactLogButtonStyle(prominent: true))
        .accessibilityLabel("Record a period")
        .accessibilityIdentifier("calendarLogPeriod")
        .accessibilityHint(record(on: selection) == nil ? "Record actual bleeding days." : "Edit this period or its confirmed bleeding dates.")
        SymptomLogButton(session: session, day: selection, title: "Symptoms", compact: true)
        SexualActivityLogButton(session: session, day: selection, compact: true)
    }
}

private struct CalendarDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    let onSelect: (LocalDay) -> Void

    init(day: LocalDay, onSelect: @escaping (LocalDay) -> Void) {
        _date = State(initialValue: day.formattingDate)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            Form { DatePicker("Go to date", selection: $date, displayedComponents: .date) }
                .trackerFormStyle()
                .environment(\.calendar, LocalDay.calendar)
                .environment(\.timeZone, LocalDay.calendar.timeZone)
                .navigationTitle("Choose a date")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Go") {
                            if let day = try? LocalDay(date: date, timeZone: LocalDay.calendar.timeZone) {
                                onSelect(day)
                                dismiss()
                            }
                        }
                    }
                }
        }
    }
}
