import SwiftUI

/// The chosen last-period date as a small calendar tile in the step's color.
struct OnboardingDateCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let day: LocalDay

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme, contrast: contrast)
        HStack(spacing: 16) {
            VStack(spacing: 0) {
                Text(DayText.weekday(day).prefix(3).uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.recordedSurface)
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                    .background(palette.recorded)
                Text("\(day.day)")
                    .font(.system(.title, design: .rounded, weight: .bold)).monospacedDigit()
                    .foregroundStyle(palette.recorded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 64, height: 68)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.recorded.opacity(0.3)) }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Label("Last period started", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.weight(.medium)).foregroundStyle(palette.recorded)
                Text(DayText.full(day)).font(TrackerTypography.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("onboardingLastStart")
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

/// A non-interactive, simplified Today card built from the draft, so the preview shows rather than tells.
struct OnboardingTodayPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let overview: CycleOverview
    let typicalCycleDays: Int?
    let today: LocalDay

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme, contrast: contrast)
        let cycleDays = max(typicalCycleDays ?? CycleSetupPolicy.defaultCycleDays, 1)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Today", systemImage: "sun.max.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(palette.sun)
                Spacer()
                Text(DayText.monthDay(today)).font(.subheadline).foregroundStyle(.secondary)
            }
            if let day = overview.currentDay {
                Text("Day \(day)").font(TrackerTypography.metric).monospacedDigit()
                GeometryReader { geometry in
                    let fraction = min(Double(day) / Double(cycleDays), 1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(LinearGradient(colors: [palette.recorded, palette.apricot, palette.sun, palette.lavender],
                                                      startPoint: .leading, endPoint: .trailing).opacity(0.3))
                        Capsule().fill(LinearGradient(colors: [palette.recorded, palette.apricot, palette.sun, palette.lavender],
                                                      startPoint: .leading, endPoint: .trailing))
                            .mask(alignment: .leading) {
                                Capsule().frame(width: max(10, geometry.size.width * fraction))
                            }
                    }
                }
                .frame(height: 10)
            } else {
                Text("Ready when you are").font(TrackerTypography.sectionTitle)
            }
            Divider()
            HStack(alignment: .firstTextBaseline) {
                Label("Next period", systemImage: "drop.fill").foregroundStyle(palette.recorded)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                if let estimate = overview.estimate {
                    Text(DayText.range(estimate.earliest, estimate.latest)).font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("After your first log").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: TrackerLayout.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TrackerLayout.cardRadius, style: .continuous)
                .strokeBorder(palette.sun.opacity(contrast == .increased ? 1 : 0.3), lineWidth: contrast == .increased ? 1.5 : 1)
        }
        .shadow(color: palette.sun.opacity(colorScheme == .dark ? 0 : 0.12), radius: 16, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview of your Today view")
    }
}

/// One colored stat on the review summary. Tapping returns to the step that set it.
struct OnboardingReviewTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let accent: OnboardingAccent
    let symbol: String
    let title: String
    let value: String
    var badge: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { tile(editable: true) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title), \(value)")
                .accessibilityHint("Double-tap to change.")
        } else {
            tile(editable: false)
                .accessibilityElement(children: .combine)
        }
    }

    private func tile(editable: Bool) -> some View {
        let palette = TrackerPalette(scheme: colorScheme, contrast: contrast)
        let tint = accent.tint(palette)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: symbol).font(.headline).foregroundStyle(tint).accessibilityHidden(true)
                Spacer(minLength: 4)
                if editable {
                    Image(systemName: "pencil").font(.caption.weight(.semibold)).foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
            }
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(tint)
            Text(value).font(.headline).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let badge {
                Text(badge).font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(tint)
                    .background(palette.surface.opacity(0.8), in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(accent.surface(palette), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(tint.opacity(contrast == .increased ? 0.9 : 0.2), lineWidth: contrast == .increased ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// A row with a tinted leading icon; the text can carry its own identifier.
struct OnboardingIconRow<Text_: View>: View {
    let symbol: String
    let tint: Color
    @ViewBuilder var text: Text_

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 24).accessibilityHidden(true)
            text.fixedSize(horizontal: false, vertical: true)
        }
    }
}
