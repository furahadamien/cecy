import SwiftUI

struct CycleLengthWheel: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var days: Int
    let identifier: String
    @ScaledMetric(relativeTo: .body) private var height = 210.0

    var body: some View {
        VStack(spacing: 4) {
            Text(days == 1 ? "1 day" : "\(days) days").font(TrackerTypography.metric).monospacedDigit()
                .accessibilityHidden(true)
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
