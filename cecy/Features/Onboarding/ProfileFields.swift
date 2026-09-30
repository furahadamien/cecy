import SwiftUI

struct ProfileBasicsFields: View {
    @Binding var profile: LocalProfile
    let today: LocalDay
    @State private var choosingBirthday = false

    var body: some View {
        TextField("Preferred name", text: $profile.preferredName)
            .textContentType(.nickname).textInputAutocapitalization(.words)
            .accessibilityIdentifier("profileName")
        Button {
            choosingBirthday = true
        } label: {
            LabeledContent("Date of birth", value: profile.birthDayKey.flatMap { try? LocalDay(key: $0) }.map(DayText.full) ?? "Choose date")
        }
        .accessibilityIdentifier("profileBirthday")
        Picker("Measurements", selection: $profile.measurementSystem) {
            ForEach(MeasurementSystem.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .accessibilityIdentifier("profileUnits")
        .sheet(isPresented: $choosingBirthday) {
            BirthdaySheet(day: profile.birthDayKey.flatMap { try? LocalDay(key: $0) }, today: today) {
                profile.birthDayKey = $0.key
            }
        }
    }
}

private struct BirthdaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    let today: LocalDay
    let onSave: (LocalDay) -> Void

    init(day: LocalDay?, today: LocalDay, onSave: @escaping (LocalDay) -> Void) {
        _date = State(initialValue: (day ?? today).formattingDate)
        self.today = today
        self.onSave = onSave
    }
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date of birth", selection: $date, in: ...today.formattingDate, displayedComponents: .date)
                    .datePickerStyle(.wheel).labelsHidden()
            }
            .environment(\.calendar, LocalDay.calendar)
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationTitle("Date of birth").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use date") {
                        if let day = try? LocalDay(date: date, timeZone: LocalDay.calendar.timeZone) { onSave(day); dismiss() }
                    }.accessibilityIdentifier("confirmBirthday")
                }
            }
        }
    }
}

struct ProfileMeasurementFields: View {
    @Binding var profile: LocalProfile

    var body: some View {
        MeasurementSliderField(kind: .height, units: profile.measurementSystem, value: $profile.heightCentimeters)
        MeasurementSliderField(kind: .weight, units: profile.measurementSystem, value: $profile.weightKilograms)
    }
}

private struct MeasurementSliderField: View {
    let kind: MeasurementSliderKind
    let units: MeasurementSystem
    @Binding var value: Double?
    @State private var expanded = false

    private var range: ClosedRange<Double> { kind.range(system: units, current: value, expanded: expanded) }
    private var displayed: Double { kind.display(value ?? kind.suggestedCanonicalValue, system: units) }
    private var valueText: String {
        value == nil ? "Not added" : "\(displayed.formatted(.number.precision(.fractionLength(0...1)))) \(kind.unit(units))"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kind.title).font(.headline)
            Text(valueText).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
                .accessibilityIdentifier("\(kind.identifier)Value")
            Slider(value: Binding(get: { displayed }, set: {
                value = min(kind.validCanonicalRange.upperBound, max(kind.validCanonicalRange.lowerBound, kind.canonical($0, system: units)))
            }), in: range, step: kind.step(units)) {
                Text("\(kind.title) in \(kind.unit(units))")
            } onEditingChanged: { editing in
                if editing && value == nil { value = kind.suggestedCanonicalValue }
            }
            .accessibilityValue(valueText)
            .accessibilityHint("Adjust to add or change this optional measurement.")
            .accessibilityIdentifier(kind.identifier)
            HStack {
                Text("\(range.lowerBound.formatted(.number.precision(.fractionLength(0...1)))) \(kind.unit(units))")
                Spacer()
                Text("\(range.upperBound.formatted(.number.precision(.fractionLength(0...1)))) \(kind.unit(units))")
            }.font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            HStack {
                adjustmentButton("minus", direction: -1)
                Text(value == nil ? "Slide to add" : "Fine tune").font(.caption).foregroundStyle(.secondary)
                adjustmentButton("plus", direction: 1)
                Spacer(minLength: 8)
                if value != nil {
                    Button("Clear") { value = nil }.frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Clear \(kind.title.lowercased())")
                        .accessibilityIdentifier("\(kind.identifier)Clear")
                }
            }
            Button(expanded ? "Use compact range" : "Need a wider range?") { expanded.toggle() }
                .font(.footnote).frame(minHeight: 44)
                .accessibilityIdentifier("\(kind.identifier)Range")
        }
        .padding(.vertical, 8)
        .buttonStyle(.borderless)
    }

    private func adjustmentButton(_ symbol: String, direction: Double) -> some View {
        Button {
            value = kind.adjusted(value, system: units, direction: direction)
        } label: {
            Image(systemName: symbol).frame(minWidth: 44, minHeight: 44)
                .background(.quaternary, in: Circle())
        }
        .accessibilityLabel("\(direction < 0 ? "Decrease" : "Increase") \(kind.title.lowercased())")
        .accessibilityIdentifier("\(kind.identifier)\(direction < 0 ? "Decrease" : "Increase")")
    }
}

struct ProfileCycleFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        Picker("Usually predictable?", selection: $profile.predictability) {
            ForEach(CyclePredictability.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .accessibilityIdentifier("profilePredictability")
        Picker("Typical period length", selection: $profile.typicalPeriodDays) {
            Text("Choose days").tag(Int?.none)
            ForEach(1...30, id: \.self) { Text("\($0) days").tag(Int?.some($0)) }
        }
        .accessibilityIdentifier("profileDuration")
    }
}

struct ProfileSymptomFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        ForEach(CommonSymptom.allCases, id: \.self) { symptom in
            ProfileChoiceRow(title: symptom.title, selected: profile.commonSymptoms.contains(symptom)) { profile.toggle(symptom) }
                .accessibilityIdentifier("commonSymptom_\(symptom.rawValue)")
        }
    }
}

struct ProfileContextFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        ForEach(CycleContext.allCases, id: \.self) { context in
            ProfileChoiceRow(title: context.title, selected: profile.cycleContext.contains(context)) { profile.toggle(context) }
        }
    }
}

struct ProfileGoalFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        ForEach(TrackingGoal.allCases, id: \.self) { goal in
            ProfileChoiceRow(title: goal.title, selected: profile.goals.contains(goal)) {
                if profile.goals.remove(goal) == nil { profile.goals.insert(goal) }
            }
            .accessibilityIdentifier("goal_\(goal.rawValue)")
        }
    }
}

private struct ProfileChoiceRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .frame(minHeight: 44)
            .background(selected ? TrackerPalette(scheme: colorScheme).sage : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
