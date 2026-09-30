import Foundation
import Testing
@testable import cecy

nonisolated struct AppearanceAndSliderTests {
    @Test func existingPreferencesFollowDeviceWithoutLosingPrivacyChoices() throws {
        let data = Data(#"{"version":1,"lockEnabled":true,"dailyReminder":true,"windowReminder":false,"reminderHour":8,"reminderMinute":30}"#.utf8)
        let old = try JSONDecoder().decode(PrivacyPreferences.self, from: data)
        #expect(old.appearance == nil && old.lockEnabled && old.dailyReminder)
        #expect(old.reminderHour == 8 && old.reminderMinute == 30)
        for appearance in [AppAppearance.light, .dark] {
            var changed = old; changed.appearance = appearance
            let reopened = try JSONDecoder().decode(PrivacyPreferences.self, from: JSONEncoder().encode(changed))
            #expect(reopened == changed)
        }
        let invalid = Data(#"{"version":1,"lockEnabled":true,"dailyReminder":false,"windowReminder":false,"reminderHour":20,"reminderMinute":0,"appearance":"unsupported"}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PrivacyPreferences.self, from: invalid) }
    }

    @Test func slidersKeepMeasurementsOptionalAndConvertPrecisely() {
        let profile = LocalProfile()
        for units in MeasurementSystem.allCases {
            for kind in [MeasurementSliderKind.height, .weight] {
                let range = kind.range(system: units, current: nil, expanded: false)
                #expect(range.contains(kind.display(kind.suggestedCanonicalValue, system: units)))
                let changed = kind.adjusted(nil, system: units, direction: 1)
                let difference = kind.display(changed, system: units) - kind.display(kind.suggestedCanonicalValue, system: units)
                #expect(abs(difference - kind.step(units)) < 0.000001)
                #expect(kind.adjusted(kind.validCanonicalRange.lowerBound, system: units, direction: -1) == kind.validCanonicalRange.lowerBound)
                #expect(kind.adjusted(kind.validCanonicalRange.upperBound, system: units, direction: 1) == kind.validCanonicalRange.upperBound)
            }
        }
        #expect(profile.heightCentimeters == nil && profile.weightKilograms == nil)
    }

    @Test func slidersIncludeExistingValuesOutsideCompactRange() {
        for units in MeasurementSystem.allCases {
            #expect(MeasurementSliderKind.height.range(system: units, current: 295, expanded: false)
                .contains(MeasurementSliderKind.height.display(295, system: units)))
            #expect(MeasurementSliderKind.weight.range(system: units, current: 260, expanded: false)
                .contains(MeasurementSliderKind.weight.display(260, system: units)))
            #expect(MeasurementSliderKind.weight.range(system: units, current: nil, expanded: true)
                .contains(MeasurementSliderKind.weight.display(999, system: units)))
        }
    }

    @Test func existingAppleIdentityDefaultsToNotSignedOut() throws {
        let id = UUID()
        let old = Data("{\"userID\":\"synthetic\",\"profileID\":\"\(id.uuidString)\"}".utf8)
        let decoded = try JSONDecoder().decode(AppleIdentity.self, from: old)
        #expect(decoded.signedOut == nil && decoded.profileID == id)
    }
}

@MainActor private final class FailingAppearanceStore: PrivacyPreferenceStoring {
    enum Failure: Error { case disk }
    var value = PrivacyPreferences()
    var fail = false
    func load() -> PrivacyPreferences { value }
    func save(_ value: PrivacyPreferences) throws {
        if fail { throw Failure.disk }
        self.value = value
    }
}

@MainActor private final class FailingIdentityStore: AppleIdentityStoring {
    enum Failure: Error { case disk }
    var identity: AppleIdentity?
    var failLoad = false
    var failSave = false
    func load() throws -> AppleIdentity? {
        if failLoad { throw Failure.disk }
        return identity
    }
    func save(_ identity: AppleIdentity) throws {
        if failSave { throw Failure.disk }
        self.identity = identity
    }
    func clear() { identity = nil }
}

@MainActor struct AppearanceAndLogoutTests {
    @Test func appearanceWritesAreDurableAndFailSafely() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FilePrivacyPreferences(url: root.appendingPathComponent("preferences.json"))
        let privacy = TrackerPrivacy(storage: store, authentication: FixedDeviceAuthentication(),
                                     exports: ProtectedExportFiles(directory: root.appendingPathComponent("exports")), delivery: MemoryReminderDelivery())
        privacy.start()
        #expect(privacy.setAppearance(.dark) == nil)
        #expect(try store.load().appearance == .dark)
        #expect(privacy.setAppearance(.light) == nil)
        #expect(try store.load().appearance == .light)
        #expect(privacy.setAppearance(nil) == nil)
        #expect(try store.load().appearance == nil)

        let failing = FailingAppearanceStore()
        let failedPrivacy = TrackerPrivacy(storage: failing, authentication: FixedDeviceAuthentication(),
                                           exports: ProtectedExportFiles(directory: root.appendingPathComponent("other")), delivery: MemoryReminderDelivery())
        failedPrivacy.start()
        failing.fail = true
        #expect(failedPrivacy.setAppearance(.dark) != nil)
        #expect(failedPrivacy.preferences == PrivacyPreferences())
    }

    @Test func logoutSurvivesReloadAndPreservesRecordsUntilSameAccountReconnects() async throws {
        let today = try LocalDay(key: 20260929)
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add([Period(start: today)], completingOnboarding: true, today: today, now: today.formattingDate)
        var profile = LocalProfile(); profile.preferredName = "Synthetic"; profile.birthDayKey = 19950512
        let original = try repository.saveProfile(profile, today: today)
        let store = MemoryAppleIdentityStore()
        let account = AppleAccount(store: store)
        try account.link(userID: "synthetic-owner", profileID: profile.id, protectsExistingProfile: true)
        let session = TrackerSession(repository: { repository }, clock: { today.formattingDate }, account: account)
        session.load()
        #expect(session.logOut() == nil)
        #expect(account.requiresSignIn && session.snapshot == TrackerSnapshot() && session.overview == nil)
        #expect(try repository.load() == original)
        session.load()
        #expect(session.snapshot == TrackerSnapshot())
        #expect(session.saveProfile(profile) != nil)
        #expect(session.update(original.periods[0]) != nil)
        let reopened = AppleAccount(store: store, checksAppleCredentials: true)
        #expect(reopened.state == .signedOut && reopened.requiresSignIn)
        await reopened.checkCredentialState()
        #expect(reopened.state == .signedOut)
        #expect(throws: ProfileError.self) {
            try reopened.link(userID: "different-account", profileID: profile.id, protectsExistingProfile: false)
        }
        try account.link(userID: "synthetic-owner", profileID: profile.id, protectsExistingProfile: true)
        session.load()
        #expect(session.snapshot == original && !account.requiresSignIn)
        #expect(session.logOut() == nil)
        #expect(await session.deleteAllAndWait() == nil)
        #expect(try repository.load() == TrackerSnapshot())
        #expect(account.identity == nil && !account.requiresSignIn)
    }

    @Test func failedLogoutAndUnreadableBindingDoNotPretendSuccess() throws {
        let store = FailingIdentityStore()
        let account = AppleAccount(store: store)
        let id = UUID()
        try account.link(userID: "synthetic", profileID: id, protectsExistingProfile: false)
        store.failSave = true
        #expect(throws: FailingIdentityStore.Failure.self) { try account.signOut() }
        #expect(account.state == .authorized && !account.requiresSignIn)
        store.failSave = false
        try account.signOut()
        store.failLoad = true
        let unreadable = AppleAccount(store: store)
        #expect(unreadable.requiresSignIn && !unreadable.identityLoaded)
        #expect(throws: FailingIdentityStore.Failure.self) {
            try unreadable.link(userID: "different", profileID: id, protectsExistingProfile: false)
        }
    }
}