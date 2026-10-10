import SwiftUI

struct CyclePhaseRingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: TrackerSession
    let today: LocalDay
    let overview: CycleOverview
    var ringOnly = false
    @State private var selectedPhase: CyclePhase?

    private var timeline: CyclePhaseTimeline? {
        CyclePhaseTimeline.make(overview: overview, forecast: session.cycleForecast, periods: session.snapshot.periods,
                                profile: session.snapshot.profile, today: today)
    }

    var body: some View {
        Group {
            if ringOnly {
                if let timeline {
                    PhaseRingGraphic(timeline: timeline) { selectedPhase = $0 }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "circle.dashed").font(.largeTitle).foregroundStyle(.secondary)
                        if let day = overview.currentDay {
                            Text("Day \(day)").font(.title2.bold()).monospacedDigit()
                                .accessibilityIdentifier("cycleDay")
                        }
                        Text("Phase timing unavailable")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            .accessibilityIdentifier("phaseTimelineUnavailable")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            phaseHeading
                            Spacer(minLength: 12)
                            fertileCaption
                        }
                        VStack(alignment: .leading, spacing: 4) { phaseHeading; fertileCaption }
                    }
                    EqualHeightPhaseLayout(columns: dynamicTypeSize.isAccessibilitySize ? 1 : dynamicTypeSize > .large ? 2 : 4) {
                        phaseTiles
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("cyclePhaseTiles")
            }
        }
        .sheet(item: $selectedPhase) { phase in
            CyclePhaseDetailsView(phase: phase, timeline: timeline, insights: session.insights)
        }
    }

    private var phaseHeading: some View {
        Text("Your cycle phases").font(.headline).accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var fertileCaption: some View {
        if let days = timeline?.fertileDays {
            Text("Estimated fertile window: days \(days.lowerBound)–\(days.upperBound)")
                .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("phaseFertileWindow")
        }
    }

    private var phaseTiles: some View {
        ForEach(CyclePhase.allCases) { phase in
            let palette = TrackerPalette(scheme: colorScheme)
            let current = timeline?.currentPhase == phase
            let tint = phase == .menstrual ? palette.recorded : palette.accent
            Button { selectedPhase = phase } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: phase.symbol).font(.title3).foregroundStyle(tint)
                        Spacer(minLength: 0)
                        if current { Image(systemName: "checkmark.circle.fill").foregroundStyle(tint) }
                    }.accessibilityHidden(true)
                    Text(phase.title).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                    if let days = timeline?.segments.first(where: { $0.phase == phase })?.days {
                        Text(days.lowerBound == days.upperBound ? "Day \(days.lowerBound)" : "Days \(days.lowerBound)–\(days.upperBound)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
                .background(phase == .menstrual ? palette.recordedSurface : phase == .follicular ? Color.orange.opacity(0.08) : palette.sage.opacity(0.55),
                            in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(current ? tint : .clear, lineWidth: 1.5))
                .contentShape(RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)
            .accessibilityValue(current ? "Current phase · \(timeline?.currentIsRecorded == true ? "Recorded bleeding" : "Estimated")" : "")
            .accessibilityHint("Opens the phase range and explanation")
            .accessibilityIdentifier("cyclePhase_\(phase.rawValue)")
        }
    }

}

/// All cards use the tallest natural content height, including at larger text sizes.
struct EqualHeightPhaseLayout: Layout {
    let columns: Int
    private let spacing: CGFloat = 8

    private func tileSize(width: CGFloat, subviews: Subviews) -> CGSize {
        let count = max(1, columns)
        let tileWidth = max(0, (width - CGFloat(count - 1) * spacing) / CGFloat(count))
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: tileWidth, height: nil)).height }.max() ?? 0
        return CGSize(width: tileWidth, height: height)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 330
        let tile = tileSize(width: width, subviews: subviews)
        let rows = (subviews.count + max(1, columns) - 1) / max(1, columns)
        return CGSize(width: width, height: CGFloat(rows) * tile.height + CGFloat(max(0, rows - 1)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let tile = tileSize(width: bounds.width, subviews: subviews)
        for index in subviews.indices {
            let row = index / max(1, columns), column = index % max(1, columns)
            subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(column) * (tile.width + spacing),
                                             y: bounds.minY + CGFloat(row) * (tile.height + spacing)),
                                  anchor: .topLeading, proposal: ProposedViewSize(tile))
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
                Circle().stroke(Color.secondary.opacity(0.1), lineWidth: size * 0.065).padding(size * 0.1)
                if let fertile = timeline.fertileDays {
                    arc(fertile, inset: size * 0.035)
                        .stroke(TrackerPalette(scheme: colorScheme).accent.opacity(0.3), style: StrokeStyle(lineWidth: size * 0.025, dash: [2, 2]))
                }
                ForEach(timeline.segments) { segment in
                    arc(segment.days, inset: size * 0.1)
                        .stroke(color(segment.phase), style: StrokeStyle(lineWidth: size * (timeline.currentPhase == segment.phase ? 0.085 : 0.065),
                                                                         dash: segment.phase == .ovulation ? [2, 2] : [6, 2]))
                }
                arc(timeline.recordedBleeding, inset: size * 0.17)
                    .stroke(color(.menstrual), lineWidth: size * 0.018)
                if let day = timeline.markerDay {
                    let angle = (Double(day) - 0.5) / Double(timeline.length) * 2 * Double.pi - Double.pi / 2
                    Circle().fill(Color.primary).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .position(x: center.x + cos(angle) * size * 0.4, y: center.y + sin(angle) * size * 0.4)
                }
                VStack(spacing: 4) {
                    Text("Day \(timeline.cycleDay)").font(.title2.weight(.bold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityIdentifier("cycleDay")
                    Text("of ~\(timeline.length)").font(.caption)
                    if timeline.currentPhase == nil {
                        Text("Phase uncertain").font(.caption2)
                            .accessibilityIdentifier("uncertainCyclePhase")
                    }
                }
                .frame(maxWidth: size * 0.6)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let dx = location.x - center.x, dy = location.y - center.y
                let radius = sqrt(dx * dx + dy * dy)
                guard radius >= size * 0.28, radius <= size / 2 else { return }
                let angle = (atan2(dy, dx) + .pi / 2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
                let day = min(timeline.length, Int(angle / (2 * .pi) * Double(timeline.length)) + 1)
                if let segment = timeline.segments.first(where: { $0.days.contains(day) }) { select(segment.phase) }
            }
        }
        // Keep the cycle-day label discoverable; named actions and phase tiles
        // also open the details without requiring precise ring gestures.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cycle phase ring")
        .accessibilityValue("Today: day \(timeline.cycleDay). Estimated cycle: \(timeline.length) days. \(timeline.currentPhase?.title ?? "Phase uncertain"). \(timeline.currentIsRecorded ? "Recorded bleeding" : "Estimated, not confirmed")")
        .accessibilityIdentifier("phaseRingSummary")
        .accessibilityActions {
            ForEach(CyclePhase.allCases) { phase in
                Button(phase.title) { select(phase) }
            }
        }
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
                } else { Text("Estimated range unavailable").font(.subheadline) }
                Text(phase.explanation)
                    .accessibilityIdentifier("phaseExplanation")
                Text("Common experiences").font(.headline)
                Text(phase.experiences).font(.subheadline)
                    .accessibilityIdentifier("phaseExperiences")
                let patterns = CyclePhaseTimeline.patterns(for: phase, insights: insights)
                if !patterns.isEmpty {
                    Text("Your recorded patterns near period starts").font(.headline)
                    ForEach(patterns) { insight in
                        Text(insight.title).font(.subheadline.weight(.semibold))
                        Text(insight.explanation).font(.footnote)
                    }
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
