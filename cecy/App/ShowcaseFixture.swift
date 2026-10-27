#if DEBUG
import Foundation

/// App Store screenshot data: six months of realistic, internally consistent records so every
/// screenshotted screen (Today, check-in, Calendar, Insights, summary) has content. UI tests only.
enum ShowcaseFixture {
    static func seed(_ repository: SwiftDataPeriodRepository, now: Date) throws {
        let today = try LocalDay(key: 20260929)
        guard try repository.load().onboardingCompletedAt == nil else { return }

        // Periods: natural 27–30 day cycles with 4–6 day periods.
        let spans: [(Int, Int, PeriodFlow)] = [
            (20260406, 5, .moderate), (20260504, 5, .heavy), (20260602, 4, .moderate),
            (20260701, 6, .heavy), (20260729, 5, .moderate), (20260827, 5, .moderate), (20260925, 5, .heavy),
        ]
        var periods: [Period] = []
        for (key, length, flow) in spans {
            let start = try LocalDay(key: key)
            let end = try start.adding(days: length - 1)
            periods.append(Period(start: start, end: end <= today ? end : nil, flow: flow,
                                  notes: key == 20260701 ? "Heavier than usual, needed extra rest." : nil,
                                  createdAt: now, updatedAt: now))
        }
        _ = try repository.add(periods, completingOnboarding: true, today: today, now: now)

        var profile = LocalProfile()
        profile.preferredName = "Maya"
        profile.birthDayKey = 19950512
        profile.typicalPeriodDays = 5
        profile.typicalCycleDays = 29
        profile.wellnessPreferences = WellnessPreferences(activityLevel: .moderatelyActive, preferredExercises: [.walking],
            dietaryPreference: .vegetarian, foodAllergyStatus: .listed, foodAllergies: ["Peanuts"], goals: [.manageSymptoms])
        _ = try repository.saveProfile(profile, today: today)

        // Daily bleeding: a flow curve for every period day, spotting before some periods, dry days lately.
        var review = BleedingReconciliation(snapshot: try repository.load())
        let curve: [PeriodFlow] = [.moderate, .heavy, .moderate, .light, .light, .light]
        for period in review.periods {
            let last = period.end ?? today
            var day = period.start
            var index = 0
            while day <= last && day <= today {
                review.observations.append(DailyBleedingObservation(day: day, state: .bleeding, flow: curve[min(index, curve.count - 1)],
                                                                    periodID: period.id, createdAt: now))
                day = try day.adding(days: 1); index += 1
            }
            if period.start.key != 20260406 {
                review.observations.append(DailyBleedingObservation(day: try period.start.adding(days: -1), state: .spotting, createdAt: now))
            }
        }
        // Consistent logging: every remaining day since August is answered "no bleeding".
        let answered = Set(review.observations.map(\.day))
        var dry = try LocalDay(key: 20260801)
        while dry <= today {
            if !answered.contains(dry), !review.periods.contains(where: { $0.contains(dry) }) {
                review.observations.append(DailyBleedingObservation(day: dry, state: .noBleeding, createdAt: now))
            }
            dry = try dry.adding(days: 1)
        }
        _ = try repository.reconcileBleeding(review, today: today, now: now)

        // Symptoms that follow the cycle, so patterns and charts have something to show.
        var symptoms: [SymptomEntry] = []
        func add(_ day: LocalDay, _ kind: SymptomKind, _ value: Int) {
            guard day <= today else { return }
            symptoms.append(SymptomEntry(day: day, kind: kind, value: value, createdAt: now))
        }
        for period in periods {
            let s = period.start
            add(s, .cramps, 3); add(try s.adding(days: 1), .cramps, 2); add(try s.adding(days: 2), .cramps, 1)
            add(s, .fatigue, 2); add(try s.adding(days: 1), .fatigue, 3); add(try s.adding(days: 1), .backPain, 2)
            add(try s.adding(days: 1), .lowMood, 1); add(try s.adding(days: 2), .sleepQuality, 2)
            add(try s.adding(days: -1), .headache, 2); add(try s.adding(days: -2), .bloating, 2)
            add(try s.adding(days: -3), .breastTenderness, 2); add(try s.adding(days: -3), .irritability, 2)
            add(try s.adding(days: -4), .cravings, 3); add(try s.adding(days: -5), .acne, 1)
            add(try s.adding(days: 8), .energyLevel, 3); add(try s.adding(days: 13), .energyLevel, 3)
            add(try s.adding(days: 13), .pelvicPain, 1)
        }
        add(today, .bloating, 2); add(today, .digestiveChanges, 1)
        let unique = Dictionary(symptoms.map { ("\($0.day.key)-\($0.kind.rawValue)", $0) }, uniquingKeysWith: { first, _ in first })
        _ = try repository.addSymptoms(Array(unique.values), today: today, now: now)

        // Intimacy log, a few times per cycle.
        for key in [20260418, 20260423, 20260517, 20260520, 20260614, 20260619, 20260712, 20260716,
                    20260809, 20260812, 20260906, 20260911, 20260918] {
            let kinds: Set<SexualActivityKind> = key % 3 == 0 ? [.vaginalSex, .oralSex] : [.vaginalSex]
            _ = try repository.saveSexualActivity(SexualActivityEntry(day: try LocalDay(key: key), activities: kinds, createdAt: now),
                                                  editing: false, today: today, now: now)
        }

        // Context that explains a longer cycle.
        _ = try repository.saveCycleFactor(CycleFactor(kind: .stress, start: try LocalDay(key: 20260615), end: try LocalDay(key: 20260626),
                                                       excludesFromForecast: false, notes: "Project deadline at work", createdAt: now), today: today, now: now)
        _ = try repository.saveCycleFactor(CycleFactor(kind: .travel, start: try LocalDay(key: 20260810), end: try LocalDay(key: 20260817),
                                                       excludesFromForecast: false, notes: "Lisbon trip, time-zone change", createdAt: now), today: today, now: now)

        // Supplements with an adherence history.
        let magnesium = TreatmentRecord(category: .supplement, name: "Magnesium", dose: "200 mg", start: try LocalDay(key: 20260601),
                                        cadence: .daily, reminderEnabled: true, reminderHour: 21, createdAt: now)
        let iron = TreatmentRecord(category: .supplement, name: "Iron", dose: "18 mg", start: try LocalDay(key: 20260701),
                                   cadence: .daily, createdAt: now)
        let ibuprofen = TreatmentRecord(category: .medication, name: "Ibuprofen", dose: "400 mg", start: try LocalDay(key: 20260406),
                                        cadence: .asNeeded, createdAt: now)
        for treatment in [magnesium, iron, ibuprofen] { _ = try repository.saveTreatment(treatment, today: today, now: now) }
        var day = try LocalDay(key: 20260830)
        var count = 0
        while day <= today {
            let state: AdherenceState = count == 6 ? .missed : count == 15 ? .late : .taken
            _ = try repository.saveTreatmentAdherence(TreatmentAdherence(treatmentID: magnesium.id, day: day, state: state, createdAt: now),
                                                      today: today, now: now)
            if count % 2 == 0 {
                _ = try repository.saveTreatmentAdherence(TreatmentAdherence(treatmentID: iron.id, day: day, state: .taken, createdAt: now),
                                                          today: today, now: now)
            }
            day = try day.adding(days: 1); count += 1
        }
        for period in periods.suffix(4) {
            _ = try repository.saveTreatmentAdherence(TreatmentAdherence(treatmentID: ibuprofen.id, day: period.start, state: .taken,
                                                                         notes: "For cramps", createdAt: now), today: today, now: now)
        }

        // Body signals: a biphasic temperature curve, LH tests and mucus around ovulation, heart rate and sleep.
        var p2 = try repository.load().p2
        let cycleStarts = periods.map(\.start) + [try LocalDay(key: 20261024)]
        var cursor = try LocalDay(key: 20260720)
        while cursor <= today {
            guard let start = cycleStarts.last(where: { $0 <= cursor }) else { break }
            let cycleDay = start.days(until: cursor) + 1
            let luteal = cycleDay >= 16
            let wobble = Double((cursor.key * 7) % 5) * 0.03
            p2.biomarkers.append(BiomarkerEntry(day: cursor, kind: .basalBodyTemperature,
                                                numericValue: (luteal ? 36.68 : 36.32) + wobble, createdAt: now))
            p2.biomarkers.append(BiomarkerEntry(day: cursor, kind: .restingHeartRate,
                                                numericValue: (luteal ? 64 : 60) + Double((cursor.key * 3) % 4),
                                                provenance: .appleHealth, sourceName: "Apple Watch", createdAt: now))
            p2.biomarkers.append(BiomarkerEntry(day: cursor, kind: .sleepDuration,
                                                numericValue: 6.6 + Double((cursor.key * 11) % 9) * 0.2,
                                                provenance: .appleHealth, sourceName: "Apple Watch", createdAt: now))
            if (11...15).contains(cycleDay) {
                p2.biomarkers.append(BiomarkerEntry(day: cursor, kind: .lhTest, result: cycleDay == 13 ? .positive : cycleDay == 14 ? .high : .negative,
                                                    createdAt: now))
                p2.biomarkers.append(BiomarkerEntry(day: cursor, kind: .cervicalMucus,
                                                    result: cycleDay == 13 ? .eggWhite : cycleDay == 12 || cycleDay == 14 ? .watery : .creamy, createdAt: now))
            }
            cursor = try cursor.adding(days: 1)
        }
        _ = try repository.saveP2Data(p2, today: today)
    }
}
#endif
