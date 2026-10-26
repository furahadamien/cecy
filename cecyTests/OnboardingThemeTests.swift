import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor
struct OnboardingThemeTests {
    static let variants: [(ColorScheme, Bool)] = [(.light, false), (.light, true), (.dark, false), (.dark, true)]

    @Test(arguments: [0, 1, 2, 3])
    func onboardingAccentsRemainReadable(variant: Int) {
        let (scheme, highContrast) = Self.variants[variant]
        let palette = TrackerPalette(scheme: scheme, highContrast: highContrast)
        for accent in OnboardingAccent.allCases {
            let tint = accent.tint(palette)
            // WCAG AA text on the warm-neutral base, cards and the accent's own surface.
            for background in [palette.background, palette.surface, accent.surface(palette)] {
                #expect(contrast(tint, background) >= 4.5, "\(accent) \(scheme) hc=\(highContrast)")
            }
            // Primary text stays readable on every tinted surface.
            let text: Color = scheme == .dark ? .white : .black
            #expect(contrast(text, accent.surface(palette)) >= 7)
        }
        // The date tile's weekday strip uses the rose surface on rose.
        #expect(contrast(palette.recordedSurface, palette.recorded) >= 4.5)
    }

    @Test func highContrastAccentsAreAtLeastAsStrong() {
        for scheme in [ColorScheme.light, .dark] {
            let standard = TrackerPalette(scheme: scheme)
            let increased = TrackerPalette(scheme: scheme, highContrast: true)
            for (base, strong) in [(standard.apricot, increased.apricot), (standard.lavender, increased.lavender),
                                   (standard.sun, increased.sun)] {
                #expect(contrast(strong, standard.background) >= contrast(base, standard.background))
            }
        }
    }

    @Test func everyStepHasAThemeAndTheBaseStaysSage() {
        let palette = TrackerPalette(scheme: .light)
        for step in OnboardingFlowView.Step.allCases {
            let theme = step.theme(palette)
            #expect(theme.symbol == step.symbol)
            #expect(UIImage(systemName: theme.symbol) != nil, "Missing SF Symbol \(theme.symbol)")
        }
        // Start and finish stay on brand; pink is never the default.
        #expect(OnboardingFlowView.Step.welcome.accent == .sage)
        #expect(OnboardingFlowView.Step.review.accent == .sage)
        #expect(OnboardingFlowView.Step.apple.accent == .sage)
        let accents = OnboardingFlowView.Step.allCases.map(\.accent)
        #expect(accents.filter { $0 == .sage }.count >= accents.filter { $0 == .rose }.count)
        #expect(Set(accents).count >= 4)
    }

    @Test func onboardingThemeDoesNotLeakIntoOtherScreens() {
        #expect(EnvironmentValues().onboardingTheme == nil)
    }

    private func contrast(_ first: Color, _ second: Color) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(_ color: Color) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        _ = UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
