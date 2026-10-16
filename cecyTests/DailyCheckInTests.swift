import Foundation
import SwiftData
import Testing
@testable import cecy

nonisolated struct DailyCheckInDomainTests {
    private let day = try! LocalDay(key: 20261015)

    @Test func suggestionsPrioritizeProfileChoicesAndKeepExistingSymptomsVisible() {
        var profile = LocalProfile()
        profile.commonSymptoms = [.nausea, .cramps]
        let existing = [SymptomEntry(day: day, kind: .hotFlashes)]
        #expect(DailyCheckInSuggestions.symptoms(profile: profile, existing: existing) == [.cramps, .nausea, .hotFlashes])
        #expect(DailyCheckInSuggestions.symptoms(profile: nil, existing: []).contains(.moodChanges))
        #expect(DailyCheckInSuggestions.symptoms(profile: nil, existing: []).contains(.energyLevel))
    }

    @Test func updatePreservesExistingIdentityAndOptionalDetails() {
        let created = Date(timeIntervalSince1970: 1_000)
        let answer = DailyBleedingObservation(day: day, state: .unsure, createdAt: created)
        let symptom = SymptomEntry(day: day, kind: .headache, value: 1, notes: "Private", createdAt: created)
        var update = DailyCheckInUpdate(day: day, snapshot: TrackerSnapshot(symptoms: [symptom], dailyBleeding: [answer]))
        #expect(update.hasAnswer && !update.hasChanges)
        update.setBleeding(.bleeding, flow: .heavy)
        update.setSymptom(.headache, selected: false)
        update.setSymptom(.headache, selected: true)
        update.setRating(3, for: .headache)
        #expect(update.bleeding?.id == answer.id && update.bleeding?.flow == .heavy)
        #expect(update.symptoms.first?.id == symptom.id)
        #expect(update.symptoms.first?.notes == "Private" && update.symptoms.first?.value == 3)
        #expect(update.hasChanges)
    }
}

@MainActor struct DailyCheckInRepositoryTests {
    private let today = try! LocalDay(key: 20261015)
    private var now: Date { today.formattingDate }
    private enum Failure: Error { case disk }

    @Test func checkInAtomicallyReplacesOnlyTheSelectedDay() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let priorDay = try today.adding(days: -1)
        let prior = SymptomEntry(day: priorDay, kind: .fatigue, createdAt: now)
        _ = try repository.saveSymptom(prior, editing: false, today: today, now: now)
        let originalSymptom = SymptomEntry(day: today, kind: .headache, value: 1, notes: "Keep privately", createdAt: now)
        _ = try repository.saveSymptom(originalSymptom, editing: false, today: today, now: now)
        let originalBleeding = DailyBleedingObservation(day: today, state: .unsure, createdAt: now)
        let original = try repository.saveDailyBleeding(originalBleeding, editing: false, today: today, now: now)

        var update = DailyCheckInUpdate(day: today, snapshot: original)
        update.setBleeding(.bleeding, flow: .moderate)
        update.setSymptom(.headache, selected: false)
        update.setSymptom(.cramps, selected: true)
        update.setRating(2, for: .cramps)
        let later = now.addingTimeInterval(60)
        let saved = try repository.saveDailyCheckIn(update, today: today, now: later)

        #expect(saved.symptoms.contains(prior))
        #expect(saved.symptoms.first(where: { $0.day == today })?.kind == .cramps)
        #expect(saved.symptoms.first(where: { $0.day == today })?.value == 2)
        #expect(saved.dailyBleeding.first?.id == originalBleeding.id)
        #expect(saved.dailyBleeding.first?.createdAt == now && saved.dailyBleeding.first?.updatedAt == later)
        #expect(saved.dailyBleeding.first?.state == .bleeding && saved.dailyBleeding.first?.flow == .moderate)
        #expect(try repository.load() == saved)
    }

    @Test func staleAndEmptyUpdatesNeverChangeStorage() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let empty = try repository.load()
        let emptyUpdate = DailyCheckInUpdate(day: today, snapshot: empty)
        #expect(throws: DailyCheckInError.empty) {
            try repository.saveDailyCheckIn(emptyUpdate, today: today, now: now)
        }

        var stale = DailyCheckInUpdate(day: today, snapshot: empty)
        stale.setSymptom(.cramps, selected: true)
        let current = try repository.saveSymptom(SymptomEntry(day: today, kind: .headache), editing: false, today: today, now: now)
        #expect(throws: DailyCheckInError.stale) {
            try repository.saveDailyCheckIn(stale, today: today, now: now)
        }
        #expect(try repository.load() == current)
    }

    @Test func failedCombinedSaveRollsBackEveryRecordAndCanRetry() throws {
        let memory = try SwiftDataPeriodRepository.inMemory()
        var fail = true
        let repository = SwiftDataPeriodRepository(container: memory.container, save: {
            if fail { throw Failure.disk }
            try $0.save()
        })
        var update = DailyCheckInUpdate(day: today, snapshot: try repository.load())
        update.setBleeding(.spotting)
        update.setSymptom(.cramps, selected: true)
        #expect(throws: Failure.disk) { try repository.saveDailyCheckIn(update, today: today, now: now) }
        #expect(try repository.load() == TrackerSnapshot())
        fail = false
        let saved = try repository.saveDailyCheckIn(update, today: today, now: now)
        #expect(saved.dailyBleeding.count == 1 && saved.symptoms.count == 1)
    }
}
