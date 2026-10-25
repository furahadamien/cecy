import SwiftUI

struct DailyInsightsPreference: View {
    let session: TrackerSession
    @State private var confirmEnable = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AIConsentControl(session: session)
            Toggle("Prepare automatically on Today", isOn: Binding(
                get: { session.privacy.dailyInsightsEnabled },
                set: { enabled in
                    if enabled { confirmEnable = true }
                    else {
                        session.dailyAI.invalidate()
                        error = session.privacy.setDailyInsightsEnabled(false)
                    }
                }))
                .disabled(!session.canUseAI || (session.dailyInsightRequest == nil && !session.privacy.dailyInsightsEnabled))
                .accessibilityIdentifier("dailyInsightsToggle")
            if session.snapshot.profile?.wellnessPreferences?.isReadyForInsights != true {
                Text(session.privacy.dailyInsightsEnabled ? "Preparation paused · Finish setup" : "Finish setup to prepare daily insights.")
                    .font(.caption).foregroundStyle(.secondary)
                NavigationLink("Finish insight setup") { DailyInsightSetupView(session: session) }
                    .accessibilityIdentifier("finishInsightSetup")
            }
            if let error { InlineError(message: error) }
        }
        .alert("Prepare daily insights automatically?", isPresented: $confirmEnable) {
            Button("Not now", role: .cancel) {}
            Button("Enable daily insights") {
                error = session.privacy.setDailyInsightsEnabled(true)
                if error == nil { session.preloadDailyInsights() }
            }.accessibilityIdentifier("enableDailyInsights")
        } message: {
            Text("Once a day when you open Cecy, your cycle day, an estimated cycle phase and its uncertainty, today’s bleeding or spotting answer, today’s selected symptoms, activity, exercise, diet, allergies and wellness goals may be sent to Azure and OpenAI. No dates, private notes, identity, sexual-activity records or full history are sent. Results cover self-care, food, movement, hydration, recovery and skincare, appear on Today and stay on this device until the day ends. Turn this off here or in Privacy and export.")
        }
    }
}

struct DailyInsightsCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    /// nil until the user taps a row; until then only the first section is open.
    @State private var openSections: Set<DailyInsightSectionKind>?

    var body: some View {
        TrackerCard {
            InsightSectionHeader(title: "Today’s insights", symbol: "sparkles",
                                 subtitle: "Personalized suggestions for today.")
            if let output = session.dailyInsightOutput, case .dailyInsights(let value) = output {
                WellnessSafetyNotice(symptoms: session.snapshot.symptoms, today: session.today)
                AISafetyNotice(message: value.safetyMessage)
                VStack(spacing: 12) {
                    ForEach(value.sections, id: \.kind) { section in
                        DailyInsightAccordionRow(section: section,
                                                 isExpanded: isOpen(section.kind, first: value.sections.first?.kind))
                    }
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("todayWellnessSuggestions")
                DisclosureGroup("Why these?") { Text(verbatim: value.explanation).font(.subheadline).padding(.top, 6) }
                    .font(.subheadline)
                Text("AI-generated · Not medical advice. Check ingredients against your allergies.")
                    .font(.caption).foregroundStyle(.secondary)
                Button { session.regenerateTodayInsights() } label: {
                    Label("Regenerate insights", systemImage: "arrow.clockwise").font(.subheadline)
                        .foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
                }
                .buttonStyle(.plain).frame(minHeight: 44)
                .disabled(session.dailyAI.isLoading)
                .accessibilityIdentifier("regenerateDailyInsights")
            } else {
                if session.dailyAI.isLoading {
                    AIRequestStatus(coordinator: session.dailyAI, label: "Preparing today’s insights")
                } else if session.snapshot.profile?.wellnessPreferences?.isReadyForInsights != true {
                    Text(session.privacy.dailyInsightsEnabled ? "Preparation paused · Finish setup" : "Personalize your daily insights")
                        .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("dailyInsightsNeedsSetup")
                    NavigationLink("Finish insight setup") { DailyInsightSetupView(session: session) }
                        .frame(minHeight: 44).accessibilityIdentifier("finishInsightSetup")
                } else if !session.canUseAI {
                    AIConsentControl(session: session)
                } else {
                    AIRequestStatus(coordinator: session.dailyAI)
                    Text(session.dailyAI.message == nil ? "Today’s insights haven’t been prepared yet." : "Today’s insights couldn’t be prepared.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(session.dailyAI.message == nil ? "Prepare today’s insights" : "Try again") {
                        session.prepareTodayInsights()
                    }.buttonStyle(TrackerPrimaryButtonStyle()).accessibilityIdentifier("prepareDailyInsights")
                }
            }
            NavigationLink { AIFeatureView(session: session, feature: .wellness) } label: {
                Label("Insight settings", systemImage: "slider.horizontal.3")
                    .font(.subheadline).frame(minHeight: 44)
            }.buttonStyle(.plain).accessibilityIdentifier("dailyWellnessAI")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyInsightsCard")
        .task(id: session.dailyInsightRequest) { session.preloadDailyInsights() }
    }

    private func isOpen(_ kind: DailyInsightSectionKind, first: DailyInsightSectionKind?) -> Binding<Bool> {
        Binding(
            get: { openSections?.contains(kind) ?? (kind == first) },
            set: { open in
                var sections = openSections ?? Set(first.map { [$0] } ?? [])
                if open { sections.insert(kind) } else { sections.remove(kind) }
                openSections = sections
            })
    }
}

/// Colour and icon for each daily insight category.
struct DailyInsightSectionStyle {
    let tint: Color
    let tile: Color
    let symbol: String

    init(kind: DailyInsightSectionKind, scheme: ColorScheme) {
        let palette = TrackerPalette(scheme: scheme)
        let dark = scheme == .dark
        switch kind {
        case .selfCare:
            tint = palette.recorded; tile = palette.recordedSurface; symbol = "heart"
        case .food:
            tint = dark ? Color(red: 0.95, green: 0.80, blue: 0.50) : Color(red: 0.55, green: 0.38, blue: 0.08)
            tile = dark ? Color(red: 0.27, green: 0.22, blue: 0.12) : Color(red: 0.99, green: 0.95, blue: 0.86)
            symbol = "fork.knife"
        case .movement:
            tint = palette.accent; tile = palette.sage; symbol = "figure.run"
        case .hydration:
            tint = dark ? Color(red: 0.62, green: 0.80, blue: 0.96) : Color(red: 0.16, green: 0.38, blue: 0.60)
            tile = dark ? Color(red: 0.13, green: 0.20, blue: 0.28) : Color(red: 0.90, green: 0.95, blue: 0.99)
            symbol = "drop"
        case .recovery:
            tint = palette.ovulation; tile = palette.ovulationSurface; symbol = "leaf"
        case .skincare:
            tint = dark ? Color(red: 0.98, green: 0.72, blue: 0.60) : Color(red: 0.66, green: 0.32, blue: 0.20)
            tile = dark ? Color(red: 0.28, green: 0.17, blue: 0.14) : Color(red: 0.99, green: 0.92, blue: 0.88)
            symbol = "sparkle"
        }
    }
}

/// One collapsible insight category. Generated text uses Text(verbatim:).
private struct DailyInsightAccordionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var tileSize = 44.0
    let section: DailyInsightSection
    @Binding var isExpanded: Bool

    var body: some View {
        let style = DailyInsightSectionStyle(kind: section.kind, scheme: colorScheme)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: style.symbol)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(style.tint)
                        .frame(width: min(tileSize, 60), height: min(tileSize, 60))
                        .background(style.tile, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    Text(section.kind.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(12)
                .frame(minHeight: TrackerLayout.minimumTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.kind.title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Hides these suggestions" : "Shows these suggestions")
            .accessibilityIdentifier("dailyInsightToggle_\(section.kind.rawValue)")

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    if section.status == .available {
                        ForEach(Array(section.suggestions.enumerated()), id: \.offset) { _, item in
                            Text(verbatim: item)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(DailyInsightSectionView.message(for: section.unavailableReason))
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("dailyInsightUnavailable_\(section.kind.rawValue)")
                    }
                }
                .lineSpacing(3)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
        .background(style.tile.opacity(isExpanded ? 0.55 : 0.35), in: shape)
        .overlay {
            shape.strokeBorder(style.tint.opacity(contrast == .increased ? 0.6 : (isExpanded ? 0.16 : 0.08)), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyInsightSection_\(section.kind.rawValue)")
    }
}

struct DailyInsightSetupView: View {
    let session: TrackerSession
    @State private var preferences: WellnessPreferences?

    init(session: TrackerSession) {
        self.session = session
        _preferences = State(initialValue: session.snapshot.profile?.wellnessPreferences)
    }

    var body: some View {
        WellnessPreferencesView(preferences: $preferences,
            saveTitle: session.canUseAI ? "Save & prepare" : "Save",
            onSave: session.saveDailyInsightPreferences)
    }
}

/// Both tabs observe the same coordinator; presentation never starts a second request.
struct DailyInsightsContent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: TrackerSession
    var styled = false

    var body: some View {
        Group {
            if let output = session.dailyInsightOutput {
                Text("AI-generated daily insights").font(.caption).foregroundStyle(.secondary)
                AIOutputView(output: output)
            } else if let today = session.today {
                let answers = PreparedRecordAnswers.build(snapshot: session.snapshot, today: today)
                if styled {
                    let periods = session.snapshot.periods.filter { $0.start <= today }
                    let ends = periods.filter { $0.end != nil }.count
                    let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
                    layout {
                        metric(periods.count, title: "period starts recorded", symbol: "drop.fill", tint: TrackerPalette(scheme: colorScheme).recorded)
                        metric(ends, title: "confirmed ends", symbol: "circle.dashed", tint: TrackerPalette(scheme: colorScheme).accent)
                    }
                    .padding(14)
                    .background(TrackerPalette(scheme: colorScheme).sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(answers[0].answer)
                    .accessibilityIdentifier("localPeriodFacts")
                    if ends < periods.count {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle").foregroundStyle(TrackerPalette(scheme: colorScheme).recorded).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Missing period ends").font(.headline)
                                Text("Add an end when known to track bleeding duration.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(TrackerPalette(scheme: colorScheme).recordedSurface, in: RoundedRectangle(cornerRadius: 20))
                    }
                } else {
                    Text(answers[0].answer).font(.subheadline)
                }
                Text(answers[1].answer).font(.footnote).foregroundStyle(.secondary)
                Text("Calculated on this device").font(.caption).foregroundStyle(.secondary)
            }
            AIRequestStatus(coordinator: session.dailyAI)
        }
    }

    private func metric(_ count: Int, title: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.title2).foregroundStyle(tint)
                .frame(width: 42, height: 42).background(tint.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(count.formatted()).font(TrackerTypography.metric).monospacedDigit()
                Text(title).font(.subheadline).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
