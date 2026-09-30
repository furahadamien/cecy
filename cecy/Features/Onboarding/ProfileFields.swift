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
    @Environment(\.locale) private var locale
    @Binding var profile: LocalProfile
    @State private var heightText: String
    @State private var weightText: String

    init(profile: Binding<LocalProfile>) {
        _profile = profile
        let value = profile.wrappedValue
        _heightText = State(initialValue: value.heightCentimeters.map(value.measurementSystem.heightForDisplay).map(Self.format) ?? "")
        _weightText = State(initialValue: value.weightKilograms.map(value.measurementSystem.weightForDisplay).map(Self.format) ?? "")
    }

    var body: some View {
        Group {
        LabeledContent(profile.measurementSystem == .metric ? "Height (cm)" : "Height (inches)") {
            TextField("Optional", text: Binding(get: { heightText }, set: {
                heightText = $0
                profile.heightCentimeters = parsed($0).map(profile.measurementSystem.heightInCentimeters)
            }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(profile.measurementSystem == .metric ? "Height in centimeters" : "Height in inches")
                .accessibilityIdentifier("profileHeight")
        }
        LabeledContent(profile.measurementSystem == .metric ? "Weight (kg)" : "Weight (lb)") {
            TextField("Optional", text: Binding(get: { weightText }, set: {
                weightText = $0
                profile.weightKilograms = parsed($0).map(profile.measurementSystem.weightInKilograms)
            }))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                .accessibilityLabel(profile.measurementSystem == .metric ? "Weight in kilograms" : "Weight in pounds")
                .accessibilityIdentifier("profileWeight")
        }
        if profile.heightCentimeters != nil || profile.weightKilograms != nil {
            Button("Clear measurements") {
                profile.heightCentimeters = nil; profile.weightKilograms = nil
                heightText = ""; weightText = ""
            }
        }
        }
        .onChange(of: profile.measurementSystem) { _, units in
            if let value = profile.heightCentimeters, value.isFinite { heightText = Self.format(units.heightForDisplay(value)) }
            if let value = profile.weightKilograms, value.isFinite { weightText = Self.format(units.weightForDisplay(value)) }
        }
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
    private func parsed(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Invalid input stays a validation error, never silently becomes an omitted measurement.
        return (try? Double(trimmed, format: .number.locale(locale), lenient: false)) ?? .nan
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
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
            }.frame(minHeight: 44)
        }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
