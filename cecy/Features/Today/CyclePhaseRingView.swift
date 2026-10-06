import SwiftUI

struct CyclePhaseRingView: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    @State private var selectedPhase: CyclePhase?

    private var timeline: CyclePhaseTimeline? {
        CyclePhaseTimeline.make(overview: overview, forecast: session.cycleForecast, periods: session.snapshot.periods,
                                profile: session.snapshot.profile, today: today)
    }

    var body: some View {
        TrackerCard {
            Text("Your cycle phases").font(.headline).accessibilityAddTraits(.isHeader)
            if let timeline {
                PhaseRingGraphic(timeline: timeline) { selectedPhase = $0 }
                    .frame(maxWidth: 280).frame(height: 260)
                    .frame(maxWidth: .infinity)
                if let phase = timeline.currentPhase {
                    Label("\(phase.title) · \(timeline.currentIsRecorded ? "Recorded bleeding" : "Estimated phase")", systemImage: phase.symbol)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("currentCyclePhase")
                    Text(phase.explanation).font(.subheadline)
                } else {
                    Text(timeline.markerDay == nil
                         ? "Day \(timeline.cycleDay) is beyond this estimated cycle. No new period has been assumed."
                         : "Your cycle context makes the current phase uncertain.")
                        .font(.subheadline).accessibilityIdentifier("uncertainCyclePhase")
                }
                Text("\(timeline.length)-day estimated cycle · Today: day \(timeline.cycleDay)")
                    .font(.footnote).monospacedDigit().accessibilityIdentifier("phaseCycleLength")
                Text("Solid inner arc: recorded bleeding. Dashed arcs: estimated phases. Dot: today. Pale outer band: estimated fertile window.")
                    .font(.caption).foregroundStyle(.secondary)
                if let days = timeline.fertileDays {
                    Text("Estimated fertile window: days \(days.lowerBound)–\(days.upperBound), not a multi-day ovulation phase.")
                        .font(.caption).accessibilityIdentifier("phaseFertileWindow")
                }
            } else {
                Text("Phase timing is unavailable. Record period dates and a typical bleeding length; irregular or conflicting estimates may not support a phase ring.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("phaseTimelineUnavailable")
            }
            ForEach(CyclePhase.allCases) { phase in
                Button { selectedPhase = phase } label: {
                    HStack {
                        Label(phase.title, systemImage: phase.symbol)
                        Spacer(minLength: 8)
                        if timeline?.currentPhase == phase { Image(systemName: "checkmark.circle.fill") }
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(TrackerPalette(scheme: colorScheme).accent)
                .accessibilityValue(timeline?.currentPhase == phase ? "Current phase" : "")
                .accessibilityHint("Opens the phase range and explanation")
                .accessibilityIdentifier("cyclePhase_\(phase.rawValue)")
            }
            Text("Calendar estimates—not confirmed ovulation or safe days. Do not use for contraception.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cyclePhaseRing")
        .sheet(item: $selectedPhase) { phase in
            CyclePhaseDetailsView(phase: phase, timeline: timeline, insights: session.insights)
        }
    }
}

private struct PhaseRingGraphic: View {
    @Environment(\.colorScheme) private var colorScheme
    let timeline: CyclePhaseTimeline
    let select: (CyclePhase) -> Void

    private func color(_ phase: CyclePhase) -> Color {
        let palette = TrackerPalette(scheme: colorScheme)
        switch phase {
        case .menstrual: return palette.recorded
        case .follicular: return palette.accent
        case .ovulation: return palette.sexualActivity
        case .luteal: return .orange
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.1), lineWidth: 18).padding(28)
                if let fertile = timeline.fertileDays {
                    arc(fertile, inset: 9)
                        .stroke(TrackerPalette(scheme: colorScheme).accent.opacity(0.3), style: StrokeStyle(lineWidth: 8, dash: [2, 2]))
                }
                ForEach(timeline.segments) { segment in
                    arc(segment.days, inset: 28)
                        .stroke(color(segment.phase), style: StrokeStyle(lineWidth: timeline.currentPhase == segment.phase ? 24 : 16,
                                                                         dash: segment.phase == .ovulation ? [2, 2] : [6, 2]))
                }
                arc(timeline.recordedBleeding, inset: 46)
                    .stroke(color(.menstrual), lineWidth: 5)
                if let day = timeline.markerDay {
                    let angle = (Double(day) - 0.5) / Double(timeline.length) * 2 * Double.pi - Double.pi / 2
                    Circle().fill(Color.primary).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .position(x: center.x + cos(angle) * (size / 2 - 28), y: center.y + sin(angle) * (size / 2 - 28))
                }
                VStack(spacing: 4) {
                    Text("Day \(timeline.cycleDay)").font(.title2.weight(.semibold)).monospacedDigit()
                    Text("of ~\(timeline.length)").font(.caption)
                }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let dx = location.x - center.x, dy = location.y - center.y
                let radius = sqrt(dx * dx + dy * dy)
                guard radius >= size / 2 - 56, radius <= size / 2 else { return }
                let angle = (atan2(dy, dx) + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
                let day = min(timeline.length, Int(angle / (2 * .pi) * Double(timeline.length)) + 1)
                if let segment = timeline.segments.first(where: { $0.days.contains(day) }) { select(segment.phase) }
            }
        }
        // Equivalent full-size labelled buttons below expose all phases to assistive input.
        .accessibilityHidden(true)
    }

    private func arc(_ days: ClosedRange<Int>, inset: CGFloat) -> some Shape {
        RingDayArc(lower: Double(days.lowerBound - 1) / Double(timeline.length),
                   upper: Double(days.upperBound) / Double(timeline.length), inset: inset)
    }
}

private struct RingDayArc: Shape {
    let lower: Double
    let upper: Double
    let inset: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: max(0, min(rect.width, rect.height) / 2 - inset),
                    startAngle: .degrees(lower * 360 - 90), endAngle: .degrees(upper * 360 - 90), clockwise: false)
        return path
    }
}

private struct CyclePhaseDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let phase: CyclePhase
    let timeline: CyclePhaseTimeline?
    let insights: [CycleInsight]

    var body: some View {
        NavigationStack {
            TrackerPage(title: phase.title) {
                if let timeline, let range = timeline.dateRange(for: phase),
                   let segment = timeline.segments.first(where: { $0.phase == phase }) {
                    Text("\(phase == .menstrual && !timeline.bleedingIsEstimated ? "Recorded" : "Estimated") days \(segment.days.lowerBound)–\(segment.days.upperBound)")
                        .font(.headline).accessibilityIdentifier("phaseDayRange")
                    Text(DayText.range(range.start, range.end)).font(.subheadline)
                    ForEach(timeline.warnings, id: \.self) { Text($0).font(.footnote) }
                } else { Text("No separate day range can be estimated from these records.").font(.subheadline) }
                Text(phase.explanation)
                Text("Common experiences").font(.headline)
                Text(phase.experiences).font(.subheadline)
                Text("Experiences vary; these are possibilities, not a prediction about you.").font(.caption).foregroundStyle(.secondary)
                let patterns = CyclePhaseTimeline.patterns(for: phase, insights: insights)
                if !patterns.isEmpty {
                    Text("Your recorded patterns near period starts").font(.headline)
                    ForEach(patterns) { insight in
                        Text(insight.title).font(.subheadline.weight(.semibold))
                        Text(insight.explanation).font(.footnote)
                    }
                    Text("Start-relative patterns do not confirm a hormonal phase.").font(.caption)
                } else {
                    Text("No repeated personal pattern is established here yet.").font(.footnote).foregroundStyle(.secondary)
                }
                if phase == .follicular {
                    Text("Biologically, the follicular phase includes menstruation. The ring shows bleeding separately for clarity.").font(.footnote)
                }
                Text("Timing comes from the existing calendar estimate, not hormone measurements. Not for contraception.").font(.footnote)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}