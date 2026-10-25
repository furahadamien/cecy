import SwiftUI

struct TodayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    let onLog: (LocalDay) -> Void
    let onHistory: () -> Void
    /// Lets Today's container hold the follow-up pop-up while a past or future day is selected.
    var onViewingTodayChange: ((Bool) -> Void)? = nil
    @State private var showExplanation = false
    @State private var showPersonalization = false
    @State private var selection: LocalDay
    // First-screen fit: the hero fills the space left so the phase tiles end just above the tab bar.
    @State private var viewportHeight: CGFloat = 0
    @State private var stripHeight: CGFloat = 0
    @State private var belowHeroHeight: CGFloat = 0
    @State private var heroCardHeight: CGFloat = 0
    @State private var heroColumnsHeight: CGFloat = 0
    private static let topInset: CGFloat = 6
    private static let sectionSpacing: CGFloat = 12
    /// Breathing room between the phase tiles and the tab bar.
    private static let foldGap: CGFloat = 8

    init(session: TrackerSession, today: LocalDay, overview: CycleOverview, onLog: @escaping (LocalDay) -> Void,
         onHistory: @escaping () -> Void, onViewingTodayChange: ((Bool) -> Void)? = nil) {
        self.session = session
        self.today = today
        self.overview = overview
        self.onLog = onLog
        self.onHistory = onHistory
        self.onViewingTodayChange = onViewingTodayChange
        _selection = State(initialValue: today)
    }

    var body: some View {
        TrackerPage(title: "Today", showsHeading: false,
                    backgroundColor: colorScheme == .dark ? TrackerPalette(scheme: colorScheme).background : Color(red: 0.965, green: 0.980, blue: 0.963),
                    sectionSpacing: Self.sectionSpacing, topInset: Self.topInset) {
            ActivityCalendarStrip(today: today, activityIndex: session.activityIndex,
                                  forecast: session.cycleForecast, selection: $selection, compact: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { stripHeight = $0 }
            hero
            // Measured as one block so the hero can take exactly the space left above the tab bar.
            VStack(alignment: .leading, spacing: Self.sectionSpacing) {
                // Check-in and "Make Cecy yours" share one 44-point row so the phase tiles stay on the first screen.
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) { checkInRow }
                    } else {
                        HStack(spacing: 8) { checkInRow }
                    }
                }
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { loggingButtons }
                    } else {
                        HStack(alignment: .top, spacing: 8) { loggingButtons }
                    }
                }
                .environment(\.todayLogCards, true)
                .disabled(selection > today)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Log for \(DayText.full(selection))")
                .accessibilityIdentifier("todayLogActions")
                CyclePhaseRingView(session: session, today: today, overview: overview)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { belowHeroHeight = $0 }
            ForEach(session.cycleForecast.cycles.filter { selection != today && $0.contains(selection) }) { cycle in
                TrackerCard { ProjectedCycleDetails(cycle: cycle, todayStyle: true) }
            }
            DailyInsightsCard(session: session)
            // New dynamic cards live only in this slot, between insights and the forecast.
            if selection == today { TodayHighlightsView(session: session) }
            if !session.cycleForecast.cycles.isEmpty {
                TrackerCard { UpcomingCycleForecastView(forecast: session.cycleForecast, today: today, todayStyle: true) }
            }
            DailyLogCard(session: session, selectedDay: selection, today: today)
            if let confirmation = session.confirmation {
                TrackerCard {
                    Label(confirmation, systemImage: "checkmark.circle")
                        .accessibilityIdentifier("saveConfirmation")
                    Button("Dismiss confirmation") { session.confirmation = nil }
                }
                .onAppear { AccessibilityNotification.Announcement(confirmation).post() }
            }
            if let insight = session.insights.first { InsightCard(insight: insight) }
            if let message = session.insightMessage { InlineError(message: message) }
        }
        // The page's own size already excludes the status bar and tab bar.
        .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { viewportHeight = $0 }
        .onChange(of: today) { old, new in if selection == old { selection = new } }
        .onChange(of: selection == today, initial: true) { _, viewingToday in onViewingTodayChange?(viewingToday) }
        .sheet(isPresented: $showExplanation) {
            if let estimate = overview.estimate {
                PredictionExplanation(estimate: estimate, sources: Array(overview.intervals.suffix(6)), replay: session.predictionReplay)
            }
        }
    }

    private var needsPersonalization: Bool {
        guard let profile = session.snapshot.profile else { return false }
        return profile.commonSymptoms.isEmpty && profile.cycleContext.isEmpty && profile.goals.isEmpty
            && profile.heightCentimeters == nil && profile.weightKilograms == nil
    }

    @ViewBuilder private var checkInRow: some View {
        DailyCheckInButton(session: session, day: selection)
            .disabled(selection > today)
        if needsPersonalization {
            let palette = TrackerPalette(scheme: colorScheme)
            Button { showPersonalization = true } label: {
                Label("Make Cecy yours", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
                    .frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget)
                    .background(palette.sage, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.accent.opacity(0.25), lineWidth: 1) }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Optional: personalize your profile, reminders and Apple Health import.")
            .accessibilityIdentifier("postOnboardingPersonalization")
            .sheet(isPresented: $showPersonalization) { PersonalizationSheet(session: session) }
        }
    }

    /// Height the ring row should fill so the phase tiles are the last thing above the tab bar.
    /// The card's padding and status row ("chrome") don't depend on the ring row, so this can't feed back on itself.
    private var heroColumnsMinHeight: CGFloat {
        guard viewportHeight > 0, stripHeight > 0, belowHeroHeight > 0, heroColumnsHeight > 0, heroCardHeight > heroColumnsHeight else { return 0 }
        let chrome = heroCardHeight - heroColumnsHeight
        let heroTarget = viewportHeight - Self.topInset - stripHeight - Self.sectionSpacing * 2 - belowHeroHeight - Self.foldGap
        // Capped so tall screens (iPad) don't get an oversized empty card.
        return min(max(0, heroTarget - chrome), 380)
    }

    private var hero: some View {
        TrackerCard(padding: 12, spacing: 8) {
            if dynamicTypeSize > .large {
                VStack(spacing: 16) { heroRing.frame(height: 280); countdown }
            } else {
                // The ring takes most of the width; the window and starter notes live in the forecast card and "?" sheet.
                TodayHeroColumns(minHeight: heroColumnsMinHeight) {
                    heroRing
                    countdown
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { heroColumnsHeight = $0 }
            }
            if let status = TodayCurrentPeriodStatus(periods: session.snapshot.resolvedPeriods,
                                                     forecast: session.cycleForecast, today: today, dailyBleeding: session.snapshot.dailyBleeding) {
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill").font(.title3).foregroundStyle(TrackerPalette(scheme: colorScheme).recorded).accessibilityHidden(true)
                    Text(status.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(status.title)
                .accessibilityIdentifier("currentPeriodStatus")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height.rounded() } action: { heroCardHeight = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nextPeriodCard")
    }

    private var heroRing: some View {
        CyclePhaseRingView(session: session, today: today, overview: overview, ringOnly: true)
    }

    private var countdown: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        let value = TodayPeriodCountdown(outcome: overview.prediction, today: today)
        return VStack(alignment: .leading, spacing: 4) {
            if overview.estimate != nil {
                Button { showExplanation = true } label: {
                    HStack(spacing: 4) {
                        Text("Next period")
                        Image(systemName: "questionmark.circle").accessibilityHidden(true)
                    }
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("How this estimate works")
            } else {
                Text("Next period").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Text(value.title).font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit()
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("periodCountdown")
            if let estimate = overview.estimate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar").foregroundStyle(palette.recorded).accessibilityHidden(true)
                    Text("Around \(DayText.short(estimate.center))")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nextPeriodCenter")
                }
                .font(.subheadline.weight(.medium))
                Text("\(estimate.confidence.rawValue) confidence")
                    .font(.caption2.weight(.semibold)).foregroundStyle(palette.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(palette.sage, in: Capsule())
                    .padding(.top, 4)
                    .accessibilityLabel("\(estimate.confidence.rawValue) confidence, rough estimate")
                    .accessibilityIdentifier("predictionConfidence")
            } else {
                Text(value.detail).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var loggingButtons: some View {
        Button { onLog(selection) } label: {
            Label { Text("Log period") } icon: { Image(systemName: "drop.fill").foregroundStyle(TrackerPalette(scheme: colorScheme).recorded) }
        }
        .buttonStyle(TrackerCompactLogButtonStyle(prominent: true))
        .accessibilityLabel("Log period")
        .accessibilityHint("Record a period start or update its end date.")
        .accessibilityIdentifier("logPeriod")
        SymptomLogButton(session: session, day: selection, title: "Symptoms", compact: true)
        SexualActivityLogButton(session: session, day: selection, compact: true)
        DailyBleedingLogButton(session: session, day: selection)
    }

}

/// "Make Cecy yours": the same optional links that used to sit in a card on Today.
private struct PersonalizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession

    var body: some View {
        NavigationStack {
            SettingsForm(title: "Make Cecy yours") {
                Section {
                    Text("Optional answers can put common symptoms first and tailor your experience. Add them whenever you’re ready.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink { ProfileSettingsView(session: session) } label: {
                        Label("Personalize profile", systemImage: "person.crop.circle")
                    }
                    NavigationLink { ReminderSettingsView(privacy: session.privacy) } label: {
                        Label("Choose reminders", systemImage: "bell")
                    }
                    NavigationLink { HealthImportSettingsView(session: session) } label: {
                        Label("Review Apple Health import", systemImage: "heart.text.square")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("personalizationSheet")
    }
}

/// Propose each column's actual width rather than testing unwrapped text widths.
private struct TodayHeroColumns: Layout {
    /// Extra height to fill so the first screen ends at the phase tiles; content is centred within it.
    var minHeight: CGFloat = 0
    private let spacing: CGFloat = 12

    private func columns(_ width: CGFloat) -> (ring: CGFloat, detail: CGFloat) {
        // Leaves ~100 pt for the countdown on an iPhone; the countdown wraps rather than truncates.
        let ring = min(300, width * 0.68)
        return (ring, max(0, width - ring - spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 330
        let sizes = columns(width)
        let detail = subviews[1].sizeThatFits(ProposedViewSize(width: sizes.detail, height: nil))
        return CGSize(width: width, height: max(sizes.ring, detail.height, minHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let sizes = columns(bounds.width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY - sizes.ring / 2), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes.ring, height: sizes.ring))
        // Centre the countdown beside the ring.
        let detail = subviews[1].sizeThatFits(ProposedViewSize(width: sizes.detail, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.minX + sizes.ring + spacing, y: bounds.midY - detail.height / 2), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes.detail, height: detail.height))
    }
}

/// Uses today's evidence, not the selected calendar day or an assumed ongoing period.
nonisolated enum TodayCurrentPeriodStatus: Equatable {
    case recorded, estimated

    init?(periods: [Period], forecast: CycleForecast, today: LocalDay, dailyBleeding: [DailyBleedingObservation] = []) {
        if PeriodLogSelection.existing(on: today, periods: periods, dailyBleeding: dailyBleeding) != nil {
            self = .recorded
        } else if forecast.bleeding(on: today) != nil {
            self = .estimated
        } else {
            return nil
        }
    }

    var title: String {
        self == .recorded ? "You’re on your period" : "You may be on your period"
    }
}

/// Presentation only: never rolls a missed estimate into an unrecorded new cycle.
@MainActor struct TodayPeriodCountdown {
    let title: String
    let detail: String

    init(outcome: PredictionOutcome, today: LocalDay) {
        switch outcome {
        case .available(let estimate):
            let days = today.days(until: estimate.center)
            if days > 0 {
                title = days == 1 ? "About 1 day" : "About \(days) days"
            } else if days == 0 {
                title = "Estimated today"
            } else if today <= estimate.latest {
                title = "Within estimated window"
            } else {
                title = "Estimated window passed"
            }
            detail = "Possible start: \(DayText.range(estimate.earliest, estimate.latest)). An estimate, not a deadline. Missing records can affect it."
        case .insufficientHistory:
            title = "More history needed"
            detail = "Log periods as they happen. Estimates can come later."
        case .wideVariation:
            title = "Timing uncertain"
            detail = "Your recorded cycles vary. Keep tracking without a date estimate."
        case .unavailable(let reason):
            title = "Estimate unavailable"
            detail = reason.localizedDescription
        }
    }
}

struct PredictionExplanation: View {
    @Environment(\.dismiss) private var dismiss
    let estimate: CyclePrediction
    let sources: [CycleInterval]
    let replay: PredictionReplay?

    var body: some View {
        NavigationStack {
            TrackerPage(title: "About this estimate") {
                TrackerCard(highlighted: true) {
                    Text(DayText.range(estimate.earliest, estimate.latest)).font(TrackerTypography.sectionTitle)
                    Text("Possible next start dates, not a predicted bleeding duration.")
                    Text("\(estimate.confidence.rawValue) confidence · Provisional")
                }
                if let notice = estimate.starterNotice {
                    TrackerCard {
                        Text("A starting point, not measured history").font(.headline)
                        Text(notice).accessibilityIdentifier("starterPrediction")
                        Text("We count from your recorded start, with three days on either side of the estimated next start. This is a rough range, not a probability.")
                        Text("New records replace assumptions. Estimated period days never become recorded days, and an overdue estimate does not start a new cycle.")
                    }
                } else {
                TrackerCard {
                    Text("The recorded intervals behind it").font(.headline)
                    Text(estimate.sourceLengths.map { "\($0)" }.joined(separator: ", ") + " days")
                    Text("The same calculation works from the first recorded start onward. With measured intervals available, it uses up to six recent intervals: the median for the center and two days around the shortest and longest. One interval is limited evidence, not an established pattern.")
                    Text(PredictionEvidence.policy).font(.caption)
                    if let replay {
                        Text(PredictionEvidence.assess(sourceLengths: estimate.sourceLengths, replay: replay).reason)
                            .accessibilityIdentifier("confidenceReason")
                    }
                    Text("Confidence thresholds are provisional display rules, not measured probabilities. Historical coverage is not a future probability.")
                    Text("There is no guaranteed start date. Records are never discarded merely because an interval is unusual.")
                        .foregroundStyle(.secondary)
                }
                TrackerCard {
                    Text("Source dates").font(.headline)
                    ForEach(sources) { source in
                        Text("\(DayText.range(source.start, source.nextStart)): \(source.length) days")
                    }
                    Text("Intervals older than the six most recent remain in your records but do not enter this window. No interval is excluded for being unusually long or short.")
                }
                NavigationLink("Prediction history check") { PredictionHistoryView(replay: replay) }
                    .frame(minHeight: 44).accessibilityIdentifier("predictionReplayLink")
                }
                Text(OvulationNotice.explanation).font(.footnote)
                Text("This is an uncalibrated estimate, not medical advice. Missing records affect it. Do not use it for contraception or diagnosis.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
