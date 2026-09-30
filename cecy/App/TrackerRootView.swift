import SwiftUI
import UIKit

struct TrackerRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var session: TrackerSession

    init(session: TrackerSession) {
        _session = State(initialValue: session)
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
                        }.frame(minHeight: 44)
                    } else { ProgressView() }
                }
            } else if session.privacy.isLocked {
                LockedTrackerView(privacy: session.privacy)
            } else {
            switch session.phase {
            case .loading:
                ProgressView("Opening your records…")
            case .failed:
                TrackerPage(title: "Your records couldn’t be opened") {
                    TrackerCard {
                        InlineError(message: session.failureMessage ?? "Your data has not been reset.")
                        Button("Try again") { session.load() }
                            .buttonStyle(.borderedProminent)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("retryLoading")
                    }
                }
            case .loaded:
                if let today = session.today, let overview = session.overview {
                    if session.snapshot.onboardingCompletedAt == nil {
                        NavigationStack { HistoryEntryView(session: session, today: today) }
                    } else {
                        TrackerTabs(session: session, today: today, overview: overview)
                    }
                }
            }
            }
        }
        .tint(TrackerPalette(scheme: colorScheme).accent)
        .background(PrivacyShield(isActive: scenePhase == .active))
        .task {
            session.privacy.start()
            if session.privacy.canAccess && session.phase == .loading { session.load() }
        }
        .onChange(of: session.privacy.canAccess) { _, accessible in
            if accessible { session.load() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.refresh() }
            if phase == .background { session.privacy.wentToBackground() }
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
    }
}

private struct TrackerTabs: View {
    let session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    @State private var selectedTab = 0
    @State private var loggingDay: LocalDay?
    @State private var showHistory = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(session: session, today: today, overview: overview,
                          onLog: { loggingDay = $0 }, onHistory: { showHistory = true })
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
        .sheet(item: $loggingDay) { day in
            PeriodEntryView(period: Period(start: day), today: session.today ?? today,
                            existing: session.snapshot.periods) { period in session.save([period]) }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HistoryEntryView(session: session, today: session.today ?? today, isOnboarding: false) }
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
