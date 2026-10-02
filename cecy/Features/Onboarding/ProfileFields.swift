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
            LabeledContent("Date of birth", value: profile.birthDayKey.flatMap { try? LocalDay(key: $0) }.map { DayText.full($0) } ?? "Choose date")
        }
        .accessibilityIdentifier("profileBirthday")
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
            .trackerFormStyle()
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Measurement units").font(.headline)
            Picker("Measurement units", selection: $profile.measurementSystem) {
                Text("Metric").tag(MeasurementSystem.metric)
                Text("Imperial").tag(MeasurementSystem.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("profileUnits")
        }
        MeasurementWheelField(kind: .height, units: profile.measurementSystem, value: $profile.heightCentimeters)
        MeasurementWheelField(kind: .weight, units: profile.measurementSystem, value: $profile.weightKilograms)
    }
}

private struct MeasurementWheelField: View {
    let kind: MeasurementPickerKind
    let units: MeasurementSystem
    @Binding var value: Double?
    @State private var isExpanded = false
    @ScaledMetric(relativeTo: .body) private var wheelHeight = 160.0

    private var valueText: String {
        value.map { kind.formatted($0, system: units) } ?? "Not added"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title).font(.headline)
                    Text(valueText).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        .accessibilityIdentifier("\(kind.identifier)Value")
                }
                Spacer()
                if value != nil {
                    Button("Clear") { value = nil; isExpanded = false }.frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("Clear \(kind.title.lowercased())")
                        .accessibilityIdentifier("\(kind.identifier)Clear")
                }
                if !isExpanded {
                    Button(value == nil ? "Add" : "Edit") {
                        if value == nil { value = kind.suggestedCanonicalValue }
                        isExpanded = true
                    }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityLabel("\(value == nil ? "Add" : "Edit") \(kind.title.lowercased())")
                        .accessibilityIdentifier("\(kind.identifier)\(value == nil ? "Add" : "Edit")")
                }
            }
            if value != nil && isExpanded {
                Picker(kind.title, selection: Binding(get: {
                    kind.index(for: value ?? kind.suggestedCanonicalValue, system: units)
                }, set: { index in
                    value = kind.value(at: index, system: units)
                })) {
                    ForEach(kind.indices(system: units), id: \.self) { index in
                        Text(kind.formatted(kind.value(at: index, system: units), system: units)).tag(index)
                    }
                }
                .pickerStyle(.wheel).labelsHidden()
                .frame(height: wheelHeight).clipped()
                .id(units)
                .accessibilityLabel(kind.title)
                .accessibilityHint("Swipe up or down to change this optional measurement.")
                .accessibilityIdentifier(kind.identifier)
                Button("Done") { isExpanded = false }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Done choosing \(kind.title.lowercased())")
                    .accessibilityIdentifier("\(kind.identifier)Done")
            }
        }
        .padding(.vertical, 8)
        .buttonStyle(.borderless)
        .onChange(of: units) { _, _ in isExpanded = false }
    }
}

struct ProfileCycleFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usually predictable?").font(.headline)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(CyclePredictability.allCases, id: \.self) { choice in
                        SelectionChip(title: choice.title, selected: profile.predictability == choice) {
                            profile.predictability = choice
                        }
                        .accessibilityIdentifier("profilePredictability_\(choice.rawValue)")
                    }
                }.padding(.vertical, 4)
            }
            .accessibilityIdentifier("profilePredictability")
        }
        CyclePreferenceField(title: "Typical period length", range: CycleSetupPolicy.periodDays,
                             defaultValue: 5, identifier: "profileDuration", value: $profile.typicalPeriodDays)
        CyclePreferenceField(title: "Typical cycle length", range: CycleSetupPolicy.cycleDays,
                             defaultValue: 28, identifier: "profileCycleLength", value: $profile.typicalCycleDays)
    }
}

struct ProfileSymptomFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        SelectionFlowLayout {
            ForEach(CommonSymptom.allCases, id: \.self) { symptom in
                SelectionChip(title: symptom.title, symbol: symptom.symbol, selected: profile.commonSymptoms.contains(symptom)) {
                    profile.toggle(symptom)
                }
                .accessibilityIdentifier("commonSymptom_\(symptom.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("commonSymptoms")
    }
}

struct ProfileContextFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        SelectionFlowLayout {
            ForEach(CycleContext.allCases, id: \.self) { context in
                SelectionChip(title: context.title, selected: profile.cycleContext.contains(context)) {
                    profile.toggle(context)
                }
                .accessibilityIdentifier("cycleContext_\(context.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profileCycleContext")
    }
}

struct ProfileGoalFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        SelectionFlowLayout {
            ForEach(TrackingGoal.allCases, id: \.self) { goal in
                SelectionChip(title: goal.title, selected: profile.goals.contains(goal)) {
                    if profile.goals.remove(goal) == nil { profile.goals.insert(goal) }
                }
                .accessibilityIdentifier("goal_\(goal.rawValue)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profileGoals")
    }
}
