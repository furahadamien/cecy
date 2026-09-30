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
    @State private var showExplanation = false

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
            let contentWidth = min(geometry.size.width - 32, 640)
            let listLayout = contentWidth - 16 < 320 || dynamicTypeSize.isAccessibilitySize
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Calendar").font(.largeTitle.weight(.semibold)).accessibilityAddTraits(.isHeader)
                        Text("Your records and estimates, clearly apart.").foregroundStyle(.secondary)
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
                                        if day == selection { selectedDetails.padding(8) }
                                    }
                                    .id(day.key)
                                }
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 2), count: 7), spacing: 8) {
                                    ForEach(0..<7, id: \.self) { index in
                                        Text(weekdays[index]).font(.caption).accessibilityHidden(true)
                                    }
                                    ForEach(0..<leadingCells, id: \.self) { _ in
                                        Color.clear.frame(height: 44).accessibilityHidden(true)
                                    }
                                    ForEach(days) { day in dayButton(day, asList: false) }
                                }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Recorded start or confirmed bleeding day", systemImage: "drop.fill")
                                Label("Estimated start window · Dashed border", systemImage: "circle.dashed")
                                Text("An underlined date is selected. Estimates are not recorded bleeding days.")
                            }
                            .font(.footnote).padding(8)
                        }
                        if !listLayout { TrackerCard { selectedDetails } }
                    }
                    .frame(width: max(0, contentWidth), alignment: .leading)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: selection) { _, value in
                    if listLayout { proxy.scrollTo(value.key, anchor: .top) }
                }
            }
            .background(palette.background.ignoresSafeArea())
        }
        .sheet(isPresented: $showDatePicker) {
            CalendarDateSheet(day: selection) { selection = $0 }
        }
        .sheet(isPresented: $showExplanation) {
            if let estimate = overview.estimate { PredictionExplanation(estimate: estimate) }
        }
    }

    private var monthControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DayText.month(selection)).font(.title2.weight(.semibold))
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

    private func status(_ day: LocalDay) -> String {
        var parts: [String] = []
        if day == today { parts.append("Today") }
        if let period = record(on: day) {
            parts.append(period.start == day ? "Recorded period start" : "Confirmed bleeding day")
        } else { parts.append("No recorded entry") }
        if overview.estimate?.contains(day) == true { parts.append("Possible next period start; estimate") }
        return parts.joined(separator: ". ")
    }

    private func dayButton(_ day: LocalDay, asList: Bool) -> some View {
        let recorded = record(on: day) != nil
        let predicted = overview.estimate?.contains(day) == true
        return Button { selection = day } label: {
            VStack(alignment: asList ? .leading : .center, spacing: 4) {
                Text(asList ? DayText.full(day) : day.day.formatted())
                    .fontWeight(selection == day ? .bold : .regular)
                    .underline(selection == day)
                if asList {
                    Text(status(day)).font(.footnote)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill").opacity(recorded ? 1 : 0)
                        Image(systemName: "circle.fill").opacity(day == today ? 1 : 0)
                    }
                    .font(.system(size: 8)).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: asList ? .leading : .center)
            .padding(.horizontal, asList ? 8 : 0)
            .background(recorded ? palette.sage : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if predicted {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(palette.accent, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DayText.full(day)). \(status(day))")
        .accessibilityAddTraits(day == selection ? [.isSelected] : [])
        .accessibilityIdentifier("calendarDay_\(day.key)")
    }

    private var selectedDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(DayText.full(selection)).font(.headline).accessibilityAddTraits(.isHeader)
            if selection == today { Text("Today").font(.subheadline) }
            if let period = record(on: selection) {
                Label(period.start == selection ? "Recorded period start" : "Confirmed bleeding day", systemImage: "drop.fill")
                Text("Started \(DayText.full(period.start))")
                if let end = period.end, let duration = period.duration {
                    Text("Ended \(DayText.full(end)) · \(duration) days, inclusive")
                } else {
                    Text("End not recorded. No later bleeding days are assumed.")
                }
                PeriodExtraDetails(period: period)
                PeriodRecordActions(session: session, period: period).id(period.id)
            } else {
                Text("No period recorded for this day.")
            }
            if let estimate = overview.estimate, estimate.contains(selection) {
                Label("Possible start date · Estimate", systemImage: "circle.dashed")
                Text(DayText.range(estimate.earliest, estimate.latest))
                if today > estimate.latest { Text("Estimated window passed. No new start has been recorded.") }
                Button("How this estimate works") { showExplanation = true }.frame(minHeight: 44)
            }
            if selection > today {
                Text("Future dates can be viewed, but not recorded as observations.").font(.footnote)
            } else if record(on: selection) == nil {
                Button { onLog(selection) } label: {
                    Label("Record a period", systemImage: "plus").frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("calendarLogPeriod")
            }
        }
        .accessibilityIdentifier("selectedDayDetails")
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
