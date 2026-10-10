import SwiftUI

struct InsightSectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let symbol: String
    var subtitle: String? = nil

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(palette.accent)
                .frame(width: 46, height: 46)
                .background(palette.sage.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(TrackerTypography.sectionTitle).accessibilityAddTraits(.isHeader)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Fractions are a presentation of explicit daily answers, not prediction confidence.
enum RecordingCoverageDisplay {
    static func fraction(_ count: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(count) / Double(total)))
    }
    static func percent(_ count: Int, total: Int) -> String {
        fraction(count, total: total).formatted(.percent.precision(.fractionLength(0)))
    }
}

struct RecordingCoverageOverview: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let coverage: RecordingCoverage

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))
        layout {
            ZStack {
                Circle().stroke(palette.accent.opacity(0.12), lineWidth: 9)
                Circle().trim(from: 0, to: RecordingCoverageDisplay.fraction(coverage.loggedDays, total: coverage.totalDays))
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(coverage.loggedDays.formatted()).font(.title2.bold()).monospacedDigit()
                    Text("of \(coverage.totalDays)").font(.caption).foregroundStyle(.secondary)
                }
            }.frame(width: 88, height: 88).padding(5).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(RecordingCoverageDisplay.percent(coverage.loggedDays, total: coverage.totalDays)) of days logged")
                    .font(.headline)
                Text("Days logged: \(coverage.loggedDays) of \(coverage.totalDays)")
                    .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("recordingCoverage")
                Text("Your daily bleeding answers over time.").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(palette.sage.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct RecordingCoverageRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let symbol: String
    let count: Int
    let total: Int
    let tint: Color

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint)
                    .frame(width: 30, height: 30).background(tint.opacity(0.09), in: Circle()).accessibilityHidden(true)
                Text(title).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Text(count.formatted()).font(.subheadline.monospacedDigit())
            }.frame(maxWidth: .infinity)
            HStack(spacing: 8) {
                ProgressView(value: RecordingCoverageDisplay.fraction(count, total: total)).tint(tint)
                    .accessibilityHidden(true)
                Text(RecordingCoverageDisplay.percent(count, total: total))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 34, alignment: .trailing)
            }.frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(count) of \(total) days, \(RecordingCoverageDisplay.percent(count, total: total))")
        .accessibilityIdentifier("recordingState_\(title)")
    }
}