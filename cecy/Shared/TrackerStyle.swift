import SwiftUI

struct TrackerPalette {
    let scheme: ColorScheme
    var background: Color {
        scheme == .dark ? Color(red: 0.09, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.93)
    }
    var surface: Color {
        scheme == .dark ? Color(red: 0.14, green: 0.17, blue: 0.15) : Color(red: 1, green: 0.99, blue: 0.97)
    }
    var accent: Color {
        scheme == .dark ? Color(red: 0.69, green: 0.82, blue: 0.71) : Color(red: 0.25, green: 0.38, blue: 0.29)
    }
    var sage: Color {
        scheme == .dark ? Color(red: 0.19, green: 0.27, blue: 0.22) : Color(red: 0.87, green: 0.91, blue: 0.84)
    }
}

struct TrackerPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.largeTitle.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
                }
                content
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(TrackerPalette(scheme: colorScheme).background.ignoresSafeArea())
    }
}

struct TrackerCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var highlighted = false
    var padding: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(highlighted ? palette.sage : palette.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct InlineError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .foregroundStyle(.primary)
            .font(.callout)
            .accessibilityIdentifier("validationError")
    }
}

/// Format UTC anchors in UTC, never as local instants that can change their civil day.
enum DayText {
    static func full(_ day: LocalDay) -> String { format(day, template: "yMMMMd") }
    static func short(_ day: LocalDay) -> String { format(day, template: "yMMMd") }
    static func month(_ day: LocalDay) -> String { format(day, template: "yMMMM") }
    static func range(_ first: LocalDay, _ last: LocalDay) -> String { "\(short(first)) – \(short(last))" }

    private static func format(_ day: LocalDay, template: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = LocalDay.calendar
        formatter.timeZone = LocalDay.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: day.formattingDate)
    }
}

struct PrivacyDetails: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stored on this device", systemImage: "hand.raised")
                .font(.headline)
            Text("Your health data stays on your device. Apple sign-in identifies you without uploading your health records. No cloud sync, AI, analytics or Apple Health connection.")
            Text("Records and preferences are excluded from future system backups. Earlier backups and shared exports are not erased by local deletion. Apple sign-in cannot restore your records on another device yet. App locking, export and discreet reminders are in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
