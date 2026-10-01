import Foundation
import SwiftData
import Testing
import UIKit
@testable import cecy

nonisolated private func wellnessProfile() throws -> LocalProfile {
    var profile = LocalProfile()
    profile.preferredName = "Synthetic Alex"
    profile.birthDayKey = 19950512
    profile.typicalPeriodDays = 5
    var preferences = WellnessPreferences()
    preferences.activityLevel = .moderatelyActive
    preferences.preferredExercises = [.walking, .strengthTraining]
    preferences.dietaryPreference = .vegetarian
    preferences.goals = [.manageSymptoms, .stayActive]
    try preferences.addAllergy("Peanuts")
    profile.wellnessPreferences = preferences
    return profile
}

nonisolated private let legacyWellnessProfileData = Data("""
{"id":"00000000-0000-0000-0000-000000000008","preferredName":"Synthetic legacy","birthDayKey":19950512,"measurementSystem":"metric","predictability":"notSure","typicalPeriodDays":5,"commonSymptoms":["cramps"],"cycleContext":[],"goals":["trackSymptoms"]}
""".utf8)

nonisolated struct WellnessDomainTests {
    @Test func unansweredIsNotExplicitNone() throws {
        var value = WellnessPreferences()
        #expect(value.isUnanswered)
        try value.validate()
        value.preferredExercises = []
        value.dietaryPreference = .noPreference
        value.goals = []
        value.setAllergyStatus(.noneKnown)
        #expect(!value.isUnanswered)
        let decoded = try JSONDecoder().decode(WellnessPreferences.self, from: JSONEncoder().encode(value))
        #expect(decoded == value)
        #expect(decoded.preferredExercises == [] && decoded.goals == [])
        #expect(decoded.foodAllergyStatus == .noneKnown)
    }

    @Test func allLocalPreferenceChoicesRoundTrip() throws {
        for activity in ActivityLevel.allCases {
            for diet in DietaryPreference.allCases {
                var value = WellnessPreferences()
                value.activityLevel = activity
                value.dietaryPreference = diet
                value.preferredExercises = Set(PreferredExercise.allCases)
                value.goals = Set(WellnessGoal.allCases)
                try value.validate()
                #expect(try JSONDecoder().decode(WellnessPreferences.self, from: JSONEncoder().encode(value)) == value)
            }
        }
        #expect(PreferredExercise.allCases.count == 9)
        #expect(WellnessGoal.allCases.count == 2)
    }

    @Test func allergyInsertionTrimsAndRejectsDuplicateWithoutMutation() throws {
        var value = WellnessPreferences()
        try value.addAllergy("  Peanuts  ")
        let saved = value
        #expect(value.foodAllergies == ["Peanuts"] && value.foodAllergyStatus == .listed)
        #expect(throws: WellnessValidationError.self) { try value.addAllergy("peanuts") }
        #expect(value == saved)
        #expect(throws: WellnessValidationError.self) { try value.addAllergy("\n\t") }
        #expect(value == saved)
        #expect(throws: WellnessValidationError.self) { try value.addAllergy("Milk\nEggs") }
        #expect(value == saved)
    }

    @Test func allergyLimitsAndStatusMustBeConsistent() throws {
        var value = WellnessPreferences()
        value.foodAllergyStatus = .listed
        #expect(throws: WellnessValidationError.self) { try value.validate() }
        for index in 0..<WellnessPreferences.maximumAllergies { try value.addAllergy("Synthetic \(index)") }
        let full = value
        #expect(throws: WellnessValidationError.self) { try value.addAllergy("One more") }
        #expect(value == full)
        value.setAllergyStatus(.noneKnown)
        #expect(value.foodAllergies.isEmpty)
        try value.validate()
        value.foodAllergies = ["Peanuts"]
        #expect(throws: WellnessValidationError.self) { try value.validate() }
        value.setAllergyStatus(.notAnswered)
        #expect(value.isUnanswered)
        try value.addAllergy(String(repeating: "é", count: 80))
        #expect(throws: WellnessValidationError.self) { try value.addAllergy(String(repeating: "a", count: 81)) }
    }

    @Test func oldProfileDecodesWithoutInventedAnswers() throws {
        let profile = try JSONDecoder().decode(LocalProfile.self, from: legacyWellnessProfileData)
        try profile.validate()
        #expect(profile.wellnessPreferences == nil)
        #expect(profile.preferredName == "Synthetic legacy" && profile.commonSymptoms == [.cramps])
        #expect(profile.goals == [.trackSymptoms])
        #expect(try JSONDecoder().decode(LocalProfile.self, from: JSONEncoder().encode(profile)) == profile)
    }

    @Test func malformedPreferenceEnumsFailRatherThanLosingAnswers() throws {
        let invalid = Data("""
        {"activityLevel":"invented","foodAllergyStatus":"notAnswered","foodAllergies":[]}
        """.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(WellnessPreferences.self, from: invalid) }
    }

    @Test func profileValidationIncludesWellnessAndCanClearIt() throws {
        var profile = try wellnessProfile()
        try profile.validate()
        profile.wellnessPreferences?.foodAllergies = []
        #expect(throws: WellnessValidationError.self) { try profile.validate() }
        profile.wellnessPreferences = nil
        try profile.validate()
        #expect(try JSONDecoder().decode(LocalProfile.self, from: JSONEncoder().encode(profile)).wellnessPreferences == nil)
    }

    @Test func digestiveChangeUsesExistingSeverityAndCommonSymptomRules() throws {
        let day = try LocalDay(key: 20260929)
        for value: Int? in [nil, 1, 2, 3] {
            let entry = SymptomEntry(day: day, kind: .digestiveChanges, value: value)
            try SymptomValidation.validate([entry], asOf: day)
            #expect(entry.ratingLabel == value.map { ["Mild", "Moderate", "Severe"][$0 - 1] })
        }
        var profile = LocalProfile()
        profile.toggle(.digestiveChanges as CommonSymptom)
        #expect(profile.commonSymptoms == [.digestiveChanges])
        profile.toggle(.none as CommonSymptom)
        #expect(profile.commonSymptoms == [.none])
        profile.toggle(.digestiveChanges as CommonSymptom)
        #expect(profile.commonSymptoms == [.digestiveChanges])
        #expect(SymptomKind.energyLevel.ratingLabels == ["Low", "Typical", "High"])
        #expect(SymptomKind.sleepQuality.ratingLabels == ["Poor", "Fair", "Good"])
    }

    @Test func digestiveTimingUsesExistingEvidenceRules() throws {
        let today = try LocalDay(key: 20260929)
        let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        let entries = try periods.prefix(3).map { SymptomEntry(day: try $0.start.adding(days: -1), kind: .digestiveChanges) }
        let insight = try #require(CycleInsightEngine.generate(periods: periods, symptoms: entries, today: today).first)
        #expect(insight.matchedStarts == 3 && insight.category == .symptomTiming)
        #expect(insight.title.contains("Digestive changes") && insight.explanation.contains("does not mean"))
    }

    @Test func wellnessExportRequiresProfileConsentAndUsesVersionFour() throws {
        let today = try LocalDay(key: 20260929)
        let snapshot = TrackerSnapshot(symptoms: [SymptomEntry(day: today, kind: .digestiveChanges, notes: "Private note")], profile: try wellnessProfile())
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let excluded = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: today.formattingDate)
        let ordinary = try decoder.decode(TrackerExport.Document.self, from: excluded)
        #expect(ordinary.formatVersion == 1 && ordinary.profile == nil)
        #expect(!String(decoding: excluded, as: UTF8.self).contains("Peanuts"))
        let included = try TrackerExport.encode(snapshot: snapshot, includeNotes: false, generatedAt: today.formattingDate, includeProfile: true)
        let document = try decoder.decode(TrackerExport.Document.self, from: included)
        #expect(document.formatVersion == 4)
        #expect(document.profile?.wellnessPreferences?.foodAllergies == ["Peanuts"])
        #expect(document.profile?.wellnessPreferences?.preferredExercises == ["strengthTraining", "walking"])
        #expect(document.observations.first?.type == "digestiveChanges" && document.observations.first?.notes == nil)
        #expect(!String(decoding: included, as: UTF8.self).contains("userID"))
        let legacy = TrackerSnapshot(profile: try JSONDecoder().decode(LocalProfile.self, from: legacyWellnessProfileData))
        let oldExport = try TrackerExport.encode(snapshot: legacy, includeNotes: false, generatedAt: today.formattingDate, includeProfile: true)
        #expect(try decoder.decode(TrackerExport.Document.self, from: oldExport).formatVersion == 2)
    }
}

@MainActor struct WellnessPersistenceTests {
    private let today = try! LocalDay(key: 20260929)
    private enum Failure: Error { case disk }

    @Test func legacyPayloadAndNewPreferencesReopenInSameV6Store() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.store")
        let legacy = try JSONDecoder().decode(LocalProfile.self, from: legacyWellnessProfileData)
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let context = ModelContext(repository.container)
            let record = try TrackerSchemaV4.ProfileRecord(legacy)
            record.payload = legacyWellnessProfileData
            context.insert(record)
            try context.save()
        }
        var expected = legacy
        expected.wellnessPreferences = try wellnessProfile().wellnessPreferences
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            #expect(try repository.load().profile == legacy)
            _ = try repository.saveProfile(expected, today: today)
            _ = try repository.addSymptoms([SymptomEntry(day: today, kind: .digestiveChanges, value: 2, notes: "Synthetic note")], today: today, now: today.formattingDate)
        }
        let repository = try SwiftDataPeriodRepository.local(url: url)
        let loaded = try repository.load()
        #expect(loaded.profile == expected)
        #expect(loaded.symptoms.first?.kind == .digestiveChanges && loaded.symptoms.first?.value == 2)
        #expect(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(try repository.deleteAll() == TrackerSnapshot())
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == TrackerSnapshot())
    }

    @Test func failedProfileSaveAndResetPreserveCommittedPreferences() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = false
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }
            try $0.save()
        })
        let original = try wellnessProfile()
        _ = try repository.saveProfile(original, today: today)
        var changed = original; changed.wellnessPreferences = nil
        fail = true
        #expect(throws: Failure.self) { try repository.saveProfile(changed, today: today) }
        #expect(try repository.load().profile == original)
        #expect(throws: Failure.self) { try repository.deleteAll() }
        #expect(try repository.load().profile == original)
        fail = false
        _ = try repository.saveProfile(changed, today: today)
        #expect(try repository.load().profile?.wellnessPreferences == nil)
    }

    @Test func digestiveCRUDAndDuplicateBatchRemainAtomic() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let entry = SymptomEntry(day: today, kind: .digestiveChanges, value: 1)
        _ = try repository.addSymptoms([entry], today: today, now: today.formattingDate)
        #expect(throws: TrackingError.self) {
            try repository.addSymptoms([SymptomEntry(day: today, kind: .headache), SymptomEntry(day: today, kind: .digestiveChanges)], today: today, now: today.formattingDate)
        }
        #expect(try repository.load().symptoms.count == 1)
        var edited = entry; edited.value = 3; edited.notes = "Synthetic correction"
        _ = try repository.saveSymptom(edited, editing: true, today: today, now: today.formattingDate)
        #expect(try repository.load().symptoms.first?.ratingLabel == "Severe")
        #expect(try repository.deleteSymptom(id: entry.id).symptoms.isEmpty)
    }

    @Test func preferencesDoNotChangePredictionsAndSignedOutWritesAreBlocked() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let periods = try [20260607, 20260705, 20260804, 20260902].map { Period(start: try LocalDay(key: $0)) }
        _ = try repository.add(periods, completingOnboarding: true, today: today, now: today.formattingDate)
        let account = AppleAccount()
        let session = TrackerSession(repository: { repository }, clock: { self.today.formattingDate }, timeZone: { .gmt }, account: account)
        session.load()
        let prediction = session.overview
        let profile = try wellnessProfile()
        #expect(session.saveProfile(profile) == nil && session.overview == prediction)
        #expect(session.snapshot.symptoms.isEmpty)
        var invalid = profile; invalid.wellnessPreferences?.foodAllergies = []
        #expect(session.saveProfile(invalid)?.contains("Add at least one") == true)
        #expect(session.snapshot.profile == profile)
        try account.link(userID: "synthetic-wellness", profileID: profile.id, protectsExistingProfile: false)
        #expect(session.logOut() == nil)
        #expect(session.saveProfile(profile) != nil)
        #expect(try repository.load().profile == profile)
    }

    @Test func digestiveSymbolsExist() {
        #expect(UIImage(systemName: SymptomKind.digestiveChanges.symbol) != nil)
        #expect(UIImage(systemName: CommonSymptom.digestiveChanges.symbol) != nil)
    }
}
