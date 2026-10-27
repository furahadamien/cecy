import SwiftUI

/// The accent family each onboarding step borrows from the cycle phases.
enum OnboardingAccent: CaseIterable {
    case sage, apricot, rose, lavender, sun

    func tint(_ palette: TrackerPalette) -> Color {
        switch self {
        case .sage: palette.accent
        case .apricot: palette.apricot
        case .rose: palette.recorded
        case .lavender: palette.lavender
        case .sun: palette.sun
        }
    }

    func surface(_ palette: TrackerPalette) -> Color {
        switch self {
        case .sage: palette.sage
        case .apricot: palette.apricotSurface
        case .rose: palette.recordedSurface
        case .lavender: palette.lavenderSurface
        case .sun: palette.sunSurface
        }
    }
}

/// Colors for one onboarding step. Accents sit on the warm-neutral base; they never replace it.
struct OnboardingTheme {
    let accent: OnboardingAccent
    let tint: Color
    let surface: Color
    let symbol: String

    init(accent: OnboardingAccent, symbol: String, palette: TrackerPalette) {
        self.accent = accent
        self.symbol = symbol
        tint = accent.tint(palette)
        surface = accent.surface(palette)
    }
}

extension OnboardingFlowView.Step {
    var accent: OnboardingAccent {
        switch self {
        case .welcome, .review, .apple: .sage
        case .about: .apricot
        case .history, .cycle: .rose
        case .cycleLength: .lavender
        case .preview: .sun
        }
    }

    func theme(_ palette: TrackerPalette) -> OnboardingTheme {
        OnboardingTheme(accent: accent, symbol: symbol, palette: palette)
    }
}

extension EnvironmentValues {
    /// When set, shared controls (chips, wheels) adopt the onboarding step's colors.
    /// Elsewhere it stays nil, so those controls keep the app's default accent.
    @Entry var onboardingTheme: OnboardingTheme? = nil
}

extension TrackerPalette {
    init(scheme: ColorScheme, contrast: ColorSchemeContrast) {
        self.init(scheme: scheme, highContrast: contrast == .increased)
    }
}
