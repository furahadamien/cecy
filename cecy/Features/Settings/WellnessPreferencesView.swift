import SwiftUI

/// Edits the parent profile draft; only Profile's Save commits to the repository.
struct WellnessPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var preferences: WellnessPreferences?
    private let initial: WellnessPreferences?
    @State private var draft: WellnessPreferences
    @State private var allergyText = ""
    @State private var error: String?
    @State private var discard = false
    @State private var clear = false
    @FocusState private var allergyFocused: Bool

    init(preferences: Binding<WellnessPreferences?>) {
        _preferences = preferences
        initial = preferences.wrappedValue
        _draft = State(initialValue: preferences.wrappedValue ?? WellnessPreferences())
    }

    private var normalized: WellnessPreferences? { draft.isUnanswered ? nil : draft }
    private var hasChanges: Bool { normalized != initial || !allergyText.isEmpty }
    private var validation: String? {
        do { try draft.validate(); return nil }
        catch { return error.localizedDescription }
    }

    var body: some View {
        SettingsForm(title: "Wellness preferences") {
            Section {
                Text("Optional choices saved on this device. They do not change cycle predictions or record exercise, meals or symptoms.")
                Text("If you enable AI and request wellness suggestions, these choices—including food allergies—are sent with that request. Saving preferences alone sends nothing.")
                Text("Tap Done to return to Profile, then Save to keep your changes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Activity") {
                Picker("Activity level", selection: $draft.activityLevel) {
                    Text("Not answered").tag(ActivityLevel?.none)
                    ForEach(ActivityLevel.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .accessibilityIdentifier("wellnessActivity")
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
            Section("Food preferences") {
                Picker("Dietary preference", selection: $draft.dietaryPreference) {
                    Text("Not answered").tag(DietaryPreference?.none)
                    ForEach(DietaryPreference.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                .accessibilityIdentifier("wellnessDiet")
            }
            Section {
                Picker("Food allergies", selection: Binding(get: { draft.foodAllergyStatus }, set: {
                    draft.setAllergyStatus($0)
                    allergyText = ""
                    error = nil
                })) {
                    ForEach(FoodAllergyStatus.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("wellnessAllergyStatus")
                if draft.foodAllergyStatus == .listed {
                    ForEach(Array(draft.foodAllergies.enumerated()), id: \.offset) { index, name in
                        HStack {
                            Text(name)
                            Spacer()
                            Button(role: .destructive) { draft.foodAllergies.remove(at: index) } label: {
                                Image(systemName: "minus.circle").frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove food allergy")
                            .accessibilityIdentifier("removeFoodAllergy_\(index)")
                        }
                    }
                    TextField("Food allergy", text: $allergyText)
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
                Text("Not answered is different from no known allergies. Changing away from a list clears its entries from this draft. These are your reported preferences, not a medical assessment.")
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
                Text("These are separate from your existing tracking goals. Saving preferences does not enable AI or send them anywhere.")
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
                Button("Done") {
                    guard validation == nil, allergyText.isEmpty else { return }
                    preferences = normalized
                    dismiss()
                }
                .disabled(validation != nil || !allergyText.isEmpty)
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
