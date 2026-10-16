import Foundation
import Testing
@testable import cecy

nonisolated struct P1RoadmapDomainTests {
    private let today = try! LocalDay(key: 20261015)
    private let now = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!

    @Test func factorExclusionIsExplicitAndKeepsRawIntervals() throws {
        let periods = try [20260701, 20260729, 20260826, 20260923].map { Period(start: try LocalDay(key: $0)) }
        let factor = CycleFactor(kind: .postpartum, start: try LocalDay(key: 20260720), end: try LocalDay(key: 20260805))
        let overview = CycleCalculator.overview(periods: periods, today: today, factors: [factor])
        #expect(overview.intervals.count == 1)
        #expect(overview.excludedIntervals.count == 2)
        #expect(overview.excludedIntervals.first?.start == periods[0].start)
        #expect(periods.count == 4)
    }

    @Test func dailyCheckInCopiesYesterdayOnlyIntoExplicitDraft() throws {
        let yesterday = try today.adding(days: -1)
        let snapshot = TrackerSnapshot(symptoms: [SymptomEntry(day: yesterday, kind: .cramps, value: 2)],
            dailyBleeding: [DailyBleedingObservation(day: yesterday, state: .spotting)])
        var update = DailyCheckInUpdate(day: today, snapshot: snapshot)
        update.copyAnswers(from: snapshot, previousDay: yesterday)
        #expect(update.hasChanges)
        #expect(update.bleeding?.day == today && update.bleeding?.state == .spotting)
        #expect(update.symptoms.first?.day == today && update.symptoms.first?.kind == .cramps)
        #expect(snapshot.symptoms.first?.day == yesterday)
    }

    @Test @MainActor func reportFormatsAreLocalReadableAndCoverageAware() throws {
        let snapshot = TrackerSnapshot(periods: [Period(start: try LocalDay(key: 20261001))],
            symptoms: [SymptomEntry(day: today, kind: .headache)],
            cycleFactors: [CycleFactor(kind: .stress, start: today)],
            treatments: [TreatmentRecord(category: .medication, name: "Example", start: today)])
        var options = AppointmentSummaryOptions()
        options.trends = true; options.treatments = true
        options.concerns = ["Discuss a change"]
        let document = try AppointmentSummary.document(snapshot: snapshot, start: try LocalDay(key: 20261001), end: today, options: options)
        #expect(document.sections.contains { $0.kind == .trends })
        #expect(document.sections.contains { $0.kind == .treatments })
        #expect(String(data: AppointmentReportCSV.encode(document), encoding: .utf8)?.contains("Discuss a change") == true)
        #expect(AppointmentReportPDF.encode(document).starts(with: Data("%PDF".utf8)))
    }

    @Test func reminderPlannerAddsUsefulPromptsAndHonorsSnooze() throws {
        var preferences = PrivacyPreferences()
        preferences.periodFollowUpReminder = true
        preferences.symptomReminderKinds = [.cramps]
        preferences.missedLogReminder = true
        let period = Period(start: today)
        let treatment = TreatmentRecord(category: .medication, name: "Example", start: today, reminderEnabled: true)
        let requests = try ReminderPlanner.requests(preferences: preferences, prediction: nil, now: now,
            timeZone: .gmt, periods: [period], treatments: [treatment])
        #expect(requests.contains { $0.kind == .periodStarted })
        #expect(requests.contains { $0.kind == .symptom })
        #expect(requests.contains { $0.kind == .missedLog })
        #expect(requests.contains { $0.kind == .treatment })
        #expect(requests.filter { $0.kind != .window }.allSatisfy { $0.deepLink == "cecy://check-in" })
        preferences.remindersSnoozedUntilDay = try today.adding(days: 1).key
        let snoozed = try ReminderPlanner.requests(preferences: preferences, prediction: nil, now: now,
            timeZone: .gmt, periods: [], treatments: [treatment])
        #expect(!snoozed.contains { [.symptom, .missedLog, .treatment].contains($0.kind) })
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        let resumed = try ReminderPlanner.requests(preferences: preferences, prediction: nil, now: tomorrow,
            timeZone: .gmt, periods: [], treatments: [treatment])
        #expect(resumed.contains { $0.kind == .symptom })
        #expect(resumed.contains { $0.kind == .missedLog })
        #expect(resumed.contains { $0.kind == .treatment })
    }

    @Test func exportImportRoundTripDeduplicatesAndPreservesP1Records() throws {
        let timestamp = now.addingTimeInterval(0.123456789)
        let treatment = TreatmentRecord(category: .contraception, name: "Pill", contraceptionType: .pill,
            start: today, createdAt: timestamp, updatedAt: timestamp)
        let original = TrackerSnapshot(periods: [Period(start: try LocalDay(key: 20261001), createdAt: timestamp, updatedAt: timestamp)],
            symptoms: [SymptomEntry(day: today, kind: .cramps, createdAt: timestamp, updatedAt: timestamp)],
            dailyBleeding: [DailyBleedingObservation(day: today, state: .noBleeding, createdAt: timestamp, updatedAt: timestamp)],
            cycleFactors: [CycleFactor(kind: .stress, start: today, createdAt: timestamp, updatedAt: timestamp)], treatments: [treatment],
            treatmentAdherence: [TreatmentAdherence(treatmentID: treatment.id, day: today, state: .taken,
                                                     createdAt: timestamp, updatedAt: timestamp)])
        let data = try TrackerExport.encode(snapshot: original, includeNotes: true, generatedAt: now)
        let imported = try TrackerImport.preview(data: data, existing: TrackerSnapshot(), today: today, strategy: .useImported)
        #expect(imported.formatVersion == 8)
        #expect(imported.snapshot.periods.first?.createdAt == original.periods.first?.createdAt)
        #expect(imported.snapshot.periods.first?.updatedAt == original.periods.first?.updatedAt)
        #expect(imported.snapshot.treatments.first?.createdAt == original.treatments.first?.createdAt)
        #expect(imported.snapshot.treatments.first?.updatedAt == original.treatments.first?.updatedAt)
        #expect(imported.snapshot.periods == original.periods)
        #expect(imported.snapshot.treatments == original.treatments)
        #expect(imported.snapshot.treatmentAdherence == original.treatmentAdherence)
        let duplicate = try TrackerImport.preview(data: data, existing: imported.snapshot, today: today, strategy: .keepExisting)
        #expect(duplicate.added == 0)
        #expect(duplicate.duplicates >= 6)
    }
}

@MainActor struct P1RoadmapRepositoryTests {
    private let today = try! LocalDay(key: 20261015)
    private var now: Date { today.formattingDate }

    @Test func onboardingProgressAndP1RecordsSurviveReload() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        var draft = OnboardingDraft()
        draft.profile.preferredName = "Alex"
        let progress = OnboardingProgress(draft: draft, stepID: "2", updatedAt: now)
        _ = try repository.saveOnboardingProgress(progress, today: today)
        let treatment = TreatmentRecord(category: .contraception, name: "Ring", contraceptionType: .ring, start: today)
        _ = try repository.saveTreatment(treatment, today: today, now: now)
        let saved = try repository.saveTreatmentAdherence(TreatmentAdherence(treatmentID: treatment.id, day: today, state: .late),
                                                            today: today, now: now)
        #expect(saved.onboardingProgress == progress)
        #expect(saved.cycleFactors.first?.id == treatment.id)
        #expect(saved.cycleFactors.first?.kind == .hormonalContraception)
        #expect(try repository.load() == saved)
    }

    @Test func failedImportRollsBackWholeSnapshot() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        let original = try repository.add([Period(start: today)], completingOnboarding: true, today: today, now: now)
        var invalid = original
        invalid.periods.append(Period(start: today))
        #expect(throws: TrackingError.duplicateStart) { try repository.importSnapshot(invalid, today: today) }
        #expect(try repository.load() == original)
    }
}
