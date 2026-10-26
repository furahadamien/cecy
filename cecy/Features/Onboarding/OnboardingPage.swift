import SwiftUI

struct OnboardingPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize = 88.0
    @AccessibilityFocusState private var headingFocused: Bool
    let title: String
    let subtitle: String?
    let accent: OnboardingAccent
    let symbol: String
    let step: Int
    let totalSteps: Int
    let optional: Bool
    /// The welcome page shows the app icon over a fuller color wash.
    var hero = false
    @ViewBuilder var content: Content

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme, contrast: contrast)
        let theme = OnboardingTheme(accent: accent, symbol: symbol, palette: palette)
        let iconSize = min(heroIconSize, 128)
        Form {
            Section {
                VStack(alignment: hero ? .center : .leading, spacing: 14) {
                    if hero {
                        Image("LaunchIcon")
                            .resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous))
                            .shadow(color: palette.accent.opacity(0.25), radius: 18, y: 8)
                            .accessibilityHidden(true)
                            .onboardingStagger(0)
                    } else {
                        OnboardingSymbolBadge(theme: theme)
                    }
                    Text(title).font(TrackerTypography.pageTitle)
                        .multilineTextAlignment(hero ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingFocused)
                        .accessibilityIdentifier("onboardingHeading")
                    if let subtitle {
                        Text(subtitle).font(.body).foregroundStyle(.secondary)
                            .multilineTextAlignment(hero ? .center : .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: hero ? .center : .leading)
                .padding(.vertical, hero ? 20 : 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            content
        }
        .formStyle(.grouped)
        .fontDesign(.rounded)
        .environment(\.defaultMinListRowHeight, 48)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { OnboardingBackdrop(theme: theme, hero: hero) }
        .predictionUpdateProgress()
        .environment(\.onboardingTheme, theme)
        .tint(theme.tint)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingProgressBar(step: step, totalSteps: totalSteps, optional: optional)
                .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .navigationTitle("Cecy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { headingFocused = true }
    }
}
