import Foundation
import SwiftData
import Testing
@testable import cecy

/// Synthetic data only.
nonisolated struct P2RoadmapDomainTests {
    private let today = try! LocalDay(key: 20261015)
    private let now = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!
    private func day(_ key: Int) -> LocalDay { try! LocalDay(key: key) }
    private let periods: [Period] = [20260601, 20260629, 20260727, 20260824, 20260921].map { Period(start: try! LocalDay(key: $0)) }

    private func isAvailable(_ overview: CycleOverview) -> Bool {
        if case .available = overview.prediction { return true }
        return false
    }

    // MARK: P2.1 / P2.2

    @Test func postpartumStageIsAVisibleReversibleForecastExclusion() throws {
        var snapshot = TrackerSnapshot(periods: periods)
        let baseline = CycleCalculator.overview(periods: snapshot.periods, today: today, factors: P2Forecast.factors(for: snapshot))
        snapshot.p2.lifeStages = [LifeStageEpisode(kind: .postpartum, start: day(20260705), end: day(20260810))]
        let excluded = CycleCalculator.overview(periods: snapshot.periods, today: today, factors: P2Forecast.factors(for: snapshot))
        #expect(baseline.excludedIntervals.isEmpty)
        #expect(excluded.excludedIntervals.count == 2)
        #expect(excluded.intervals.count + excluded.excludedIntervals.count == baseline.intervals.count)
        #expect(isAvailable(baseline) && isAvailable(excluded), "A middle exclusion must not remove the forecast.")
        #expect(excluded.latestStart == baseline.latestStart)
        #expect(snapshot.periods == periods)
        snapshot.p2.lifeStages[0].forecastExclusion = false
        let restored = CycleCalculator.overview(periods: snapshot.periods, today: today, factors: P2Forecast.factors(for: snapshot))
        #expect(restored == baseline)
    }

    @Test func ongoingPostpartumStageKeepsForecastFromEarlierEvidence() throws {
        var snapshot = TrackerSnapshot(periods: periods)
        snapshot.p2.lifeStages = [LifeStageEpisode(kind: .postpartum, start: day(20260901))]
        let overview = CycleCalculator.overview(periods: snapshot.periods, today: today, engine: EvidencePredictionEngine(),
                                                factors: P2Forecast.factors(for: snapshot))
        #expect(overview.excludedIntervals.map(\.start) == [day(20260824)])
        #expect(overview.intervals.map(\.length) == [28, 28, 28])
        #expect(isAvailable(overview), "An exclusion covering the latest interval must not remove the forecast.")
        if case .available(let prediction) = overview.prediction { #expect(prediction.sourceLengths == [28, 28, 28]) }
    }

    @Test func cycleChangeStaysIncludedByDefault() {
        let episode = LifeStageEpisode(kind: .cycleChange, start: day(20260101))
        #expect(!episode.excludesFromForecast)
        #expect(LifeStageEpisode(kind: .breastfeeding, start: day(20260101)).excludesFromForecast)
        let snapshot = TrackerSnapshot(periods: periods, p2: P2Data(lifeStages: [episode]))
        #expect(P2Forecast.factors(for: snapshot).isEmpty)
    }

    @Test func postpartumBleedingNeverBecomesAPeriodOrChangesForecast() throws {
        let stage = LifeStageEpisode(kind: .postpartum, start: day(20261001), forecastExclusion: false)
        let base = TrackerSnapshot(periods: periods, p2: P2Data(lifeStages: [stage]))
        var withBleeding = base
        withBleeding.p2.postpartumBleeding = [
            PostpartumBleedingEntry(day: day(20261002), state: .bleeding, flow: .heavy),
            PostpartumBleedingEntry(day: day(20261003), state: .lochia)
        ]
        try P2RecordValidation.validate(withBleeding.p2, asOf: today)
        let before = CycleCalculator.overview(periods: base.periods, today: today, factors: P2Forecast.factors(for: base))
        let after = CycleCalculator.overview(periods: withBleeding.periods, today: today, factors: P2Forecast.factors(for: withBleeding))
        #expect(before == after)
        #expect(withBleeding.periods.count == periods.count)
    }

    @Test func postpartumBleedingRequiresPostpartumContextAndValidFlow() {
        let orphan = P2Data(postpartumBleeding: [PostpartumBleedingEntry(day: today, state: .lochia)])
        #expect(throws: TrackingError.invalidData) { try P2RecordValidation.validate(orphan) }
        let stage = LifeStageEpisode(kind: .postpartum, start: today)
        let lochiaWithFlow = P2Data(lifeStages: [stage],
            postpartumBleeding: [PostpartumBleedingEntry(day: today, state: .lochia, flow: .light)])
        #expect(throws: TrackingError.invalidData) { try P2RecordValidation.validate(lochiaWithFlow) }
        let future = P2Data(lifeStages: [LifeStageEpisode(kind: .cycleChange, start: day(20261020))])
        #expect(throws: TrackingError.futureDate) { try P2RecordValidation.validate(future, asOf: today) }
        let feedingOnWrongKind = P2Data(lifeStages: [LifeStageEpisode(kind: .cycleChange, start: today, feedingContext: .formula)])
        #expect(throws: TrackingError.invalidData) { try P2RecordValidation.validate(feedingOnWrongKind) }
    }

    @Test func lifeStageSummaryDescribesCoverageWithoutPrediction() throws {
        let stage = LifeStageEpisode(kind: .postpartum, start: day(20260701))
        let snapshot = TrackerSnapshot(periods: periods,
            symptoms: [SymptomEntry(day: day(20260710), kind: .fatigue), SymptomEntry(day: day(20260711), kind: .fatigue),
                       SymptomEntry(day: day(20260710), kind: .headache)],
            dailyBleeding: [DailyBleedingObservation(day: day(20260712), state: .noBleeding)],
            p2: P2Data(lifeStages: [stage], postpartumBleeding: [PostpartumBleedingEntry(day: day(20260702), state: .lochia)]))
        let summary = LifeStageSummary.make(episode: stage, snapshot: snapshot, through: today)
        #expect(summary.firstPeriodAfterStart == day(20260727))
        #expect(summary.relevantSymptoms == [SymptomCount(kind: .fatigue, count: 2)])
        #expect(summary.postpartumBleedingDays == 1)
        #expect(summary.dailyAnswerDays == 1)
        let lines = summary.observations(format: { String($0.key) })
        #expect(lines.contains { $0.contains("20260727") })
        #expect(lines.contains { $0.contains("unknown") })
        #expect(!lines.joined().localizedCaseInsensitiveContains("expected"))
    }

    @Test func cycleChangeComparesIntervalsOnlyWithEnoughEvidence() {
        let starts = [20260101, 20260129, 20260226, 20260326, 20260501, 20260610, 20260725].map { Period(start: day($0)) }
        let stage = LifeStageEpisode(kind: .cycleChange, start: day(20260401))
        let summary = LifeStageSummary.make(episode: stage, snapshot: TrackerSnapshot(periods: starts), through: today)
        #expect(summary.intervalsBefore == [28, 28, 28])
        #expect(summary.intervalsDuring == [40, 45])
        #expect(summary.observations(format: { _ in "" }).contains { $0.contains("28–28") && $0.contains("40–45") })
        let sparse = LifeStageSummary.make(episode: stage, snapshot: TrackerSnapshot(periods: Array(starts.prefix(2))), through: today)
        #expect(sparse.observations(format: { _ in "" }).contains { $0.contains("At least two") })
    }

    @Test func activeLifeStageTailorsCheckInSymptoms() {
        let data = P2Data(lifeStages: [LifeStageEpisode(kind: .cycleChange, start: day(20260901))])
        let tailored = LifeStageCheckIn.symptoms(for: data, on: today)
        #expect(tailored.first == .hotFlashes)
        var preferences = CheckInPreferences()
        preferences.pinnedSymptoms = [.cramps]
        preferences.hiddenSymptoms = [.nightSweats]
        let ordered = DailyCheckInSuggestions.symptoms(profile: nil, existing: [], preferences: preferences, lifeStage: tailored)
        #expect(ordered.prefix(2) == [.cramps, .hotFlashes])
        #expect(!ordered.contains(.nightSweats))
        let ended = P2Data(lifeStages: [LifeStageEpisode(kind: .cycleChange, start: day(20260101), end: day(20260201))])
        #expect(LifeStageCheckIn.symptoms(for: ended, on: today).isEmpty)
    }

    // MARK: P2.3

    @Test func biomarkersNeverChangeTheForecast() throws {
        let base = TrackerSnapshot(periods: periods)
        var withMarkers = base
        withMarkers.p2.biomarkers = [
            BiomarkerEntry(day: day(20261005), kind: .lhTest, result: .positive),
            BiomarkerEntry(day: day(20261006), kind: .basalBodyTemperature, numericValue: 36.9),
            BiomarkerEntry(day: day(20261007), kind: .pregnancyTest, result: .positive)
        ]
        try P2RecordValidation.validate(withMarkers.p2, asOf: today)
        let before = CycleCalculator.overview(periods: base.periods, today: today, factors: P2Forecast.factors(for: base))
        let after = CycleCalculator.overview(periods: withMarkers.periods, today: today, factors: P2Forecast.factors(for: withMarkers))
        #expect(before == after)
        let forecastBefore = CycleForecast.calculate(overview: before, profile: nil, periods: base.periods, asOf: today, dailyBleeding: [])
        let forecastAfter = CycleForecast.calculate(overview: after, profile: nil, periods: withMarkers.periods, asOf: today, dailyBleeding: [])
        #expect(forecastBefore == forecastAfter)
    }

    @Test(arguments: [
        (BiomarkerKind.basalBodyTemperature, 29.9, true), (.basalBodyTemperature, 36.5, false), (.basalBodyTemperature, Double.nan, true),
        (.restingHeartRate, 251, true), (.restingHeartRate, 60, false), (.sleepDuration, 24.5, true), (.sleepDuration, 7.5, false)
    ])
    func numericBiomarkerRangesFailClosed(kind: BiomarkerKind, value: Double, rejected: Bool) {
        let data = P2Data(biomarkers: [BiomarkerEntry(day: today, kind: kind, numericValue: value)])
        if rejected { #expect(throws: TrackingError.invalidData) { try P2RecordValidation.validate(data) } }
        else { #expect(throws: Never.self) { try P2RecordValidation.validate(data) } }
    }

    @Test func categoricalBiomarkersAcceptOnlyTheirOwnResults() {
        let mucusAsTest = P2Data(biomarkers: [BiomarkerEntry(day: today, kind: .lhTest, result: .eggWhite)])
        #expect(throws: TrackingError.invalidData) { try P2RecordValidation.validate(mucusAsTest) }
        let numberForTest = P2Data(biomarkers: [BiomarkerEntry(day: today, kind: .pregnancyTest, numericValue: 1, result: .negative)])
        #expect(throws: TrackingError.invalidData) { try P2RecordValidation.validate(numberForTest) }
        let valid = P2Data(biomarkers: [BiomarkerEntry(day: today, kind: .cervicalMucus, result: .eggWhite)])
        #expect(throws: Never.self) { try P2RecordValidation.validate(valid) }
    }

    @Test func temperatureUnitsRoundTripAndTrendsReportCoverage() {
        let kind = BiomarkerKind.basalBodyTemperature
        #expect(abs(kind.displayValue(37, system: .imperial) - 98.6) < 0.0001)
        #expect(abs(kind.storedValue(98.6, system: .imperial) - 37) < 0.0001)
        #expect(kind.displayValue(37, system: .metric) == 37)
        #expect(BiomarkerKind.restingHeartRate.storedValue(60, system: .imperial) == 60)
        let entries = [BiomarkerEntry(day: day(20261010), kind: kind, numericValue: 36.4),
                       BiomarkerEntry(day: day(20261012), kind: kind, numericValue: 36.8),
                       BiomarkerEntry(day: day(20250101), kind: kind, numericValue: 40)]
        let trend = BiomarkerTrend.make(kind: kind, entries: entries, through: today, days: 30)
        #expect(trend.points.count == 2 && trend.recordedDays == 2 && trend.totalDays == 30)
        #expect(trend.minimum == 36.4 && trend.maximum == 36.8)
        #expect(trend.summary(system: .metric).contains("2 of 30"))
    }

    // MARK: P2.5 / P2.4

    @Test func everyArticleCarriesProvenanceAndIsLabeledUntilReviewed() {
        #expect(EducationCatalog.articles.count >= 8)
        #expect(Set(EducationCatalog.articles.map(\.id)).count == EducationCatalog.articles.count)
        for article in EducationCatalog.articles {
            #expect(!article.references.isEmpty && !article.emergencyBoundary.isEmpty && !article.jurisdiction.isEmpty)
            #expect(!article.author.isEmpty && !article.reviewer.isEmpty)
            #expect(!article.isClinicallyReviewed, "Articles must stay labeled as drafts until a named clinician signs off.")
        }
        for stage in LifeStageKind.allCases {
            #expect(EducationCatalog.articles(for: stage).count == stage.educationIDs.count)
        }
        #expect(EducationCatalog.search("lochia").map(\.id) == ["postpartum"])
        #expect(EducationCatalog.search("  ").count == EducationCatalog.articles.count)
    }

    @Test func onlyReviewFirstAppleCapabilitiesAreEnabled() {
        #expect(AppleEcosystemCapability.allCases.filter(\.isEnabledInThisBuild) == [.appIntents])
        #expect(!AppleEcosystemCapability.healthWriteBack.isEnabledInThisBuild)
    }

    // MARK: P2.7

    @Test func dismissedInsightsHideUntilEvidenceChangesAndMaterialChangesRankFirst() {
        func insight(_ id: String, _ category: InsightCategory, _ evidence: InsightEvidence, recent: [Int]) -> CycleInsight {
            CycleInsight(id: id, category: category, title: id, explanation: "", evidence: evidence, generatedDay: today,
                         rangeStart: day(20260101), rangeEnd: today, sourceIDs: [], previousValues: [28, 28, 28], recentValues: recent)
        }
        let timing = insight("v1.timing.cramps", .symptomTiming, .repeated, recent: [])
        let length = insight("v1.cycleLength", .cycleLength, .limited, recent: [33, 34, 35])
        let arranged = InsightQuality.arrange([timing, length], feedback: [])
        #expect(arranged.visible.map(\.id) == ["v1.cycleLength", "v1.timing.cramps"])
        let dismissed = InsightFeedback(insightID: InsightQuality.fingerprint(length), helpful: false, reasons: [.repetitive], updatedAt: now)
        let hidden = InsightQuality.arrange([timing, length], feedback: [dismissed])
        #expect(hidden.visible.map(\.id) == ["v1.timing.cramps"])
        #expect(hidden.hidden.map(\.id) == ["v1.cycleLength"])
        let changed = insight("v1.cycleLength", .cycleLength, .limited, recent: [33, 34, 40])
        #expect(InsightQuality.arrange([changed], feedback: [dismissed]).visible.count == 1)
        let helpful = InsightFeedback(insightID: InsightQuality.fingerprint(length), helpful: true, reasons: [], updatedAt: now)
        #expect(InsightQuality.arrange([length], feedback: [helpful]).hidden.isEmpty)
    }

    // MARK: Portability and reports

    @Test func v9ExportImportRoundTripsExactlyAndHonorsNotesChoice() throws {
        let stamp = now.addingTimeInterval(0.123456789)
        let stage = LifeStageEpisode(kind: .postpartum, start: day(20261001), feedingContext: .combination,
                                     forecastExclusion: false, notes: "Synthetic note", createdAt: stamp, updatedAt: stamp)
        let p2 = P2Data(lifeStages: [stage],
            postpartumBleeding: [PostpartumBleedingEntry(day: day(20261002), state: .bleeding, flow: .light, createdAt: stamp, updatedAt: stamp)],
            biomarkers: [BiomarkerEntry(day: today, kind: .basalBodyTemperature, numericValue: 36.55, createdAt: stamp, updatedAt: stamp),
                         BiomarkerEntry(day: today, kind: .lhTest, result: .negative, provenance: .appleHealth, sourceName: "Synthetic",
                                        createdAt: stamp, updatedAt: stamp)],
            insightFeedback: [InsightFeedback(insightID: "v1.cycleLength|x", helpful: false, reasons: [.unclear, .repetitive], updatedAt: stamp)])
        let original = TrackerSnapshot(periods: periods, p2: p2)
        let data = try TrackerExport.encode(snapshot: original, includeNotes: true, generatedAt: now)
        let imported = try TrackerImport.preview(data: data, existing: TrackerSnapshot(), today: today, strategy: .useImported)
        #expect(imported.formatVersion == 9)
        #expect(imported.snapshot.p2 == P2RecordValidation.sorted(p2))
        let duplicate = try TrackerImport.preview(data: data, existing: imported.snapshot, today: today, strategy: .keepExisting)
        #expect(duplicate.added == 0 && duplicate.conflicts == 0)
        let withoutNotes = try TrackerExport.encode(snapshot: original, includeNotes: false, generatedAt: now)
        #expect(String(data: withoutNotes, encoding: .utf8)?.contains("Synthetic note") == false)
    }

    @Test func importRejectsMalformedP2AndOlderFormatsStillImport() throws {
        let olderData = try TrackerExport.encode(snapshot: TrackerSnapshot(periods: periods), includeNotes: false, generatedAt: now)
        let older = try TrackerImport.preview(data: olderData, existing: TrackerSnapshot(), today: today, strategy: .keepExisting)
        #expect(older.formatVersion < 9 && older.snapshot.p2.isEmpty)
        let orphanJSON = """
        {"formatVersion":9,"generatedAt":"2026-10-15T12:00:00Z","includesPrivateNotes":false,"periods":[],"observations":[],
         "postpartumBleeding":[{"id":"\(UUID().uuidString)","date":"2026-10-10","state":"lochia","createdAtReference":0,"updatedAtReference":0}]}
        """
        #expect(throws: TrackingError.invalidData) {
            try TrackerImport.preview(data: Data(orphanJSON.utf8), existing: TrackerSnapshot(), today: today, strategy: .keepExisting)
        }
        let wrongUnit = """
        {"formatVersion":9,"generatedAt":"2026-10-15T12:00:00Z","includesPrivateNotes":false,"periods":[],"observations":[],
         "biomarkers":[{"id":"\(UUID().uuidString)","date":"2026-10-10","type":"basalBodyTemperature","value":98.6,"unit":"°F",
         "provenance":"manual","createdAtReference":0,"updatedAtReference":0}]}
        """
        #expect(throws: TrackingError.invalidData) {
            try TrackerImport.preview(data: Data(wrongUnit.utf8), existing: TrackerSnapshot(), today: today, strategy: .keepExisting)
        }
        let future = """
        {"formatVersion":10,"generatedAt":"2026-10-15T12:00:00Z","includesPrivateNotes":false,"periods":[],"observations":[]}
        """
        #expect(throws: TrackingError.invalidData) {
            try TrackerImport.preview(data: Data(future.utf8), existing: TrackerSnapshot(), today: today, strategy: .keepExisting)
        }
    }

    @Test @MainActor func reportIncludesP2SectionsOnlyWhenSelected() throws {
        let stage = LifeStageEpisode(kind: .postpartum, start: day(20261001), notes: "Private stage note")
        let snapshot = TrackerSnapshot(periods: periods, p2: P2Data(lifeStages: [stage],
            postpartumBleeding: [PostpartumBleedingEntry(day: day(20261003), state: .lochia)],
            biomarkers: [BiomarkerEntry(day: day(20261004), kind: .pregnancyTest, result: .negative)]))
        var options = AppointmentSummaryOptions()
        let defaults = try AppointmentSummary.document(snapshot: snapshot, start: day(20260901), end: today, options: options)
        #expect(!defaults.sections.contains { $0.kind == .lifeStages || $0.kind == .biomarkers })
        options.lifeStages = true; options.biomarkers = true
        let document = try AppointmentSummary.document(snapshot: snapshot, start: day(20260901), end: today, options: options)
        let text = document.text
        #expect(text.contains("LIFE STAGES") && text.contains("BIOMARKER RECORDS"))
        #expect(text.contains("separately from periods") && text.contains("Not used to confirm"))
        #expect(!text.contains("Private stage note"))
        options.notes = true
        #expect(try AppointmentSummary.text(snapshot: snapshot, start: day(20260901), end: today, options: options).contains("Private stage note"))
        #expect(AppointmentReportPDF.encode(document).starts(with: Data("%PDF".utf8)))
    }
}

@MainActor struct P2RoadmapRepositoryTests {
    private let today = try! LocalDay(key: 20261015)
    private var now: Date { today.formattingDate }

    @Test func p2RecordsPersistRollBackOnInvalidSaveAndReset() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        _ = try repository.add([Period(start: try LocalDay(key: 20261001))], completingOnboarding: true, today: today, now: now)
        let stage = LifeStageEpisode(kind: .postpartum, start: try LocalDay(key: 20261005), createdAt: now)
        let data = P2Data(lifeStages: [stage],
            postpartumBleeding: [PostpartumBleedingEntry(day: today, state: .spotting, createdAt: now)],
            biomarkers: [BiomarkerEntry(day: today, kind: .restingHeartRate, numericValue: 62, createdAt: now)])
        let saved = try repository.saveP2Data(data, today: today)
        #expect(try repository.load() == saved)
        #expect(saved.p2 == P2RecordValidation.sorted(data))
        var invalid = saved.p2
        invalid.lifeStages = []
        #expect(throws: TrackingError.invalidData) { try repository.saveP2Data(invalid, today: today) }
        #expect(try repository.load() == saved)
        _ = try repository.deleteAll()
        #expect(try repository.load().p2.isEmpty)
    }

    @Test func importReplacesP2DataInOneTransaction() throws {
        let repository = try SwiftDataPeriodRepository.inMemory()
        var candidate = TrackerSnapshot()
        candidate.p2.biomarkers = [BiomarkerEntry(day: today, kind: .sleepDuration, numericValue: 7, createdAt: now)]
        let imported = try repository.importSnapshot(candidate, today: today)
        #expect(try repository.load().p2 == imported.p2)
        var bad = imported
        bad.p2.biomarkers.append(BiomarkerEntry(day: today, kind: .sleepDuration, numericValue: 30, createdAt: now))
        #expect(throws: TrackingError.invalidData) { try repository.importSnapshot(bad, today: today) }
        #expect(try repository.load().p2 == imported.p2)
    }

    @Test func v8StoreMigratesToV9WithoutChangingRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("v8.store")
        let period = Period(start: try LocalDay(key: 20261001), createdAt: now)
        let factor = CycleFactor(kind: .travel, start: today, createdAt: now)
        try autoreleasepool {
            let schema = Schema(versionedSchema: TrackerSchemaV8.self)
            let config = ModelConfiguration("CecyLocal", schema: schema, url: url, cloudKitDatabase: .none)
            let context = ModelContext(try ModelContainer(for: schema, configurations: [config]))
            context.insert(TrackerSchemaV2.PeriodRecord(period))
            context.insert(TrackerSchemaV2.AppStateRecord(completedAt: now))
            context.insert(try TrackerSchemaV8.CycleFactorRecord(factor))
            try context.save()
        }
        var saved = TrackerSnapshot()
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            let migrated = try repository.load()
            #expect(migrated.periods == [period] && migrated.cycleFactors == [factor])
            #expect(migrated.p2.isEmpty)
            saved = try repository.saveP2Data(P2Data(lifeStages: [LifeStageEpisode(kind: .cycleChange, start: today, createdAt: now)]), today: today)
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == saved)
    }
}
