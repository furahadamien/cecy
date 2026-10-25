import Foundation

// MARK: - Follow-up questions shown as a pop-up on Today
//
// Questions are derived from records each time, so filling a gap makes its question disappear.
// Only the user's skips, confirmations and the weekly budget are remembered (on this device).
// Explanations describe what Cecy records and does with it; they never give medical advice.

nonisolated enum FollowUpKind: String, Codable, CaseIterable, Sendable {
    case periodToday, windowPassed, unusualCycle, newCycle, openFactor
    case treatmentDose, treatmentReview, lifeStageReview, biomarker
    /// Everyday questions, so there's something useful to ask on ordinary days too.
    case cycleContext, dailyCheckIn

    /// Higher is asked first when several are due.
    var priority: Int {
        switch self {
        case .periodToday: 100
        case .windowPassed: 90
        case .unusualCycle: 80
        case .newCycle: 70
        case .openFactor: 60
        case .treatmentDose: 55
        case .treatmentReview: 50
        case .lifeStageReview: 40
        case .biomarker: 30
        case .cycleContext: 25
        case .dailyCheckIn: 20
        }
    }

    var settingsTitle: String {
        switch self {
        case .periodToday: String(localized: "Whether your period has started or is still going")
        case .windowPassed: String(localized: "When an estimated window has passed")
        case .unusualCycle: String(localized: "Cycles that were longer or shorter than usual")
        case .newCycle: String(localized: "Anything new at the start of a cycle")
        case .openFactor: String(localized: "Whether illness, stress or travel has ended")
        case .treatmentDose: String(localized: "Treatments with reminders that are due today")
        case .treatmentReview: String(localized: "Whether contraception or medication is still current")
        case .lifeStageReview: String(localized: "Whether a life stage is still current")
        case .biomarker: String(localized: "Biomarkers you've been recording")
        case .cycleContext: String(localized: "A weekly check for anything affecting your cycle")
        case .dailyCheckIn: String(localized: "How you're feeling, when today isn't logged yet")
        }
    }
}

nonisolated struct FollowUpSnooze: Codable, Equatable, Sendable {
    var untilDay: Int
    var count: Int
}

/// Local-only memory of how the user answered questions. Never exported.
nonisolated struct FollowUpMemory: Codable, Equatable, Sendable {
    /// "Not now": the subject waits until `untilDay`; each skip waits longer.
    var snoozes: [String: FollowUpSnooze] = [:]
    /// "Still going": the subject's review clock restarts from this day.
    var confirmedDays: [String: Int] = [:]
    /// Answered with "nothing" or "not sure": never asked again for that subject.
    var resolvedDays: [String: Int] = [:]
    /// "Don't ask about this": the whole question type stays off until re-enabled in Settings.
    var disabledKinds: Set<FollowUpKind> = []
    /// Days a question was shown.
    var shownDays: [Int] = []
    /// The day `todaySubjects` and `lastShownMinute` belong to. Optional so older preferences still load.
    var todayKey: Int?
    /// Questions already shown today: each is asked at most once a day, and they count toward the daily limit.
    var todaySubjects: [String]?
    /// Minutes since midnight when the last question was shown, to space pop-ups out across the day.
    var lastShownMinute: Int?

    static let snoozeSchedule = [3, 7, 21]

    func validate() throws {
        for value in snoozes.values { _ = try LocalDay(key: value.untilDay); guard value.count > 0 else { throw TrackingError.invalidData } }
        for value in confirmedDays.values { _ = try LocalDay(key: value) }
        for value in resolvedDays.values { _ = try LocalDay(key: value) }
        for value in shownDays { _ = try LocalDay(key: value) }
        if let todayKey { _ = try LocalDay(key: todayKey) }
        guard snoozes.count + confirmedDays.count + resolvedDays.count <= 2_000, shownDays.count <= 60,
              (todaySubjects?.count ?? 0) <= 50, (0..<1_440).contains(lastShownMinute ?? 0) else {
            throw TrackingError.invalidData
        }
    }

    /// Questions shown so far on `today`.
    func subjectsShown(on today: LocalDay) -> [String] {
        todayKey == today.key ? (todaySubjects ?? []) : []
    }

    func lastShownMinute(on today: LocalDay) -> Int? {
        todayKey == today.key ? lastShownMinute : nil
    }

    mutating func markShown(_ today: LocalDay, subject: String? = nil, minute: Int? = nil) {
        if !shownDays.contains(today.key) { shownDays.append(today.key) }
        if todayKey != today.key { todayKey = today.key; todaySubjects = []; lastShownMinute = nil }
        if let subject, !(todaySubjects ?? []).contains(subject) { todaySubjects = (todaySubjects ?? []) + [subject] }
        if let minute { lastShownMinute = minute }
    }

    mutating func snooze(_ subject: String, today: LocalDay) {
        let count = (snoozes[subject]?.count ?? 0) + 1
        let wait = Self.snoozeSchedule[min(count, Self.snoozeSchedule.count) - 1]
        let until = (try? today.adding(days: wait)) ?? today
        snoozes[subject] = FollowUpSnooze(untilDay: until.key, count: count)
    }

    mutating func confirm(_ subject: String, today: LocalDay) {
        confirmedDays[subject] = today.key
        snoozes[subject] = nil
    }

    mutating func resolve(_ subject: String, today: LocalDay) {
        resolvedDays[subject] = today.key
        snoozes[subject] = nil
    }

    mutating func answered(_ subject: String) { snoozes[subject] = nil }

    /// Settings "Ask again": clears skips and turned-off questions. Records are untouched.
    mutating func resetSkipped() {
        snoozes = [:]
        resolvedDays = [:]
        disabledKinds = []
    }

    /// Keeps the file small: old days no longer affect any rule.
    mutating func prune(today: LocalDay) {
        let weekAgo = ((try? today.adding(days: -14)) ?? today).key
        let yearAgo = ((try? today.adding(days: -365)) ?? today).key
        shownDays = shownDays.filter { $0 >= weekAgo && $0 <= today.key }.sorted()
        if todayKey != today.key { todayKey = nil; todaySubjects = nil; lastShownMinute = nil }
        snoozes = snoozes.filter { $0.value.untilDay >= yearAgo }
        confirmedDays = confirmedDays.filter { $0.value >= yearAgo }
        resolvedDays = resolvedDays.filter { $0.value >= yearAgo }
    }

    func isWaiting(_ subject: String, today: LocalDay) -> Bool {
        if resolvedDays[subject] != nil { return true }
        if let snooze = snoozes[subject], snooze.untilDay > today.key { return true }
        return false
    }
}

nonisolated struct FollowUpPrompt: Identifiable, Equatable, Sendable {
    enum Context: Equatable, Sendable {
        case periodStarted(day: LocalDay)
        case periodContinuing(day: LocalDay)
        case windowPassed(estimate: CyclePrediction, latestStart: LocalDay?)
        case unusualCycle(interval: CycleInterval, usual: Int)
        case newCycle(start: LocalDay)
        case openFactor(CycleFactor)
        case treatmentDose(TreatmentRecord, day: LocalDay)
        case treatmentReview(TreatmentRecord)
        case lifeStage(LifeStageEpisode)
        case biomarker(BiomarkerKind)
        case cycleContext(day: LocalDay)
        case dailyCheckIn(day: LocalDay)
    }

    let kind: FollowUpKind
    let subject: String
    let title: String
    let message: String
    let explainer: String
    /// "Why am I seeing this?": the records that triggered the question.
    let reason: String
    let context: Context
    var id: String { subject }
}

nonisolated struct FollowUpInput: Sendable {
    var today: LocalDay
    var snapshot: TrackerSnapshot
    var overview: CycleOverview
    var forecast: CycleForecast
    var memory: FollowUpMemory
    /// Minutes since local midnight, for treatment reminder times.
    var minuteOfDay: Int
    var timeZone: TimeZone
}

/// How a scheduled treatment is asked about, so questions match the method.
/// `nil` from `FollowUpEngine.doseStyle` means there's no sensible daily question (IUD, implant, barrier).
nonisolated enum DoseStyle: Equatable, Sendable {
    case take, changePatch, changeRing, shot, use
}

/// How "is this still current?" is asked: long-acting methods are "in place", medicines are "taken".
nonisolated enum ReviewStyle: Equatable, Sendable {
    case inPlace, taking, using
}

/// Main-actor because prompts use the app's localized date formatting (`DayText`).
@MainActor enum FollowUpEngine {
    /// Up to this many pop-ups a day, each a different question.
    static let dailyLimit = 4
    /// Minimum minutes between two pop-ups, so they're spread across separate visits.
    static let minimumGapMinutes = 45
    /// No questions on the day setup finishes.
    static let quietDaysAfterSetup = 1
    /// How often the everyday "anything affecting your cycle?" question can come back.
    static let cycleContextInterval = 7
    static let unusualCycleDifference = 7
    static let factorExplainer = String(localized: "Cycle factors are things that might affect the length or regularity of your cycle, such as illness, stress or travel. Your period records never change.")

    /// The question to show now, after limits and quiet times. `nil` means stay quiet.
    static func next(_ input: FollowUpInput) -> FollowUpPrompt? {
        guard canAsk(input) else { return nil }
        return eligible(input).first
    }

    /// Daily limit, spacing and quiet-time rules, independent of which questions are due.
    static func canAsk(_ input: FollowUpInput) -> Bool {
        let today = input.today
        if input.memory.subjectsShown(on: today).count >= dailyLimit { return false }
        if let last = input.memory.lastShownMinute(on: today), input.minuteOfDay - last < minimumGapMinutes { return false }
        if let completed = input.snapshot.onboardingCompletedAt,
           let completedDay = try? LocalDay(date: completed, timeZone: input.timeZone),
           completedDay.days(until: today) < quietDaysAfterSetup { return false }
        return true
    }

    /// Every due question that isn't skipped, turned off or already shown today, highest priority first.
    static func eligible(_ input: FollowUpInput) -> [FollowUpPrompt] {
        let sensitive = isSensitivePeriod(input)
        let shownToday = Set(input.memory.subjectsShown(on: input.today))
        return candidates(input)
            .filter { !input.memory.disabledKinds.contains($0.kind) }
            .filter { !input.memory.isWaiting($0.subject, today: input.today) }
            .filter { !shownToday.contains($0.subject) }
            // Pregnancy or loss: no casual questions. Only explicit treatment reminders remain.
            .filter { !sensitive || $0.kind == .treatmentDose }
            .sorted { ($0.kind.priority, $1.subject) > ($1.kind.priority, $0.subject) }
    }

    static func isSensitivePeriod(_ input: FollowUpInput) -> Bool {
        let recent = (try? input.today.adding(days: -30)) ?? input.today
        return input.snapshot.cycleFactors.contains { factor in
            [.pregnancy, .pregnancyLoss].contains(factor.kind) && (factor.end.map { $0 >= recent } ?? true)
        }
    }

    static func candidates(_ input: FollowUpInput) -> [FollowUpPrompt] {
        var result: [FollowUpPrompt] = []
        if let value = periodQuestion(input) { result.append(value) }
        if let value = windowPassed(input) { result.append(value) }
        let unusual = unusualCycle(input)
        if let unusual { result.append(unusual) }
        // One question per cycle start: "anything new?" yields to the unusual-cycle question,
        // unless the user turned that question type off.
        if unusual == nil || input.memory.disabledKinds.contains(.unusualCycle), let value = newCycle(input) { result.append(value) }
        result += openFactors(input)
        result += treatmentDoses(input)
        result += treatmentReviews(input)
        result += lifeStageReviews(input)
        result += biomarkers(input)
        // The weekly "anything affecting your cycle?" question would repeat the cycle-start questions.
        if !result.contains(where: { [.unusualCycle, .newCycle, .openFactor].contains($0.kind) }),
           let value = cycleContext(input) { result.append(value) }
        if let value = dailyCheckIn(input) { result.append(value) }
        return result
    }

    // MARK: Everyday questions

    /// "How's today going?" while nothing is logged for today. Answering opens the daily check-in.
    static func dailyCheckIn(_ input: FollowUpInput) -> FollowUpPrompt? {
        let today = input.today
        guard !input.snapshot.dailyBleeding.contains(where: { $0.day == today }),
              !input.snapshot.symptoms.contains(where: { $0.day == today }) else { return nil }
        return FollowUpPrompt(kind: .dailyCheckIn, subject: "dailyCheckIn:\(today.key)",
            title: String(localized: "How are you feeling today?"),
            message: String(localized: "Nothing is logged for today yet. It only takes a few seconds."),
            explainer: String(localized: "Daily answers build your history, so patterns and estimates get more useful over time. Days you don't log stay unknown."),
            reason: String(localized: "Today has no bleeding answer or symptoms logged yet."),
            context: .dailyCheckIn(day: today))
    }

    /// A weekly check for anything that might affect the cycle, when nothing has been noted recently.
    static func cycleContext(_ input: FollowUpInput) -> FollowUpPrompt? {
        let today = input.today
        guard let weekAgo = try? today.adding(days: -cycleContextInterval) else { return nil }
        // Something noted or still going recently already answers this.
        guard !input.snapshot.cycleFactors.contains(where: { factor in
            factor.start >= weekAgo || (factor.end.map { $0 >= weekAgo } ?? true)
                || ((try? LocalDay(date: factor.updatedAt, timeZone: input.timeZone)).map { $0 >= weekAgo } ?? false)
        }) else { return nil }
        let subject = "cycleContext"
        if let key = input.memory.confirmedDays[subject], let confirmed = try? LocalDay(key: key),
           confirmed.days(until: today) < cycleContextInterval { return nil }
        return FollowUpPrompt(kind: .cycleContext, subject: subject,
            title: String(localized: "Anything affecting your cycle lately?"),
            message: String(localized: "Illness, stress or travel can all shift when a period comes."),
            explainer: factorExplainer,
            reason: String(localized: "No cycle factor has been noted in the last week. Cecy checks in about once a week."),
            context: .cycleContext(day: today))
    }

    // MARK: Rules

    static func periodQuestion(_ input: FollowUpInput) -> FollowUpPrompt? {
        let today = input.today
        guard input.forecast.bleeding(on: today) != nil,
              !input.snapshot.dailyBleeding.contains(where: { $0.day == today }),
              !input.snapshot.resolvedPeriods.contains(where: { $0.contains(today) }) else { return nil }
        if input.forecast.currentBleeding?.contains(today) == true {
        return FollowUpPrompt(kind: .periodToday, subject: "periodToday:\(today.key)",
            title: String(localized: "Is your period still going?"),
            message: String(localized: "Your latest period is still open, and today isn't logged yet."),
            explainer: String(localized: "A quick answer keeps your calendar accurate. Days you don't answer stay unknown."),
            reason: String(localized: "Your recorded period has no end date, and Cecy estimates it may still be going today."),
            context: .periodContinuing(day: today))
        }
        // After birth or while feeding, bleeding often isn't a period; don't suggest one from an estimate.
        guard !input.snapshot.p2.lifeStages.contains(where: {
            [.postpartum, .breastfeeding].contains($0.kind) && $0.overlaps(start: today, end: today)
        }) else { return nil }
        return FollowUpPrompt(kind: .periodToday, subject: "periodToday:\(today.key)",
            title: String(localized: "Has your period started?"),
            message: String(localized: "Today falls within your estimated period days."),
            explainer: String(localized: "Estimates are rough. Recording what actually happens keeps your calendar accurate and improves future estimates."),
            reason: String(localized: "Your estimate includes today, and nothing is logged for today yet."),
            context: .periodStarted(day: today))
    }

    static func windowPassed(_ input: FollowUpInput) -> FollowUpPrompt? {
        guard case .available(let estimate) = input.overview.prediction,
              input.today > estimate.latest,
              estimate.latest.days(until: input.today) <= 30,
              (input.overview.latestStart.map { $0 < estimate.earliest } ?? true),
              !input.snapshot.resolvedPeriods.contains(where: { $0.start >= estimate.earliest }) else { return nil }
        // Something already noted for this time (a factor or life stage) explains the wait; don't ask.
        guard !input.snapshot.cycleFactors.contains(where: { $0.overlaps(start: estimate.earliest, end: input.today) }),
              !input.snapshot.p2.lifeStages.contains(where: { $0.overlaps(start: estimate.earliest, end: input.today) })
        else { return nil }
        let days = estimate.latest.days(until: input.today)
        return FollowUpPrompt(kind: .windowPassed, subject: "windowPassed:\(estimate.center.key)",
            title: String(localized: "Your estimated window has passed"),
            message: days == 1 ? String(localized: "It ended yesterday, and no new period is logged.")
                               : String(localized: "It ended \(days) days ago, and no new period is logged."),
            explainer: String(localized: "Estimates are rough, and cycles vary. If your period started and wasn't logged, adding it keeps future estimates accurate. If something might have affected this cycle, you can note it as a cycle factor."),
            reason: String(localized: "Your estimated start window was \(DayText.range(estimate.earliest, estimate.latest))."),
            context: .windowPassed(estimate: estimate, latestStart: input.overview.latestStart))
    }

    static func latestCompletedInterval(_ overview: CycleOverview) -> CycleInterval? {
        (overview.intervals + overview.excludedIntervals).max { $0.nextStart < $1.nextStart }
    }

    static func unusualCycle(_ input: FollowUpInput) -> FollowUpPrompt? {
        guard let last = latestCompletedInterval(input.overview),
              !input.overview.excludedIntervals.contains(where: { $0.id == last.id }),
              last.nextStart.days(until: input.today) >= 0,
              last.nextStart.days(until: input.today) <= 21,
              let lastDay = try? last.nextStart.adding(days: -1) else { return nil }
        let others = input.overview.intervals.filter { $0.id != last.id }.map(\.length).sorted()
        guard others.count >= 3 else { return nil }
        let usual = others[others.count / 2]
        guard abs(last.length - usual) >= unusualCycleDifference else { return nil }
        guard !input.snapshot.cycleFactors.contains(where: { $0.overlaps(start: last.start, end: lastDay) }),
              !input.snapshot.p2.lifeStages.contains(where: { $0.overlaps(start: last.start, end: lastDay) }) else { return nil }
        let longer = last.length > usual
        return FollowUpPrompt(kind: .unusualCycle, subject: "unusualCycle:\(last.start.key)",
            title: longer ? String(localized: "Your last cycle was longer than usual")
                          : String(localized: "Your last cycle was shorter than usual"),
            message: String(localized: "It was \(last.length) days. Your usual is about \(usual). Was anything going on?"),
            explainer: factorExplainer,
            reason: String(localized: "Your cycle from \(DayText.range(last.start, lastDay)) differs from your usual length by \(abs(last.length - usual)) days, and no cycle factor covers those dates."),
            context: .unusualCycle(interval: last, usual: usual))
    }

    static func newCycle(_ input: FollowUpInput) -> FollowUpPrompt? {
        guard let start = input.overview.latestStart,
              input.snapshot.periods.contains(where: { $0.start == start }),
              (0...2).contains(start.days(until: input.today)),
              latestCompletedInterval(input.overview)?.nextStart == start else { return nil }
        return FollowUpPrompt(kind: .newCycle, subject: "newCycle:\(start.key)",
            title: String(localized: "A new cycle has started"),
            message: String(localized: "Anything new this cycle that's worth noting?"),
            explainer: factorExplainer,
            reason: String(localized: "You recorded a period starting \(DayText.full(start))."),
            context: .newCycle(start: start))
    }

    static func reviewInterval(for kind: CycleFactorKind) -> Int? {
        switch kind {
        case .illness, .travel: 7
        case .stress: 14
        default: nil
        }
    }

    static func openFactors(_ input: FollowUpInput) -> [FollowUpPrompt] {
        input.snapshot.cycleFactors.compactMap { factor in
            guard factor.end == nil, let interval = reviewInterval(for: factor.kind) else { return nil }
            let subject = "openFactor:\(factor.id.uuidString)"
            let since = reviewBase(factor.start, updatedAt: factor.updatedAt, subject: subject, input: input)
            guard since.days(until: input.today) >= interval else { return nil }
            let title: String = switch factor.kind {
            case .travel: String(localized: "Are you still traveling?")
            case .illness: String(localized: "Are you still unwell?")
            default: String(localized: "Is the stress still going on?")
            }
            return FollowUpPrompt(kind: .openFactor, subject: subject, title: title,
                message: String(localized: "You noted \(factor.kind.title.lowercased()) starting \(DayText.full(factor.start))."),
                explainer: factorExplainer,
                reason: String(localized: "This cycle factor has no end date yet."),
                context: .openFactor(factor))
        }
    }

    static func isDue(_ treatment: TreatmentRecord, on day: LocalDay) -> Bool {
        guard treatment.start <= day, treatment.end.map({ day <= $0 }) ?? true,
              let interval = treatment.cadence.dayInterval else { return false }
        return treatment.start.days(until: day) % interval == 0
    }

    /// The question style for a scheduled treatment, or `nil` when a dose question wouldn't make sense.
    static func doseStyle(_ treatment: TreatmentRecord) -> DoseStyle? {
        guard treatment.category == .contraception else { return .take }
        switch treatment.contraceptionType {
        case .pill: return .take
        case .patch: return .changePatch
        case .ring: return .changeRing
        case .shot: return .shot
        // Long-acting or used-when-needed methods have no "dose" to log.
        case .implant, .hormonalIUD, .copperIUD, .barrier: return nil
        case .other, nil: return .use
        }
    }

    static func reviewStyle(_ treatment: TreatmentRecord) -> ReviewStyle {
        switch treatment.contraceptionType {
        case .implant, .hormonalIUD, .copperIUD: .inPlace
        default: treatment.category == .contraception ? .using : .taking
        }
    }

    /// Long-acting methods last years, so they're checked yearly rather than every 90 days.
    static func reviewInterval(for treatment: TreatmentRecord) -> Int {
        reviewStyle(treatment) == .inPlace ? 365 : 90
    }

    static func isPregnant(_ input: FollowUpInput) -> Bool {
        input.snapshot.cycleFactors.contains { $0.kind == .pregnancy && ($0.end.map { $0 >= input.today } ?? true) }
    }

    static func treatmentDoses(_ input: FollowUpInput) -> [FollowUpPrompt] {
        let pregnant = isPregnant(input)
        return input.snapshot.treatments.compactMap { treatment in
            guard treatment.reminderEnabled, let style = doseStyle(treatment), isDue(treatment, on: input.today),
                  input.minuteOfDay >= treatment.reminderHour * 60 + treatment.reminderMinute,
                  // Contraception questions make no sense during a recorded pregnancy.
                  !(pregnant && treatment.category == .contraception),
                  !input.snapshot.treatmentAdherence.contains(where: { $0.treatmentID == treatment.id && $0.day == input.today })
            else { return nil }
            let title: String = switch style {
            case .take: String(localized: "Did you take \(treatment.name) today?")
            case .changePatch: String(localized: "Did you change your patch today?")
            case .changeRing: String(localized: "Did you change your ring today?")
            case .shot: String(localized: "Did you get your shot?")
            case .use: String(localized: "Did you use \(treatment.name) today?")
            }
            let message: String = switch style {
            case .take, .use: String(localized: "Its reminder time has passed and today isn't logged yet.")
            case .changePatch, .changeRing: String(localized: "Today is a scheduled change day for \(treatment.name).")
            case .shot: String(localized: "Your shot (\(treatment.name)) was scheduled for today.")
            }
            return FollowUpPrompt(kind: .treatmentDose, subject: "treatmentDose:\(treatment.id.uuidString):\(input.today.key)",
                title: title, message: message,
                explainer: String(localized: "Saved only on this device. Days you don't log stay unknown; Cecy never assumes a missed dose."),
                reason: String(localized: "You turned on reminders for \(treatment.name), and it's scheduled \(treatment.cadence.title.lowercased())."),
                context: .treatmentDose(treatment, day: input.today))
        }
    }

    static func treatmentReviews(_ input: FollowUpInput) -> [FollowUpPrompt] {
        input.snapshot.treatments.compactMap { treatment in
            guard treatment.end == nil, treatment.start <= input.today,
                  treatment.category == .contraception || treatment.cadence != .asNeeded else { return nil }
            let subject = "treatmentReview:\(treatment.id.uuidString)"
            let interval = reviewInterval(for: treatment)
            let since = reviewBase(treatment.start, updatedAt: treatment.updatedAt, subject: subject, input: input)
            guard since.days(until: input.today) >= interval else { return nil }
            let title: String = switch reviewStyle(treatment) {
            case .inPlace:
                treatment.contraceptionType == .implant ? String(localized: "Is your implant still in place?")
                                                         : String(localized: "Is your IUD still in place?")
            case .taking: String(localized: "Still taking \(treatment.name)?")
            case .using: String(localized: "Still using \(treatment.name)?")
            }
            return FollowUpPrompt(kind: .treatmentReview, subject: subject, title: title,
                message: String(localized: "It's been a while since this record was reviewed."),
                explainer: String(localized: "Keeping this current keeps your history and appointment reports accurate. Cecy doesn't give medication advice."),
                reason: interval >= 365
                    ? String(localized: "\(treatment.name) has no end date and hasn't been updated in over a year.")
                    : String(localized: "\(treatment.name) has no end date and hasn't been updated in over 90 days."),
                context: .treatmentReview(treatment))
        }
    }

    static func lifeStageReviews(_ input: FollowUpInput) -> [FollowUpPrompt] {
        input.snapshot.p2.lifeStages.compactMap { episode in
            guard episode.end == nil, episode.start <= input.today else { return nil }
            let subject = "lifeStage:\(episode.id.uuidString)"
            let interval = episode.kind == .cycleChange ? 90 : 30
            let since = reviewBase(episode.start, updatedAt: episode.updatedAt, subject: subject, input: input)
            guard since.days(until: input.today) >= interval else { return nil }
            let title: String = switch episode.kind {
            case .cycleChange: String(localized: "Still tracking cycle changes?")
            case .postpartum: String(localized: "Still in postpartum recovery?")
            case .breastfeeding: String(localized: "Still breastfeeding or chestfeeding?")
            }
            return FollowUpPrompt(kind: .lifeStageReview, subject: subject, title: title,
                message: String(localized: "This life stage started \(DayText.full(episode.start))."),
                explainer: String(localized: "Life stages tailor your daily check-in and can keep these dates out of cycle averages."),
                reason: String(localized: "This life stage has no end date and hasn't been reviewed in over \(interval) days."),
                context: .lifeStage(episode))
        }
    }

    static func biomarkers(_ input: FollowUpInput) -> [FollowUpPrompt] {
        guard let start = try? input.today.adding(days: -14),
              let recentRun = try? input.today.adding(days: -2) else { return [] }
        return [BiomarkerKind.basalBodyTemperature, .lhTest, .cervicalMucus].compactMap { kind in
            let entries = input.snapshot.p2.biomarkers.filter { $0.kind == kind }
            let recentDays = Set(entries.filter { $0.day >= start && $0.day < input.today }.map(\.day))
            guard recentDays.count >= 3, !entries.contains(where: { $0.day == input.today }) else { return nil }
            // LH tests are taken for a few days at a time, so only ask while a run of tests is ongoing.
            if kind == .lhTest, !recentDays.contains(where: { $0 >= recentRun }) { return nil }
            let title: String = switch kind {
            case .basalBodyTemperature: String(localized: "Add today's temperature?")
            case .lhTest: String(localized: "Did you take an LH test today?")
            default: String(localized: "Add today's cervical mucus observation?")
            }
            let noun: String = switch kind {
            case .basalBodyTemperature: String(localized: "your basal body temperature")
            case .lhTest: String(localized: "LH test results")
            default: String(localized: "cervical mucus")
            }
            return FollowUpPrompt(kind: .biomarker, subject: "biomarker:\(kind.rawValue):\(input.today.key)",
                title: title,
                message: String(localized: "You've recorded \(noun) on \(recentDays.count) of the last 14 days."),
                explainer: String(localized: "Readings are saved as records only. They never change your estimate."),
                reason: String(localized: "You've been recording \(noun) regularly, and today isn't logged yet."),
                context: .biomarker(kind))
        }
    }

    /// The later of the record's start, its last edit, and the user's last "still going" answer.
    static func reviewBase(_ start: LocalDay, updatedAt: Date, subject: String, input: FollowUpInput) -> LocalDay {
        var base = start
        if let edited = try? LocalDay(date: updatedAt, timeZone: input.timeZone), edited > base { base = edited }
        if let key = input.memory.confirmedDays[subject], let confirmed = try? LocalDay(key: key), confirmed > base { base = confirmed }
        return base
    }
}
