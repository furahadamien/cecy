import SwiftUI

struct CycleLengthWheel: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var days: Int
    let identifier: String
    @ScaledMetric(relativeTo: .body) private var height = 210.0
    @Environment(\.onboardingTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            Text(days == 1 ? "1 day" : "\(days) days").font(TrackerTypography.metric).monospacedDigit()
                .foregroundStyle(theme?.tint ?? .primary)
                .contentTransition(reduceMotion ? .identity : .numericText(value: Double(days)))
                .animation(reduceMotion ? nil : .snappy, value: days)
                .accessibilityHidden(true)
            if let theme { LengthVisual(days: days, range: range, theme: theme) }
            Picker(title, selection: $days) {
                ForEach(range, id: \.self) { day in Text(day == 1 ? "1 day" : "\(day) days").tag(day) }
            }
            .pickerStyle(.wheel).labelsHidden()
            .frame(height: min(height, 320)).clipped()
            .accessibilityLabel(title)
            .accessibilityHint("Swipe up or down to choose your usual number of days.")
            .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 8)
    }
}

/// A decorative picture of the chosen length: one drop-shaped capsule per bleeding day for short ranges,
/// or one segment per week for cycle lengths. VoiceOver already hears the wheel's value.
private struct LengthVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let days: Int
    let range: ClosedRange<Int>
    let theme: OnboardingTheme

    var body: some View {
        let perDay = range.upperBound <= 31
        let units = perDay ? min(days, 15) : min(Int((Double(days) / 7).rounded(.up)), 18)
        HStack(spacing: perDay ? 6 : 4) {
            ForEach(0..<units, id: \.self) { index in
                let partial = !perDay && index == units - 1 && days % 7 != 0
                Capsule()
                    .fill(theme.tint.opacity(perDay ? 0.85 : (partial ? 0.35 : 0.75)))
                    .frame(width: perDay ? 10 : nil, height: perDay ? 18 : 10)
                    .frame(maxWidth: perDay ? nil : 28)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(theme.surface, in: Capsule())
        .animation(reduceMotion ? nil : .snappy, value: days)
        .accessibilityHidden(true)
    }
}

struct OnboardingCycleLengthField: View {
    let title: String
    let range: ClosedRange<Int>
    let suggestedDays: Int
    let identifier: String
    @Binding var value: Int?
    @Binding var isUnknown: Bool

    var body: some View {
        SelectionFlowLayout {
            SelectionChip(title: "Choose length", selected: value != nil) {
                isUnknown = false
                if value == nil { value = suggestedDays }
            }
            .accessibilityIdentifier(identifier + "Known")
            SelectionChip(title: "Not sure", selected: isUnknown && value == nil) {
                value = nil
                isUnknown = true
            }
            .accessibilityIdentifier(identifier + "Unknown")
        }
        if value != nil {
            CycleLengthWheel(title: title, range: range,
                             days: Binding(get: { value ?? suggestedDays }, set: { value = $0 }),
                             identifier: identifier)
        }
    }
}

/// Existing profiles remain unanswered until Add is tapped; merely opening Settings never adopts defaults.
struct CyclePreferenceField: View {
    let title: String
    let range: ClosedRange<Int>
    let defaultValue: Int
    let identifier: String
    @Binding var value: Int?
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(value.map { $0 == 1 ? "1 day" : "\($0) days" } ?? "Not set").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(value == nil ? "Add" : "Edit") {
                    if value == nil { value = defaultValue }
                    editing = true
                }.frame(minHeight: 44).accessibilityIdentifier(identifier + "Edit")
            }
            if editing {
                CycleLengthWheel(title: title, range: range, days: Binding(get: { value ?? defaultValue }, set: { value = $0 }), identifier: identifier)
                HStack {
                    Button("Clear") { value = nil; editing = false }.frame(minHeight: 44)
                    Spacer()
                    Button("Done") { editing = false }.frame(minHeight: 44)
                }
            }
        }
        .buttonStyle(.borderless)
    }
}
