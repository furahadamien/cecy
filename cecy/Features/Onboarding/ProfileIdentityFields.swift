import SwiftUI

struct ProfileGenderFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        SelectionFlowLayout {
            ForEach(GenderIdentity.allCases, id: \.self) { gender in
                SelectionChip(title: gender.title, selected: profile.genderIdentity == gender) {
                    profile.genderIdentity = profile.genderIdentity == gender ? nil : gender
                }.accessibilityIdentifier("profileGender_\(gender.rawValue)")
            }
        }
        Button("Clear gender answer") { profile.genderIdentity = nil }
            .accessibilityIdentifier("clearGender")
    }
}

struct ProfilePartnerFields: View {
    @Binding var profile: LocalProfile
    var body: some View {
        SelectionFlowLayout {
            ForEach(SexualPartnerPreference.allCases, id: \.self) { partner in
                SelectionChip(title: partner.title, selected: profile.sexualPartners?.contains(partner) == true) {
                    profile.togglePartner(partner)
                }.accessibilityIdentifier("profilePartner_\(partner.rawValue)")
            }
        }
        Button("Clear partner answer") { profile.sexualPartners = nil }
            .accessibilityIdentifier("clearPartners")
    }
}