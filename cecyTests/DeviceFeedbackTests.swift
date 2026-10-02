import Foundation
import Testing
import UIKit
@testable import cecy

nonisolated struct DeviceFeedbackDomainTests {
    private func profile() -> LocalProfile {
        var value = LocalProfile()
        value.preferredName = "Synthetic"
        value.birthDayKey = 19950512
        value.genderIdentity = .nonbinary
        value.sexualPartners = [.men, .women]
        return value
    }

    @Test func oldProfilesDecodeWithUnansweredIdentity() throws {
        let original = profile()
        let data = try JSONEncoder().encode(original)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "genderIdentity")
        json.removeValue(forKey: "sexualPartners")
        let old = try JSONDecoder().decode(LocalProfile.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.genderIdentity == nil && old.sexualPartners == nil)
        #expect(old.preferredName == "Synthetic" && old.birthDayKey == 19950512)
        #expect(try JSONDecoder().decode(LocalProfile.self, from: data) == original)
        let exported = try TrackerExport.ProfileRecord(old, includeSexualInformation: true)
        #expect(exported.genderIdentity == nil && exported.sexualPartners == nil)
    }

    @Test func partnerChoicesAreInclusiveClearableAndExclusiveWhenNeeded() throws {
        var p = profile()
        p.togglePartner(.nonbinaryPeople)
        #expect(p.sexualPartners == [.men, .women, .nonbinaryPeople])
        p.togglePartner(.preferNotToSay)
        #expect(p.sexualPartners == [.preferNotToSay])
        p.togglePartner(.women)
        #expect(p.sexualPartners == [.women])
        p.togglePartner(.women)
        #expect(p.sexualPartners == nil)
        p.sexualPartners = [.notSexuallyActive, .men]
        #expect(throws: ProfileError.selection) { try p.validate() }
        p.sexualPartners = [.notSexuallyActive]
        try p.validate()
    }

    @Test func newFieldsRequireIndependentExportPermissions() throws {
        let snapshot = TrackerSnapshot(periods: [], onboardingCompletedAt: nil, profile: profile())
        func export(profile: Bool, sexual: Bool) throws -> TrackerExport.Document {
            try JSONDecoder.iso8601.decode(TrackerExport.Document.self,
                from: TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: Date(), includeProfile: profile, includeSexualActivity: sexual))
        }
        #expect(try export(profile: false, sexual: true).profile == nil)
        let personal = try export(profile: true, sexual: false)
        #expect(personal.formatVersion == 5 && personal.profile?.genderIdentity == "nonbinary")
        #expect(personal.profile?.sexualPartners == nil)
        #expect(try export(profile: true, sexual: true).profile?.sexualPartners == ["men", "women"])
    }

    @Test func identityNeverEntersWellnessContextOrPredictions() throws {
        let today = try LocalDay(key: 20260929)
        var p = profile()
        p.wellnessPreferences = WellnessPreferences(activityLevel: .beginner, preferredExercises: [], dietaryPreference: .noPreference,
            foodAllergyStatus: .noneKnown, foodAllergies: [], goals: [])
        var snapshot = TrackerSnapshot(periods: [], onboardingCompletedAt: nil, profile: p)
        let baseline = try AIContextBuilder.wellness(snapshot: snapshot, today: today)
        snapshot.profile?.genderIdentity = .man
        snapshot.profile?.sexualPartners = [.preferNotToSay]
        #expect(try AIContextBuilder.wellness(snapshot: snapshot, today: today) == baseline)
        guard case .wellness(let context) = baseline else { Issue.record(); return }
        let json = String(decoding: try JSONEncoder().encode(context), as: UTF8.self)
        for field in ["genderIdentity", "sexualPartners", "nonbinary", "Synthetic"] { #expect(!json.contains(field)) }
    }

    @Test func questionLimitIs100CharactersNotBytes() throws {
        try AIContextBuilder.validateQuestion(String(repeating: "é", count: 100))
        #expect(throws: AIContextError.invalidQuestion) { try AIContextBuilder.validateQuestion(String(repeating: "x", count: 101)) }
        #expect(throws: AIContextError.invalidQuestion) { try AIContextBuilder.validateQuestion(" \n ") }
        try AIContextBuilder.validateText(String(repeating: "x", count: 2_000))
        for scope in CycleQuestionScope.allCases {
            for kind in SymptomKind.allCases {
                try AIContextBuilder.validateQuestion(scope.suggestedQuestion(kind: kind))
            }
        }
    }

    @Test func dateMarkersIncludeEverySymptomAndSexualActivityWithoutInferringBleeding() throws {
        let day = try LocalDay(key: 20260929)
        let snapshot = TrackerSnapshot(periods: [Period(start: day)], onboardingCompletedAt: nil,
            symptoms: [SymptomEntry(day: day, kind: .cramps), SymptomEntry(day: day, kind: .headache)],
            sexualActivities: [SexualActivityEntry(day: day, activities: [.vaginalSex, .masturbation])])
        let markers = DayActivityMarker.recorded(on: day, in: snapshot)
        #expect(markers.map(\.id) == ["period", "symptom.cramps", "symptom.headache", "sexualActivity"])
        #expect(markers.map(\.symbol) == ["drop.fill", SymptomKind.cramps.symbol, SymptomKind.headache.symbol, "heart.fill"])
        #expect(markers.last?.title.contains("Masturbation") == true)
        #expect(DayActivityMarker.recorded(on: try day.adding(days: 1), in: snapshot).isEmpty)
    }

    @MainActor @Test func markerSymbolsExist() throws {
        let day = try LocalDay(key: 20260929)
        let snapshot = TrackerSnapshot(periods: [Period(start: day)], onboardingCompletedAt: nil,
            symptoms: SymptomKind.allCases.map { SymptomEntry(day: day, kind: $0) },
            sexualActivities: [SexualActivityEntry(day: day, activities: [.other])])
        for marker in DayActivityMarker.recorded(on: day, in: snapshot) { #expect(UIImage(systemName: marker.symbol) != nil) }
    }
}

@MainActor struct DeviceFeedbackPersistenceTests {
    @Test func profileAnswersReopenAndClearInExistingStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.store")
        let day = try LocalDay(key: 20260929)
        var p = LocalProfile()
        p.preferredName = "Synthetic"; p.birthDayKey = 19950512
        p.genderIdentity = .woman; p.sexualPartners = [.women, .nonbinaryPeople]
        do {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            _ = try repository.saveProfile(p, today: day)
        }
        let reopened = try SwiftDataPeriodRepository.local(url: url)
        #expect(try reopened.load().profile == p)
        p.genderIdentity = nil; p.sexualPartners = nil
        _ = try reopened.saveProfile(p, today: day)
        #expect(try reopened.load().profile?.sexualPartners == nil)
        #expect(try reopened.load().profile?.genderIdentity == nil)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}
