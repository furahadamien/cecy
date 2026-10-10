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
                    VStack(alignment: .leading, spacing: 12) {
                        calendarToolbar
                        if let confirmation = session.confirmation {
                            TrackerCard {
                                Label(confirmation, systemImage: "checkmark.circle")
                                Button("Dismiss confirmation") { session.confirmation = nil }
                            }
                            .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
                        }
                        TrackerCard(padding: 8, spacing: 6) {
                            monthControls
                            if listLayout {
                                ForEach(days) { day in
                                    VStack(alignment: .leading, spacing: 12) {
                                        dayButton(day, asList: true)
                                        if day == selection {
                                            // Keep logging next to the selected date at large text sizes.
                                            loggingActions
                                        }
                                    }
                                    .id(day.key)
                                }
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 2, alignment: .top), count: 7), spacing: 2) {
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
                            Divider().padding(.horizontal, 8)
                            CalendarSymbolLegend().padding(.horizontal, 8)
                        }
                        if !listLayout {
                            loggingActions
                        }
                        TrackerCard(padding: 16) {
                            UpcomingCycleForecastView(forecast: session.cycleForecast, today: today, calendarStyle: true)
                        }
                        RecordedDayCard(session: session, day: selection, today: today)
                            .environment(\.calendarRecordStyle, true)
                            .accessibilityIdentifier("calendarRecordedDayCard")
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
                    .padding(.top, 6)
                    .padding(.bottom, TrackerLayout.pageInset)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: selection) { _, value in
                    if listLayout { proxy.scrollTo(value.key, anchor: .top) }
                }
            }
            .background((colorScheme == .dark ? palette.background : Color(red: 0.965, green: 0.980, blue: 0.963)).ignoresSafeArea())
        }
        .predictionUpdateProgress()
        .sheet(isPresented: $showDatePicker) {
            CalendarDateSheet(day: selection) { selection = $0 }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HistoryEntryView(session: session, today: session.today ?? today, isOnboarding: false) }
        }
    }

    private var calendarToolbar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button { showDatePicker = true } label: {
                    Label("Go to date", systemImage: "calendar.badge.clock")
                        .frame(minHeight: 44).contentShape(Rectangle())
                }.accessibilityIdentifier("goToDate")
                Spacer(minLength: 8)
                Button { selection = today } label: {
                    Label("Today", systemImage: "calendar")
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(palette.surface, in: Capsule()).contentShape(Capsule())
                }.accessibilityIdentifier("calendarReturnToToday")
            }
            .buttonStyle(.plain).font(.subheadline.weight(.semibold)).foregroundStyle(palette.accent)
            Text("Your records and estimates, clearly apart.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var monthControls: some View {
        HStack(spacing: 4) {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.backward").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month").accessibilityIdentifier("previousMonth")
            .disabled((try? selection.adding(months: -1)) == nil)
            Text(DayText.month(selection)).font(.system(.title2, design: .serif, weight: .semibold))
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("calendarMonth")
            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.forward").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel("Next month").accessibilityIdentifier("nextMonth")
            .disabled((try? selection.adding(months: 1)) == nil)
        }
        .buttonStyle(.plain).foregroundStyle(palette.accent)
    }

    private func moveMonth(_ offset: Int) {
        if let day = try? selection.adding(months: offset) { selection = day }
    }

    private func record(on day: LocalDay) -> Period? {
        PeriodLogSelection.existing(on: day, periods: session.snapshot.periods, dailyBleeding: session.snapshot.dailyBleeding)
    }

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
            VStack(alignment: asList ? .leading : .center, spacing: asList ? 4 : 2) {
                VStack(alignment: asList ? .leading : .center, spacing: 4) {
                    HStack(spacing: 2) {
                        Text(asList ? DayText.full(day) : day.day.formatted())
                            .fontWeight(selection == day ? .bold : .regular)
                            .underline(asList && selection == day)
                        if day == today { Image(systemName: "circle.fill").font(.system(size: 4)).accessibilityHidden(true) }
                    }
                    if asList {
                        Text(status(day)).font(.footnote)
                    }
                }
                .frame(maxWidth: asList ? .infinity : 36, minHeight: asList ? 44 : 36, alignment: asList ? .leading : .center)
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
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                periodLogButton
                SymptomLogButton(session: session, day: selection, title: "Symptoms", compact: true)
                SexualActivityLogButton(session: session, day: selection, compact: true)
                DailyBleedingLogButton(session: session, day: selection)
            }
            .environment(\.todayLogCards, true)
            .disabled(selection > today)
            Text("Log for \(DayText.full(selection))")
                .font(.caption).foregroundStyle(.secondary)
            if selection > today {
                Text("Future dates can be viewed, but not recorded as observations.").font(.footnote)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendarLoggingActions")
    }

    private var periodLogButton: some View {
        Button { onLog(selection) } label: {
            Label {
                Text("Log period")
            } icon: {
                Image(systemName: "drop.fill").foregroundStyle(palette.recorded)
            }
        }
        .buttonStyle(TrackerCompactLogButtonStyle(prominent: true))
        .accessibilityLabel("Log period")
        .accessibilityIdentifier("calendarLogPeriod")
        .accessibilityHint(record(on: selection) == nil ? "Record actual bleeding days." : "Edit this period or its confirmed bleeding dates.")
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
