import Foundation
import Testing
@testable import cecy

nonisolated struct AppointmentSummaryTests {
    let end = try! LocalDay(key: 20261007)

    @Test func structuredPreviewPreservesExactPlainTextExport() throws {
        var options = AppointmentSummaryOptions()
        options.symptoms = true
        options.context = true
        let document = try AppointmentSummary.document(snapshot: TrackerSnapshot(), start: end, end: end, options: options)
        #expect(document.sections.map(\.kind) == [.dailyAnswers, .periods, .symptoms, .context])
        let expected = """
        Cecy · Appointment summary
        2026-10-07 – 2026-10-07
        Saved entries only. Records may be incomplete; not a medical interpretation.

        DAILY ANSWERS
        Days logged: 0 of 1
        Not logged: 1
        Bleeding: 0
        Spotting: 0
        No bleeding: 0
        Not sure: 0
        Not logged does not mean no bleeding. Not sure is a recorded uncertain answer.
        No daily answers recorded in this range.

        RECORDED PERIODS
        Periods overlapping these dates; original dates shown. Daily answers are counted separately.
        No periods recorded in this range.
        No completed start-to-start intervals within these dates.
        Unknown ends and the current open interval are not assumed complete.

        SYMPTOMS AND WELLNESS
        0 entries on 0 days.
        No symptom entries recorded in this range.

        CURRENT SELF-REPORTED CONTEXT
        Current profile answers, not a dated history or diagnosis.
        No profile context recorded.
        """ + "\n"
        #expect(document.text == expected)
        #expect(try AppointmentSummary.text(snapshot: TrackerSnapshot(), start: end, end: end, options: options) == expected)
    }

    @Test func structuredPreviewKeepsSelectedNotesLiteralAndInTheirSection() throws {
        let note = "First line\n\nDAILY ANSWERS\n**Private note**"
        let snapshot = TrackerSnapshot(periods: [Period(start: end, notes: note)])
        var options = AppointmentSummaryOptions()
        options.dailyAnswers = false
        let withoutNotes = try AppointmentSummary.document(snapshot: snapshot, start: end, end: end, options: options)
        #expect(withoutNotes.sections.map(\.kind) == [.periods])
        #expect(!withoutNotes.text.contains("Private note"))
        options.notes = true
        let selected = try AppointmentSummary.document(snapshot: snapshot, start: end, end: end, options: options)
        #expect(selected.sections.count == 1)
        #expect(selected.sections[0].lines.contains("Note: \(note)"))
        #expect(selected.text.contains("Note: \(note)"))
    }

    @Test func coverageSeparatesAllStatesAndDoesNotInferFromPeriodsOrSymptoms() throws {
        let start = try end.adding(days: -6)
        let daily = try DailyBleedingState.allCases.enumerated().map {
            DailyBleedingObservation(day: try end.adding(days: -$0.offset), state: $0.element)
        }
        let snapshot = TrackerSnapshot(periods: [Period(start: start, end: try start.adding(days: 1))],
            symptoms: [SymptomEntry(day: try start.adding(days: 2), kind: .cramps)], dailyBleeding: daily)
        let coverage = try RecordingCoverage(snapshot: snapshot, start: start, end: end)
        #expect(coverage.totalDays == 7 && coverage.loggedDays == 4 && coverage.unloggedDays == 3)
        #expect(DailyBleedingState.allCases.allSatisfy { coverage.count($0) == 1 })
        #expect(try RecordingCoverage(snapshot: snapshot, start: end, end: end).loggedDays == 1)
        #expect(throws: TrackingError.invalidData) { try RecordingCoverage(snapshot: snapshot, start: end, end: start) }
    }

    @Test func defaultSummaryOmitsIdentityNotesActivityContextAndSymptoms() throws {
        var profile = LocalProfile(); profile.preferredName = "PRIVATE IDENTITY"; profile.birthDayKey = 19950101
        profile.cycleContext = [.breastfeeding]
        let snapshot = TrackerSnapshot(periods: [Period(start: end, notes: "PRIVATE NOTE")],
            symptoms: [SymptomEntry(day: end, kind: .headache, notes: "PRIVATE SYMPTOM")], profile: profile,
            sexualActivities: [SexualActivityEntry(day: end, activities: [.other], notes: "PRIVATE SEX")],
            dailyBleeding: [DailyBleedingObservation(day: end, state: .bleeding)])
        let text = try AppointmentSummary.text(snapshot: snapshot, start: end, end: end, options: .init())
        #expect(!text.contains("PRIVATE") && !text.contains("Breastfeeding") && !text.contains("Headache"))
        #expect(!text.contains(snapshot.periods[0].id.uuidString) && !text.contains("1995"))
        #expect(text.contains("end not recorded") && text.contains("Days logged: 1 of 1"))
        var options = AppointmentSummaryOptions(); options.symptoms = true; options.context = true; options.notes = true
        let selected = try AppointmentSummary.text(snapshot: snapshot, start: end, end: end, options: options)
        #expect(selected.contains("PRIVATE NOTE") && selected.contains("PRIVATE SYMPTOM") && selected.contains("Breastfeeding"))
        #expect(!selected.contains("PRIVATE IDENTITY") && !selected.contains("PRIVATE SEX"))
        options.periods = false; options.symptoms = false
        let excluded = try AppointmentSummary.text(snapshot: snapshot, start: end, end: end, options: options)
        #expect(!excluded.contains("PRIVATE NOTE") && !excluded.contains("PRIVATE SYMPTOM"))
    }

    @Test func summaryIsStableSortedAndRangeBoundedWithNoPredictions() throws {
        let start = try end.adding(days: -29)
        let before = try start.adding(days: -1)
        let periods = [Period(start: end), Period(start: start), Period(start: before)]
        let snapshot = TrackerSnapshot(periods: periods,
            dailyBleeding: [DailyBleedingObservation(day: before, state: .bleeding), DailyBleedingObservation(day: end, state: .unsure)])
        let text = try AppointmentSummary.text(snapshot: snapshot, start: start, end: end, options: .init())
        var reordered = snapshot; reordered.periods.reverse(); reordered.dailyBleeding.reverse()
        #expect(text == (try AppointmentSummary.text(snapshot: reordered, start: start, end: end, options: .init())))
        #expect(text.contains("Days logged: 1 of 30") && text.contains("Not logged: 29"))
        #expect(text.contains("1 completed start-to-start intervals within these dates: 29 days."))
        #expect(!text.contains("ovulation") && !text.contains("fertile") && !text.contains("2026-09-07:"))
    }

    @Test func leapDayCoverageAndEmptySectionsRemainHonest() throws {
        let start = try LocalDay(key: 20240228), end = try LocalDay(key: 20240301)
        let text = try AppointmentSummary.text(snapshot: TrackerSnapshot(), start: start, end: end, options: .init())
        #expect(text.contains("Days logged: 0 of 3") && text.contains("Not logged: 3"))
        #expect(text.contains("No periods recorded") && text.contains("No daily answers recorded"))
        var options = AppointmentSummaryOptions(); options.periods = false; options.dailyAnswers = false
        #expect(throws: TrackingError.invalidData) {
            try AppointmentSummary.text(snapshot: TrackerSnapshot(), start: start, end: end, options: options)
        }
    }
}

@MainActor struct AppointmentSummaryExportTests {
    @Test func textExportUsesProtectedDirectoryAndRemovesPreviousFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = ProtectedExportFiles(directory: directory)
        let json = try files.prepare(Data("{}".utf8))
        let data = Data("Synthetic preview\n".utf8)
        let summary = try files.prepareSummary(data)
        #expect(summary.lastPathComponent == "Cecy-summary.txt")
        #expect(!FileManager.default.fileExists(atPath: json.path))
        #expect(try Data(contentsOf: summary) == data)
        #expect(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        try files.clean()
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func privacyGatesSharingAndCleansSummaryOnBackgroundAndReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let privacy = TrackerPrivacy(storage: MemoryPrivacyPreferences(), authentication: SummaryAuthentication(),
            exports: ProtectedExportFiles(directory: directory), delivery: MemoryReminderDelivery())
        privacy.exportSummary("Synthetic")
        #expect(privacy.preparedExport == nil)
        privacy.start()
        privacy.exportSummary("Reviewed text")
        let url = try #require(privacy.preparedExport?.url)
        #expect(try String(contentsOf: url, encoding: .utf8) == "Reviewed text")
        privacy.wentToBackground()
        #expect(privacy.preparedExport == nil && !FileManager.default.fileExists(atPath: url.path))
        privacy.exportSummary("Reviewed again")
        try privacy.prepareForReset()
        #expect(privacy.preparedExport == nil && !FileManager.default.fileExists(atPath: directory.path))
    }
}

@MainActor private final class SummaryAuthentication: DeviceAuthenticating {
    func authenticate(reason: String) async -> Bool { true }
    func cancel() { }
}
