import SwiftUI
import UIKit
import AuthenticationServices

struct TrackerRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: TrackerSession

    init(session: TrackerSession) {
        _session = State(initialValue: session)
    }

    private struct DailyPreloadKey: Equatable {
        let active: Bool
        let allowed: Bool
        let enabled: Bool
        let manualRequestRunning: Bool
        let day: LocalDay?
        let request: AIRequest?
    }

    var body: some View {
        Group {
            if !session.privacy.isReady {
                TrackerPage(title: "Opening Cecy") {
                    if let error = session.privacy.startupError {
                        InlineError(message: error)
                        Button("Retry privacy settings") {
                            session.privacy.start()
                            if session.privacy.canAccess { session.load() }
                            if scenePhase == .active { Task { await session.privacy.unlockAutomatically() } }
                        }.frame(minHeight: 44)
                    } else { ProgressView() }
                }
            } else if session.privacy.isLocked {
                LockedTrackerView(privacy: session.privacy)
            } else if session.account.requiresSignIn {
                NavigationStack { SignedOutAccountView(session: session) }
            } else {
            switch session.phase {
            case .loading:
                ProgressView("Opening your records…")
            case .failed:
                TrackerPage(title: "Your records couldn’t be opened") {
                    TrackerCard {
                        InlineError(message: session.failureMessage ?? "Your data has not been reset.")
                        Button("Try again") { session.load() }
                            .buttonStyle(TrackerPrimaryButtonStyle())
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("retryLoading")
                    }
                }
            case .loaded:
                if let today = session.today, let overview = session.overview {
                    if session.snapshot.onboardingCompletedAt == nil {
                        NavigationStack { OnboardingFlowView(session: session, today: today) }
                    } else {
                        TrackerTabs(session: session, today: today, overview: overview)
                    }
                }
            }
            }
        }
        .tint(Color.accentColor)
        .fontDesign(.rounded)
        .buttonBorderShape(.capsule)
        .environment(\.predictionUpdateInProgress, session.isUpdatingPredictions)
        .disabled(session.isUpdatingPredictions)
        .preferredColorScheme(session.privacy.preferences.appearance.map { $0 == .dark ? ColorScheme.dark : .light })
        .background(PrivacyShield(isActive: scenePhase == .active))
        .task {
            session.privacy.start()
            if scenePhase == .active { await session.privacy.unlockAutomatically() }
            if session.privacy.canAccess && session.phase == .loading { session.load() }
            if session.privacy.canAccess { await session.account.checkCredentialState() }
            if scenePhase == .active { session.resumeRegistry() }
        }
        .task(id: DailyPreloadKey(active: scenePhase == .active, allowed: session.canUseAI,
                                  enabled: session.privacy.dailyInsightsEnabled,
                                  manualRequestRunning: session.ai.isLoading, day: session.today,
                                  request: session.dailyInsightRequest)) {
            if scenePhase == .active { session.preloadDailyInsights() }
        }
        .onChange(of: session.privacy.canAccess) { _, accessible in
            if accessible {
                session.account.reload(); session.load()
                if scenePhase == .active { session.resumeRegistry() }
            }
            else {
                session.registry.pause()
                session.cancelPredictionUpdatePresentation()
                session.healthImport.stop(); session.ai.invalidate(); session.dailyAI.invalidate()
            }
        }
        .onChange(of: session.account.requiresSignIn) { _, required in
            if required {
                session.cancelPredictionUpdatePresentation()
                session.healthImport.stop(); session.ai.invalidate(); session.dailyAI.invalidate()
            }
        }
        .onChange(of: session.privacy.aiEnabled) { _, enabled in
            if !enabled { session.ai.invalidate(); session.dailyAI.invalidate() }
        }
        .onChange(of: session.privacy.dailyInsightsEnabled) { _, enabled in
            if !enabled { session.dailyAI.invalidate() }
        }
        .onChange(of: session.isUpdatingPredictions) { _, updating in
            if updating, scenePhase == .active, session.privacy.canAccess {
                AccessibilityNotification.Announcement("Updating your predictions").post()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.registry.pause()
                session.cancelPredictionUpdatePresentation()
                session.ai.invalidate()
            }
            if phase != .active, session.dailyAI.isLoading { session.dailyAI.cancel() }
            if phase == .active {
                session.refresh()
                session.resumeRegistry()
                Task { await session.privacy.unlockAutomatically() }
            }
            if phase == .background {
                session.healthImport.stop()
                session.cancelSetup()
                session.account.cancelPendingAuthorization()
                session.privacy.wentToBackground()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
            session.account.markRevoked()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            session.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            session.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            session.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cecyReminderSnooze)) { _ in
            session.privacy.snoozeRemindersUntilTomorrow()
        }
    }
}

private struct TrackerTabs: View {
    @Environment(\.scenePhase) private var scenePhase
    let session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    @State private var selectedTab = 0
    @State private var loggingDay: LocalDay?
    @State private var showHistory = false
    @State private var showDailyInsights = false
    @State private var showReminderCheckIn = false
    @State private var followUp: FollowUpPrompt?
    @State private var presentedFollowUp: FollowUpPrompt?
    @State private var followUpHandoff: FollowUpHandoff?
    /// Set when the sheet itself answered, skipped or turned off the question.
    @State private var followUpHandled = false
    @State private var viewingToday = true
    /// Per foreground visit: a visit that opened from a reminder/Shortcut never also shows a question.
    @State private var openedByRoute = false
    /// After today's insights pop-up closes, a question waits a while so the two don't feel back to back.
    @State private var questionNotBefore: Date?

    private struct FollowUpPresentationKey: Equatable {
        let day: LocalDay
        let active: Bool
        let onToday: Bool
        let viewingToday: Bool
        let available: Bool
        let occupied: Bool
        let dailyPending: Bool
        let blockedThisVisit: Bool
    }

    /// Today's insights pop-up still has to show, or is still being prepared. Questions wait until it
    /// has been shown (and closed), so the two never come up at the same time.
    private var dailyInsightsPending: Bool {
        guard session.privacy.preferences.dailyInsightPresentationDay != today.key else { return false }
        return !session.privacy.dailyInsightsEnabled || session.dailyInsightOutput != nil || session.dailyAI.isLoading
    }

    private var followUpKey: FollowUpPresentationKey {
        FollowUpPresentationKey(day: today, active: scenePhase == .active, onToday: selectedTab == 0,
                                viewingToday: viewingToday,
                                available: session.privacy.canAccess && !session.isUpdatingPredictions && !session.isSaving,
                                occupied: loggingDay != nil || showHistory || showDailyInsights || showReminderCheckIn || followUp != nil,
                                dailyPending: dailyInsightsPending,
                                blockedThisVisit: openedByRoute)
    }

    private struct InsightPresentationKey: Equatable {
        let day: LocalDay
        let active: Bool
        let onToday: Bool
        let available: Bool
        let enabled: Bool
        let ready: Bool
        let occupied: Bool
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(session: session, today: today, overview: overview,
                          onLog: { loggingDay = $0 }, onHistory: { showHistory = true },
                          onViewingTodayChange: { viewingToday = $0 })
            }
            .tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
            NavigationStack {
                TrackerCalendarView(session: session, today: today, overview: overview) { loggingDay = $0 }
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }.tag(1)
            NavigationStack { CycleHistoryView(session: session, overview: overview) }
                .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }.tag(2)
            NavigationStack { TrackerSettingsView(session: session) }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .modifier(TrackerTabBarStyle())
        .sheet(item: $loggingDay) { day in
            let currentDay = session.today ?? today
            if day <= currentDay {
                let existing = PeriodLogSelection.existing(on: day, periods: session.snapshot.periods)
                PeriodEntryView(period: existing ?? Period(start: day), today: currentDay,
                                existing: session.snapshot.periods, isEditing: existing != nil,
                                continuation: existing == nil ? PeriodLogSelection.continuation(on: day, periods: session.snapshot.periods) : nil,
                                session: session) { period in
                    await session.withPredictionUpdate {
                        if session.snapshot.periods.contains(where: { $0.id == period.id }) {
                            return session.update(period)
                        }
                        return session.save([period])
                    }
                }
            } else {
                Text("Future dates are for viewing only.").padding()
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HistoryEntryView(session: session, today: session.today ?? today, isOnboarding: false) }
        }
        .sheet(isPresented: $showDailyInsights) {
            NavigationStack {
                AIFeatureView(session: session, feature: .wellness)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showDailyInsights = false }.accessibilityIdentifier("closeDailyInsights")
                        }
                    }
            }
        }
        .sheet(isPresented: $showReminderCheckIn) {
            DailyCheckInView(session: session, day: session.today ?? today)
        }
        .sheet(item: $followUp, onDismiss: followUpDismissed) { prompt in
            FollowUpSheet(session: session, prompt: prompt) { handoff in
                followUpHandled = true
                followUpHandoff = handoff
                followUp = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cecyReminderOpen)) { notification in
            guard let link = notification.object as? String else { return }
            _ = CecyLaunchRoute.consume()
            openedByRoute = true
            if link == "cecy://check-in" { selectedTab = 0; showReminderCheckIn = true }
            else if link == "cecy://forecast" { selectedTab = 1 }
        }
        .onAppear {
            if CecyLaunchRoute.consume() == CecyLaunchRoute.checkIn { openedByRoute = true; selectedTab = 0; showReminderCheckIn = true }
        }
        .onChange(of: showDailyInsights) { _, shown in
            if !shown { questionNotBefore = Date().addingTimeInterval(Double.random(in: 15...25)) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { openedByRoute = false; questionNotBefore = nil }
        }
        .task(id: followUpKey) {
            let key = followUpKey
            guard key.active, key.onToday, key.viewingToday, key.available, !key.occupied,
                  !key.dailyPending, !key.blockedThisVisit else { return }
            // A short random pause: never the instant the app opens, and not at the same moment every
            // visit. Right after the insights pop-up, it waits longer. Spacing is enforced by the engine.
            var delay = Double.random(in: 3...7)
            if let notBefore = questionNotBefore { delay = max(delay, notBefore.timeIntervalSinceNow) }
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard followUpKey == key, let prompt = session.nextFollowUp(), session.markFollowUpShown(prompt) else { return }
            presentedFollowUp = prompt
            followUp = prompt
        }
        .task(id: InsightPresentationKey(day: today, active: scenePhase == .active,
                onToday: selectedTab == 0, available: session.privacy.canAccess && !session.isUpdatingPredictions,
                enabled: session.privacy.dailyInsightsEnabled, ready: session.dailyInsightOutput != nil,
                occupied: loggingDay != nil || showHistory || showDailyInsights || showReminderCheckIn || followUp != nil)) {
            guard scenePhase == .active, selectedTab == 0, session.privacy.canAccess,
                  !session.isUpdatingPredictions, loggingDay == nil, !showHistory, !showDailyInsights,
                  !showReminderCheckIn, followUp == nil,
                  !session.privacy.dailyInsightsEnabled || session.dailyInsightOutput != nil else { return }
            if session.privacy.reserveDailyInsightPresentation(on: today) { showDailyInsights = true }
        }
    }

    /// Swiping the question away without answering counts as "Not now".
    /// Then opens the screen an answer handed off to (log a period or the daily check-in).
    private func followUpDismissed() {
        if let prompt = presentedFollowUp, !followUpHandled { session.snoozeFollowUp(prompt) }
        presentedFollowUp = nil
        followUpHandled = false
        switch followUpHandoff {
        case .logPeriod(let day): loggingDay = day
        case .checkIn: showReminderCheckIn = true
        case nil: break
        }
        followUpHandoff = nil
    }
}

private struct TrackerTabBarStyle: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // TabView owns the rounded Liquid Glass surface, scroll-edge treatment,
            // selection, VoiceOver and Reduce Transparency/Motion adaptations.
            // Do not add a material/background over the native glass tab bar.
            content.tabViewStyle(.tabBarOnly).tabBarMinimizeBehavior(.never)
        } else {
            // Preserve native navigation and accessibility on iOS 17/18.
            content
        }
    }
}

#if DEBUG
#Preview("Tracker · Recorded history") {
    TrackerRootView(session: .preview(withHistory: true))
}
#Preview("Tracker · Onboarding") {
    TrackerRootView(session: .preview(withHistory: false))
}
#Preview("Tracker · Dark") {
    TrackerRootView(session: .preview(withHistory: true)).preferredColorScheme(.dark)
}
#Preview("Tracker · Large text") {
    TrackerRootView(session: .preview(withHistory: true)).environment(\.dynamicTypeSize, .accessibility3)
}
#endif
