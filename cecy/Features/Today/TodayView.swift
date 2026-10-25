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
                PredictionExplanation(estimate: estimate)
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
                // The ring is centred and as large as the card allows; the countdown sits underneath it.
                TodayHeroStack(minHeight: heroColumnsMinHeight) {
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
        let value = TodayPeriodCountdown(outcome: overview.prediction, today: today)
        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                if let days = value.daysAway {
                    let count = days == 1 ? String(localized: "1 day") : String(localized: "\(days) days")
                    Text("Next period in about \(Text(count).bold().foregroundStyle(.primary))")
                        .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        .accessibilityLabel(String(localized: "Next period in about \(count)"))
                        .accessibilityIdentifier("periodCountdown")
                } else {
                    Text("Next period").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text(value.title).font(.subheadline.bold())
                        .accessibilityIdentifier("periodCountdown")
                }
                if overview.estimate != nil {
                    Button { showExplanation = true } label: {
                        Image(systemName: "questionmark.circle").font(.subheadline).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            // Full 44-pt tap area without making the row taller (the height goes to the ring).
                            .contentShape(Rectangle().inset(by: -14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("How this estimate works")
                }
            }
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.8)
            if let estimate = overview.estimate {
                Text("Around \(DayText.monthDay(estimate.center))")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityLabel("Around \(DayText.monthDay(estimate.center)), estimated")
                    .accessibilityIdentifier("nextPeriodCenter")
            } else {
                Text(value.detail).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
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

/// Ring centred on top, countdown underneath. The ring grows into whatever height the card is given
/// (so the first screen ends at the phase tiles), bounded by the card width.
private struct TodayHeroStack: Layout {
    /// Height to fill so the first screen ends at the phase tiles; content is centred within it.
    var minHeight: CGFloat = 0
    private let spacing: CGFloat = 6
    private let smallestRing: CGFloat = 160
    private let largestRing: CGFloat = 320

    private func measure(_ width: CGFloat, _ subviews: Subviews) -> (ring: CGFloat, detail: CGFloat) {
        let detail = subviews[1].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        // Before the first measurement arrives, use a width-based size so the card never starts tiny.
        let byHeight = minHeight > 0 ? minHeight - detail - spacing : width * 0.68
        let ring = min(width, largestRing, max(smallestRing, byHeight))
        return (ring, detail)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let width = proposal.width ?? 330
        let sizes = measure(width, subviews)
        return CGSize(width: width, height: max(sizes.ring + spacing + sizes.detail, minHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let sizes = measure(bounds.width, subviews)
        let top = bounds.midY - (sizes.ring + spacing + sizes.detail) / 2
        subviews[0].place(at: CGPoint(x: bounds.midX - sizes.ring / 2, y: top), anchor: .topLeading,
                          proposal: ProposedViewSize(width: sizes.ring, height: sizes.ring))
        subviews[1].place(at: CGPoint(x: bounds.minX, y: top + sizes.ring + spacing), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: sizes.detail))
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
    /// Days until the estimated start, when it's still ahead.
    var daysAway: Int?

    init(outcome: PredictionOutcome, today: LocalDay) {
        switch outcome {
        case .available(let estimate):
            let days = today.days(until: estimate.center)
            if days > 0 {
                daysAway = days
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

/// The "?" next to the countdown: just the expected start window.
struct PredictionExplanation: View {
    @Environment(\.dismiss) private var dismiss
    let estimate: CyclePrediction

    var body: some View {
        NavigationStack {
            TrackerPage(title: "About this estimate") {
                TrackerCard(highlighted: true) {
                    Text(DayText.range(estimate.earliest, estimate.latest)).font(TrackerTypography.sectionTitle)
                        .accessibilityIdentifier("estimateWindow")
                    Text("Your period is expected to start around these dates.")
                        .accessibilityIdentifier("estimateWindowExplanation")
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
