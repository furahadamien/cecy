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
            Text(earlier ? (days == 1 ? "1 day earlier, now around \(DayText.short(center))." : "\(days) days earlier, now around \(DayText.short(center)).")
                         : (days == 1 ? "1 day later, now around \(DayText.short(center))." : "\(days) days later, now around \(DayText.short(center))."))
                .font(.subheadline.weight(.semibold))
            Text(reasonText(reason)).font(.footnote).foregroundStyle(.secondary)

        case .windowApproaching(let days, let earliest, let latest):
            heading("Your estimated window is close", symbol: "calendar.badge.clock")
            Text(days == 1 ? "It starts tomorrow." : "It starts in \(days) days.")
                .font(.subheadline.weight(.semibold))
            Text("Possible start: \(DayText.range(earliest, latest)). An estimate, not a deadline.")
                .font(.footnote).foregroundStyle(.secondary)

        case .cycleRecap(let length, let periodDays, let symptoms, let factors):
            heading("Your last cycle", symbol: "arrow.triangle.2.circlepath")
            HStack(spacing: 10) {
                stat("\(length)", label: "days long")
                if let periodDays { stat("\(periodDays)", label: periodDays == 1 ? "period day" : "period days") }
            }
            if !symptoms.isEmpty {
                Text("Most logged: \(symptoms.map(\.title).formatted(.list(type: .and)))")
                    .font(.footnote)
            }
            if !factors.isEmpty {
                Text("Noted: \(factors.map(\.title).formatted(.list(type: .and)))")
                    .font(.footnote).foregroundStyle(.secondary)
            }

        case .lastCycleEcho(let cycleDay, let symptoms):
            heading("This time last cycle", symbol: "clock.arrow.circlepath")
            Text("Around day \(cycleDay) last cycle, you logged \(symptoms.map { $0.title.lowercased() }.formatted(.list(type: .and))).")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Patterns can repeat or change. This only reflects what you logged.")
                .font(.footnote).foregroundStyle(.secondary)

        case .activeContext(let cycleDay, let factors, let stages):
            localizedHeading(cycleDay.map { String(localized: "Cycle day \($0)") } ?? String(localized: "Right now"), symbol: "sun.max")
            SelectionFlowLayout {
                ForEach(stages, id: \.self) { tag($0.title, symbol: $0.symbol) }
                ForEach(factors, id: \.self) { tag($0.title, symbol: "timeline.selection") }
            }
            Text("Noted in your records. You can update them in Settings.")
                .font(.footnote).foregroundStyle(.secondary)

        case .coverage(let logged, let days):
            heading("Your logging this week", symbol: "checklist")
            HStack(spacing: 4) {
                ForEach(0..<days, id: \.self) { index in
                    Capsule().fill(index < logged ? palette.accent : palette.accent.opacity(0.15))
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
            Text(logged == days ? "You logged every day this week."
                 : logged == 1 ? "1 of the last \(days) days logged." : "\(logged) of the last \(days) days logged.")
                .font(.subheadline.weight(.semibold))
            Text("More logged days make your estimates and patterns more reliable. Days you skip stay unknown.")
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

    private func reasonText(_ reason: EstimateShift.Reason) -> LocalizedStringKey {
        switch reason {
        case .period: "This happened after you updated a period record."
        case .factor: "This happened after you changed a cycle factor or life stage."
        case .records: "This happened after your latest records."
        }
    }
}
