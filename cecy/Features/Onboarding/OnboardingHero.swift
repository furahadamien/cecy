import SwiftUI

/// A soft glow in the step's color over the warm-neutral base, so each page reads as one canvas.
struct OnboardingBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let theme: OnboardingTheme
    /// The welcome page uses a fuller, multi-color wash.
    var hero = false

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        // Increase Contrast keeps the base nearly flat so text never sits on color.
        let strength = contrast == .increased ? 0.06 : (colorScheme == .dark ? 0.22 : 0.18)
        ZStack {
            palette.background
            if hero {
                heroWash(palette, strength: strength)
            } else {
                RadialGradient(colors: [theme.tint.opacity(strength), theme.tint.opacity(0)],
                               center: .topLeading, startRadius: 0, endRadius: 420)
                RadialGradient(colors: [theme.surface.opacity(colorScheme == .dark ? 0.5 : 0.9), theme.surface.opacity(0)],
                               center: .topTrailing, startRadius: 0, endRadius: 320)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder private func heroWash(_ palette: TrackerPalette, strength: Double) -> some View {
        let sage = palette.accent.opacity(strength)
        let apricot = palette.apricot.opacity(strength)
        let rose = palette.recorded.opacity(strength * 0.8)
        let lavender = palette.lavender.opacity(strength * 0.7)
        let clear = palette.background.opacity(0)
        if #available(iOS 18.0, *) {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.45], [0.55, 0.4], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                sage, apricot, rose,
                lavender, clear, apricot,
                clear, clear, clear,
            ])
        } else {
            ZStack {
                RadialGradient(colors: [sage, clear], center: .topLeading, startRadius: 0, endRadius: 380)
                RadialGradient(colors: [rose, clear], center: .topTrailing, startRadius: 0, endRadius: 360)
                RadialGradient(colors: [apricot, clear], center: .trailing, startRadius: 0, endRadius: 300)
            }
        }
    }
}

/// The step's symbol in a round tinted badge. It bounces once on appear unless Reduce Motion is on.
struct OnboardingSymbolBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var symbolSize = 34.0
    let theme: OnboardingTheme
    var pulses = false
    @State private var appeared = false

    var body: some View {
        let size = min(symbolSize, 52)
        Image(systemName: theme.symbol)
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(theme.tint)
            .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion || pulses ? false : appeared)
            .symbolEffect(.pulse, options: .repeating, isActive: pulses && !reduceMotion)
            .frame(width: size * 1.9, height: size * 1.9)
            .background {
                Circle().fill(theme.surface)
                Circle().strokeBorder(theme.tint.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: theme.tint.opacity(0.18), radius: 14, y: 6)
            .accessibilityHidden(true)
            .onAppear { appeared = true }
    }
}
