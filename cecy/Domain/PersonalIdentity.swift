import Foundation

/// Self-reported profile answers only; never prediction or external insight inputs.
nonisolated enum GenderIdentity: String, Codable, CaseIterable, Sendable {
    case woman, man, nonbinary, anotherIdentity, questioning, preferNotToSay
    var title: String {
        switch self {
        case .woman: "Woman"
        case .man: "Man"
        case .nonbinary: "Nonbinary"
        case .anotherIdentity: "Another identity"
        case .questioning: "Questioning"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}

nonisolated enum SexualPartnerPreference: String, Codable, CaseIterable, Sendable {
    case women, men, nonbinaryPeople, anotherGender, notSexuallyActive, preferNotToSay
    var title: String {
        switch self {
        case .women: "Women"
        case .men: "Men"
        case .nonbinaryPeople: "Nonbinary people"
        case .anotherGender: "People of another gender"
        case .notSexuallyActive: "I’m not sexually active"
        case .preferNotToSay: "Prefer not to say"
        }
    }
    var isExclusive: Bool { self == .notSexuallyActive || self == .preferNotToSay }
}