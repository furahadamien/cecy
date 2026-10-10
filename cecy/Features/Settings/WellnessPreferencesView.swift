import SwiftUI

/// Edits the parent profile draft; only Profile's Save commits to the repository.
struct WellnessPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var preferences: WellnessPreferences?
    private let initial: WellnessPreferences?
    private let saveTitle: String
    private let onSave: ((WellnessPreferences?) -> String?)?
    @State private var draft: WellnessPreferences
    @State private var allergyText = ""
    @State private var error: String?
    @State private var discard = false
    @State private var clear = false
    @FocusState private var allergyFocused: Bool

    init(preferences: Binding<WellnessPreferences?>, saveTitle: String = "Done",
         onSave: ((WellnessPreferences?) -> String?)? = nil) {
        _preferences = preferences
        initial = preferences.wrappedValue
        self.saveTitle = saveTitle
        self.onSave = onSave
        _draft = State(initialValue: preferences.wrappedValue ?? WellnessPreferences())
    }

    private var normalized: WellnessPreferences? { draft.isUnanswered ? nil : draft }
    private let commonAllergies = ["Milk", "Eggs", "Peanuts", "Tree nuts", "Wheat", "Soy", "Fish", "Shellfish", "Sesame"]
    private var allergyChoices: [String] {
        commonAllergies + draft.foodAllergies.filter { name in
            !commonAllergies.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }
    }
    private var hasChanges: Bool { normalized != initial || !allergyText.isEmpty }
    private var validation: String? {
        do { try draft.validate(); return nil }
        catch { return error.localizedDescription }
    }

    var body: some View {
        SettingsForm(title: "Wellness preferences") {
            Section {
                if onSave != nil {
                    Text("Choose once to personalize your daily insights.")
                } else {
                    Text("Your preferences stay stored on this device. AI suggestions use selected details sent only when you request them.")
                    Text("Tap Done to return to Profile, then Save to keep your changes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Activity level") {
                SelectionFlowLayout {
                    SelectionChip(title: "Not answered", selected: draft.activityLevel == nil) { draft.activityLevel = nil }
                        .accessibilityIdentifier("wellnessActivity_unanswered")
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        SelectionChip(title: level.title, symbol: "figure.walk", selected: draft.activityLevel == level) {
                            draft.activityLevel = level
                        }.accessibilityIdentifier("wellnessActivity_\(level.rawValue)")
                    }
                }
            }
            Section {
                SelectionFlowLayout {
                    ForEach(PreferredExercise.allCases, id: \.self) { exercise in
                        SelectionChip(title: exercise.title, symbol: "figure.walk",
                                      selected: draft.preferredExercises?.contains(exercise) == true) {
                            var selected = draft.preferredExercises ?? []
                            if !selected.insert(exercise).inserted { selected.remove(exercise) }
                            draft.preferredExercises = selected
                        }
                        .accessibilityIdentifier("wellnessExercise_\(exercise.rawValue)")
                    }
                }
                Text(draft.preferredExercises == nil ? "Not answered" : draft.preferredExercises!.isEmpty ? "No exercise preferences" : "Choose all that apply.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("No exercise preferences") { draft.preferredExercises = [] }
                    .accessibilityIdentifier("wellnessExercisesNone")
                Button("Leave exercise preferences unanswered") { draft.preferredExercises = nil }
            } header: { Text("Preferred exercises") }
            Section("Dietary preference") {
                SelectionFlowLayout {
                    SelectionChip(title: "Not answered", selected: draft.dietaryPreference == nil) { draft.dietaryPreference = nil }
                        .accessibilityIdentifier("wellnessDiet_unanswered")
                    ForEach(DietaryPreference.allCases, id: \.self) { diet in
                        SelectionChip(title: diet.title, symbol: "fork.knife", selected: draft.dietaryPreference == diet) {
                            draft.dietaryPreference = diet
                        }.accessibilityIdentifier("wellnessDiet_\(diet.rawValue)")
                    }
                }
            }
            Section {
                SelectionFlowLayout {
                    ForEach(FoodAllergyStatus.allCases, id: \.self) { status in
                        SelectionChip(title: status.title, selected: draft.foodAllergyStatus == status) {
                            draft.setAllergyStatus(status)
                            allergyText = ""
                            error = nil
                        }.accessibilityIdentifier("wellnessAllergyStatus_\(status.rawValue)")
                    }
                }
                if draft.foodAllergyStatus == .listed {
                    SelectionFlowLayout {
                        ForEach(allergyChoices, id: \.self) { name in
                            SelectionChip(title: name, selected: draft.foodAllergies.contains { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                                error = nil
                                if let index = draft.foodAllergies.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                                    draft.foodAllergies.remove(at: index)
                                } else {
                                    do { try draft.addAllergy(name) } catch { self.error = error.localizedDescription }
                                }
                            }
                            .accessibilityIdentifier("foodAllergy_\(name)")
                        }
                    }
                    TextField("Another food allergy", text: $allergyText)
                        .focused($allergyFocused)
                        .submitLabel(.done)
                        .accessibilityIdentifier("foodAllergyName")
                        .onSubmit { addAllergy() }
                    Button("Add food allergy") { addAllergy() }
                        .disabled(allergyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("addFoodAllergy")
                    Text("Up to 20 entries, 80 characters each. Add each item separately.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("Food allergies") } footer: {
                Text("Choose all that apply, or add another. Switching away from the list clears its selections.")
            }
            Section {
                SelectionFlowLayout {
                    ForEach(WellnessGoal.allCases, id: \.self) { goal in
                        SelectionChip(title: goal.title, symbol: "checkmark.circle",
                                      selected: draft.goals?.contains(goal) == true) {
                            var selected = draft.goals ?? []
                            if !selected.insert(goal).inserted { selected.remove(goal) }
                            draft.goals = selected
                        }
                        .accessibilityIdentifier("wellnessGoal_\(goal.rawValue)")
                    }
                }
                Text(draft.goals == nil ? "Not answered" : draft.goals!.isEmpty ? "No wellness goals selected" : "Choose all that apply.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("No wellness goals") { draft.goals = [] }
                Button("Leave wellness goals unanswered") { draft.goals = nil }
            } header: { Text("Wellness goals") } footer: {
                if onSave == nil { Text("Saving preferences does not send them anywhere.") }
            }
            if let message = error ?? validation {
                Section { InlineError(message: message) }
            }
            if !allergyText.isEmpty {
                Section { Text("Add or clear the food allergy text before finishing.").font(.footnote) }
            }
            Section {
                Button("Clear wellness preferences", role: .destructive) { clear = true }
                    .accessibilityIdentifier("clearWellness")
            } footer: {
                Text("Included in JSON export only when you choose Include personal profile, including any food allergies. Delete all data also removes these preferences.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { if hasChanges { discard = true } else { dismiss() } }
                    .accessibilityIdentifier("cancelWellness")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle) {
                    guard validation == nil, allergyText.isEmpty else { return }
                    if let onSave, let message = onSave(normalized) {
                        error = message
                        return
                    }
                    preferences = normalized
                    dismiss()
                }
                .disabled(validation != nil || !allergyText.isEmpty || (onSave != nil && !draft.isReadyForInsights))
                .accessibilityIdentifier("applyWellness")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Hide keyboard") { allergyFocused = false }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .alert("Discard wellness changes?", isPresented: $discard) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .confirmationDialog("Clear wellness preferences?", isPresented: $clear, titleVisibility: .visible) {
            Button("Clear preferences", role: .destructive) {
                draft = WellnessPreferences()
                allergyText = ""
                error = nil
            }
            Button("Keep preferences", role: .cancel) {}
        } message: { Text("This clears the draft. Tap Done and Save on Profile to keep the change.") }
        .onChange(of: allergyText) { _, _ in error = nil }
    }

    private func addAllergy() {
        do {
            try draft.addAllergy(allergyText)
            allergyText = ""
            allergyFocused = false
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
