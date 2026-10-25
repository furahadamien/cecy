import SwiftUI

/// The dynamic cards between Today's insights and the upcoming forecast. Shows at most two,
/// built from the user's own records, and only while today is selected.
struct TodayHighlightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let session: TrackerSession

    var body: some View {
        ForEach(session.todayHighlights) { highlight in
            TrackerCard(spacing: 10) { content(highlight) }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("todayHighlight.\(highlight.id)")
        }
    }

    private var palette: TrackerPalette { TrackerPalette(scheme: colorScheme) }

    @ViewBuilder private func content(_ highlight: TodayHighlight) -> some View {
        switch highlight {
        case .estimateMoved(let days, let earlier, let reason, let center):
            heading("Your estimate moved", symbol: "arrow.left.arrow.right")
            Text("Now around \(DayText.monthDay(center)).").font(.subheadline.weight(.semibold))
            Text(earlier ? (days == 1 ? "That's 1 day earlier. \(reasonText(reason))" : "That's \(days) days earlier. \(reasonText(reason))")
                         : (days == 1 ? "That's 1 day later. \(reasonText(reason))" : "That's \(days) days later. \(reasonText(reason))"))
                .font(.footnote).foregroundStyle(.secondary)

        case .windowApproaching(let days, let earliest, let latest):
            heading("Your period may start soon", symbol: "calendar.badge.clock")
            Text(days == 1 ? "It could start tomorrow." : "It could start in \(days) days.")
                .font(.subheadline.weight(.semibold))
            Text("Expected \(DayText.range(earliest, latest)).")
                .font(.footnote).foregroundStyle(.secondary)

        case .cycleRecap(let length, let periodDays, let symptoms, let factors):
            heading("Your last cycle", symbol: "arrow.triangle.2.circlepath")
            HStack(spacing: 10) {
                stat("\(length)", label: "days long")
                if let periodDays { stat("\(periodDays)", label: periodDays == 1 ? "period day" : "period days") }
            }
            if !symptoms.isEmpty {
                Text("You logged \(symptoms.map { $0.title.lowercased() }.formatted(.list(type: .and))) the most.")
                    .font(.footnote)
            }
            if !factors.isEmpty {
                Text("You noted \(factors.map { $0.title.lowercased() }.formatted(.list(type: .and))).")
                    .font(.footnote).foregroundStyle(.secondary)
            }

        case .lastCycleEcho(let cycleDay, let symptoms):
            heading("This time last cycle", symbol: "clock.arrow.circlepath")
            Text("Around day \(cycleDay) you logged \(symptoms.map { $0.title.lowercased() }.formatted(.list(type: .and))).")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

        case .activeContext(let cycleDay, let factors, let stages):
            localizedHeading(cycleDay.map { String(localized: "Cycle day \($0)") } ?? String(localized: "Right now"), symbol: "sun.max")
            SelectionFlowLayout {
                ForEach(stages, id: \.self) { tag($0.title, symbol: $0.symbol) }
                ForEach(factors, id: \.self) { tag($0.title, symbol: "timeline.selection") }
            }
            Text("You can change these in Settings.")
                .font(.footnote).foregroundStyle(.secondary)

        case .coverage(let logged, let days):
            heading("This week", symbol: "checklist")
            HStack(spacing: 4) {
                ForEach(0..<days, id: \.self) { index in
                    Capsule().fill(index < logged ? palette.accent : palette.accent.opacity(0.15))
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
            Text(logged == days ? "You logged every day this week."
                 : "You logged \(logged) of the last \(days) days.")
                .font(.subheadline.weight(.semibold))
            Text("The more you log the better your estimates get.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func heading(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(palette.accent) }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    /// Already-localized text (for example with a number filled in).
    private func localizedHeading(_ title: String, symbol: String) -> some View {
        Label { Text(verbatim: title) } icon: { Image(systemName: symbol).foregroundStyle(palette.accent) }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private func stat(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.recordedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tag(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(palette.sage, in: Capsule())
    }

    private func reasonText(_ reason: EstimateShift.Reason) -> String {
        switch reason {
        case .period: String(localized: "You updated a period.")
        case .factor: String(localized: "You changed a cycle factor or life stage.")
        case .records: String(localized: "It follows your latest logs.")
        }
    }
}
