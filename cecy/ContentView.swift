//
//  ContentView.swift
//  cecy
//
//  Created by Furaha Damien on 9/29/26.
//

import SwiftUI

#if DEBUG
// Original visual reference only. The application launches TrackerRootView.
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: CanvasTab = .today
    @State private var loggingPreview: LoggingPreview?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayCanvas { loggingPreview = $0 }
            }
            .tabItem { Label("Today", systemImage: "sun.max") }
            .tag(CanvasTab.today)

            NavigationStack {
                CalendarCanvas()
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(CanvasTab.calendar)

            NavigationStack {
                InsightsCanvas()
            }
            .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }
            .tag(CanvasTab.insights)

            NavigationStack {
                SettingsCanvas()
            }
            .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            .tag(CanvasTab.settings)
        }
        .tint(CanvasPalette(colorScheme).accent)
        .sheet(item: $loggingPreview) { preview in
            LoggingPreviewSheet(preview: preview)
        }
    }
}

// Visual fixtures only. These values are not predictions or persisted records.
private enum CanvasTab: Hashable {
    case today, calendar, insights, settings
}

private enum LoggingPreview: String, Identifiable {
    case period, symptoms

    var id: String { rawValue }
    var title: String { self == .period ? "Log a period" : "Log symptoms" }
    var icon: String { self == .period ? "drop" : "plus.circle" }
}

private struct CanvasPalette {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) {
        self.scheme = scheme
    }

    var background: Color {
        scheme == .dark
            ? Color(red: 0.09, green: 0.11, blue: 0.10)
            : Color(red: 0.97, green: 0.96, blue: 0.93)
    }

    var surface: Color {
        scheme == .dark
            ? Color(red: 0.14, green: 0.17, blue: 0.15)
            : Color(red: 1.0, green: 0.99, blue: 0.97)
    }

    var accent: Color {
        scheme == .dark
            ? Color(red: 0.69, green: 0.82, blue: 0.71)
            : Color(red: 0.25, green: 0.38, blue: 0.29)
    }

    var sage: Color {
        scheme == .dark
            ? Color(red: 0.19, green: 0.27, blue: 0.22)
            : Color(red: 0.87, green: 0.91, blue: 0.84)
    }
}

private struct CanvasPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Label("Design preview · Sample data only", systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                content

                Text("This canvas does not save health data or calculate predictions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(CanvasPalette(colorScheme).background.ignoresSafeArea())
    }
}

private struct CanvasCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        let palette = CanvasPalette(colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(highlighted ? palette.sage : palette.surface,
                    in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct TodayCanvas: View {
    let onLog: (LoggingPreview) -> Void

    var body: some View {
        CanvasPage(title: "Your cycle, at a glance",
                   subtitle: "A little understanding, day by day.") {
            Text("TUESDAY, SEPTEMBER 29, 2026")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)

            CanvasCard(highlighted: true) {
                Label("Your current cycle", systemImage: "leaf")
                    .font(.subheadline.weight(.medium))
                Text("Day 28")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                Text("Counting from your recorded start on September 2.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Divider()
                Text("Next period · Estimated window")
                    .font(.subheadline)
                Text("Sep 30 – Oct 4")
                    .font(.title2.weight(.semibold))
                Label("Moderate confidence · Example", systemImage: "sparkle")
                    .font(.caption.weight(.medium))
                Text("A range, not a deadline. Predictions will adapt as you record more cycles.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                sectionHeading("Make a quick note")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { loggingButtons }
                    VStack(spacing: 12) { loggingButtons }
                }
            }

            CanvasCard {
                Label("A little perspective", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.medium))
                Text("Every cycle adds context.")
                    .font(.title3.weight(.semibold))
                Text("Over time, this space will highlight meaningful patterns in your own records—not tell you what your cycle should look like.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var loggingButtons: some View {
        Group {
            Button { onLog(.period) } label: {
                Label("Log period", systemImage: "drop")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            Button { onLog(.symptoms) } label: {
                Label("Log symptoms", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

private struct CalendarCanvas: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDay = 29
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        CanvasPage(title: "Calendar", subtitle: "Your records and estimates, clearly apart.") {
            CanvasCard {
                Text("September 2026")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                    ForEach(weekdays.indices, id: \.self) { index in
                        Text(weekdays[index])
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                            .id("weekday-\(index)")
                    }
                    // September 1, 2026 is a Tuesday in this fixed visual fixture.
                    ForEach(0..<2, id: \.self) { index in
                        Color.clear.frame(height: 44).accessibilityHidden(true)
                            .id("placeholder-\(index)")
                    }
                    ForEach(1...30, id: \.self) { day in
                        dayButton(day)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Recorded period", systemImage: "drop.fill")
                    Label("Predicted window · Dashed outline", systemImage: "circle.dashed")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("The example predicted window continues through October 4.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            CanvasCard {
                Text("September \(selectedDay)")
                    .font(.headline)
                Label(dayDescription(selectedDay), systemImage: dayIcon(selectedDay))
                Text("Select a day above to explore the sample calendar. Editing and month navigation will follow in the tracking implementation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dayButton(_ day: Int) -> some View {
        let recorded = (2...6).contains(day)
        let predicted = day == 30
        let palette = CanvasPalette(colorScheme)

        return Button { selectedDay = day } label: {
            VStack(spacing: 3) {
                Text("\(day)")
                    .font(.callout.weight(day == selectedDay ? .bold : .regular))
                Image(systemName: recorded ? "drop.fill" : "circle.fill")
                    .font(.system(size: 7))
                    .opacity(recorded || day == 29 ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(recorded ? palette.sage : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(palette.accent,
                                  style: StrokeStyle(lineWidth: day == selectedDay || predicted ? 2 : 0,
                                                     dash: predicted ? [3, 3] : []))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("September \(day), 2026. \(dayDescription(day))")
        .accessibilityAddTraits(day == selectedDay ? [.isSelected] : [])
    }

    private func dayDescription(_ day: Int) -> String {
        if (2...6).contains(day) { return "Recorded period · Sample" }
        if day == 30 { return "Predicted period window · Not a confirmed record" }
        if day == 29 { return "Today in this preview · No entries" }
        return "No sample entries"
    }

    private func dayIcon(_ day: Int) -> String {
        if (2...6).contains(day) { return "drop.fill" }
        return day == 30 ? "circle.dashed" : "calendar"
    }
}

private struct InsightsCanvas: View {
    var body: some View {
        CanvasPage(title: "Insights", subtitle: "Understand your patterns, at your pace.") {
            CanvasCard(highlighted: true) {
                Label("The bigger picture", systemImage: "chart.xyaxis.line")
                    .font(.subheadline.weight(.medium))
                Text("Your history tells a story.")
                    .font(.title2.weight(.semibold))
                Text("This is where your cycle lengths, changes, and recurring observations will come together.")
                    .foregroundStyle(.secondary)
            }

            CanvasCard {
                sectionHeading("An example cycle summary")
                summaryRow("Average cycle", value: "29 days")
                Divider()
                summaryRow("Recorded range", value: "28–32 days")
                Divider()
                summaryRow("Average period", value: "5 days")
                Text("Illustrative values only—not calculated from your data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            CanvasCard {
                Label("Patterns take time", systemImage: "leaf")
                    .font(.headline)
                Text("Future insights will show the records behind each observation. Missing logs won’t be treated as symptom-free days.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 16)
                Text(value).fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.secondary)
                Text(value).fontWeight(.semibold)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsCanvas: View {
    var body: some View {
        CanvasPage(title: "Settings", subtitle: "Your information. Your choices.") {
            CanvasCard(highlighted: true) {
                Label("Private by design", systemImage: "hand.raised")
                    .font(.headline)
                Text("The core tracker is being designed to work on your device, without an account.")
                Text("This canvas contains sample content only. Storage and privacy controls are not implemented yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            CanvasCard {
                sectionHeading("Planned controls")
                plannedRow("Reminders", icon: "bell", detail: "Optional, discreet notifications")
                Divider()
                plannedRow("App lock", icon: "lock", detail: "Optional biometric protection")
                Divider()
                plannedRow("Export your data", icon: "square.and.arrow.up", detail: "A copy of your own records")
                Divider()
                plannedRow("Delete all data", icon: "trash", detail: "Control over what you keep")
            }

            Text("Apple Health, subscriptions, AI, and cloud sharing will be considered in later phases. None are connected in this preview.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func plannedRow(_ title: String, icon: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LoggingPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: LoggingPreview

    var body: some View {
        NavigationStack {
            CanvasPage(title: preview.title, subtitle: "A place for a quick check-in.") {
                CanvasCard(highlighted: true) {
                    Label("Logging preview", systemImage: preview.icon)
                        .font(.headline)
                    Text(preview == .period
                         ? "Period logging will let you record a start date, add an end date, and correct previous entries."
                         : "Symptom logging will let you quickly choose what you’re feeling, with optional severity and notes.")
                    Text("Nothing is recorded here yet. This sheet demonstrates the logging entry point only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private func sectionHeading(_ title: String) -> some View {
    Text(title)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
}

#Preview("Cecy · Light") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Cecy · Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Cecy · Large Text") {
    ContentView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
