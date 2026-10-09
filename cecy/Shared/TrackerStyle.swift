import SwiftUI

/// Semantic, Dynamic Type-aware styles shared by screens and sheets.
enum TrackerTypography {
    static let pageTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let sectionTitle = Font.system(.title2, design: .rounded, weight: .semibold)
    static let metric = Font.system(.largeTitle, design: .rounded, weight: .semibold)
}

enum TrackerLayout {
    static let pageInset: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 28
    static let controlRadius: CGFloat = 18
    static let minimumTarget: CGFloat = 44
    static let readableWidth: CGFloat = 640
}

struct TrackerPalette {
    let scheme: ColorScheme
    var background: Color {
        scheme == .dark ? Color(red: 0.055, green: 0.075, blue: 0.070) : Color(red: 0.965, green: 0.965, blue: 0.945)
    }
    var surface: Color {
        scheme == .dark ? Color(red: 0.105, green: 0.135, blue: 0.125) : Color(red: 1, green: 1, blue: 0.99)
    }
    var accent: Color {
        scheme == .dark ? Color(red: 0.65, green: 0.84, blue: 0.75) : Color(red: 0.15, green: 0.35, blue: 0.29)
    }
    var sage: Color {
        scheme == .dark ? Color(red: 0.15, green: 0.235, blue: 0.20) : Color(red: 0.88, green: 0.935, blue: 0.895)
    }
    var recorded: Color {
        scheme == .dark ? Color(red: 0.96, green: 0.68, blue: 0.72) : Color(red: 0.57, green: 0.24, blue: 0.32)
    }
    var recordedSurface: Color {
        scheme == .dark ? Color(red: 0.27, green: 0.15, blue: 0.19) : Color(red: 0.98, green: 0.91, blue: 0.92)
    }
    var sexualActivity: Color {
        scheme == .dark ? Color(red: 1, green: 0.48, blue: 0.38) : Color(red: 0.70, green: 0.16, blue: 0.10)
    }
    // A dark fill keeps white primary-action labels legible in either appearance.
    var action: Color { Color(red: 0.15, green: 0.35, blue: 0.29) }
}

/// Keep forms native (including pickers, focus and row accessibility).
private struct TrackerFormStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .formStyle(.grouped)
            .fontDesign(.rounded)
            .environment(\.defaultMinListRowHeight, 48)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(TrackerPalette(scheme: colorScheme).background.ignoresSafeArea())
            .predictionUpdateProgress()
    }
}

extension View {
    func trackerFormStyle() -> some View { modifier(TrackerFormStyle()) }
}

/// Glass belongs to actions and navigation, never the record-reading layer.
struct TrackerPrimaryButtonStyle: PrimitiveButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(iOS 26.0, *), !reduceTransparency {
                Button(configuration).buttonStyle(.glassProminent)
            } else {
                Button(configuration).buttonStyle(.borderedProminent)
            }
        }
        .buttonBorderShape(.capsule)
        .font(.body.weight(.semibold))
        .tint(TrackerPalette(scheme: colorScheme).action)
    }
}

extension EnvironmentValues {
    @Entry var compactLogLabels = false
    @Entry var todayLogCards = false
}

private struct CompactLogLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: compact ? 3 : 8) {
            configuration.icon
            configuration.title
        }
    }
}

/// Logging controls have a 44-point total target, without native padding around a 44-point label.
struct TrackerCompactLogButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.compactLogLabels) private var compactLabels
    @Environment(\.todayLogCards) private var todayCards
    var prominent = false

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let palette = TrackerPalette(scheme: colorScheme)
        if todayCards {
            configuration.label
                .font(.caption.weight(.semibold))
                .labelStyle(TodayLogLabelStyle())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .frame(minWidth: 64, maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(palette.accent)
                .contentShape(Rectangle())
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
        } else {
        configuration.label
            .font(compactLabels ? .caption.weight(.semibold) : .footnote.weight(.semibold))
            .labelStyle(CompactLogLabelStyle(compact: compactLabels))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, compactLabels ? 4 : 8)
            .padding(.vertical, 6)
            .frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(prominent ? Color.white : palette.accent)
            .background(prominent ? palette.action : palette.sage, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
        }
    }
}

private struct TodayLogLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon.font(.title2)
            configuration.title
        }
    }
}

struct TrackerCompactLogActions<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var horizontalSpacing: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 6) { content }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: horizontalSpacing) { content }
                        .fixedSize(horizontal: true, vertical: false)
                    VStack(spacing: 6) { content }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct TrackerPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var subtitle: String? = nil
    var showsHeading = true
    var backgroundColor: Color? = nil
    var sectionSpacing: CGFloat = TrackerLayout.sectionSpacing
    var topInset: CGFloat = TrackerLayout.pageInset
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                if showsHeading { TrackerPageHeading(title: title, subtitle: subtitle) }
                content
            }
            .frame(maxWidth: TrackerLayout.readableWidth, alignment: .leading)
            .padding(.horizontal, TrackerLayout.pageInset)
            .padding(.top, topInset)
            .padding(.bottom, TrackerLayout.pageInset)
            .frame(maxWidth: .infinity)
        }
        .fontDesign(.rounded)
        .background((backgroundColor ?? TrackerPalette(scheme: colorScheme).background).ignoresSafeArea())
        .predictionUpdateProgress()
    }
}

struct TrackerPageHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(TrackerTypography.pageTitle).accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrackerCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    var highlighted = false
    var padding: CGFloat = 20
    var spacing: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        VStack(alignment: .leading, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(highlighted ? palette.sage : palette.surface,
                        in: RoundedRectangle(cornerRadius: TrackerLayout.cardRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: TrackerLayout.cardRadius, style: .continuous)
                    .fill(palette.accent.opacity(0.04))
                    .offset(y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: TrackerLayout.cardRadius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [palette.accent.opacity(contrast == .increased ? 1 : 0.20),
                                                          palette.accent.opacity(contrast == .increased ? 1 : 0.05)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: contrast == .increased ? 1.5 : 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.035), radius: 12, x: 0, y: 5)
    }
}

struct TrackerNavigationLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var iconSize = 18.0
    let title: String
    let symbol: String
    var detail: String? = nil
    var showsChevron = true

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: min(iconSize, 28), weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 40, height: 40)
                .background(palette.sage, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium)).foregroundStyle(.primary)
                if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
            }
            .fixedSize(horizontal: false, vertical: true)
            if showsChevron {
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: TrackerLayout.minimumTarget, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct InlineError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .foregroundStyle(.primary)
            .font(.callout)
            .accessibilityIdentifier("validationError")
    }
}

/// Format UTC anchors in UTC, never as local instants that can change their civil day.
enum DayText {
    private static var cachedLocaleIdentifier: String?
    private static var formatters: [String: DateFormatter] = [:]
    static func full(_ day: LocalDay) -> String { format(day, template: "yMMMMd") }
    static func short(_ day: LocalDay) -> String { format(day, template: "yMMMd") }
    static func month(_ day: LocalDay) -> String { format(day, template: "yMMMM") }
    static func range(_ first: LocalDay, _ last: LocalDay) -> String { "\(short(first)) – \(short(last))" }

    private static func format(_ day: LocalDay, template: String) -> String {
        let locale = Locale.autoupdatingCurrent
        if cachedLocaleIdentifier != locale.identifier {
            formatters.removeAll()
            cachedLocaleIdentifier = locale.identifier
        }
        if let formatter = formatters[template] {
            return formatter.string(from: day.formattingDate)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = LocalDay.calendar
        formatter.timeZone = LocalDay.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[template] = formatter
        return formatter.string(from: day.formattingDate)
    }
}

struct PrivacyDetails: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stored on this device", systemImage: "hand.raised")
                .font(.headline)
            Text("Records stay stored on-device. Apple Health import is optional and read-only. Optional insights send selected information for external processing only with your consent and request. No health-data cloud sync or analytics.")
            Text("Records and preferences are excluded from future system backups. Earlier backups and shared exports are not erased by local deletion. Apple sign-in cannot restore your records on another device yet. App locking, export and discreet reminders are in Settings.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
