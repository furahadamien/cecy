import SwiftUI

/// A colored card with an icon badge, used on the welcome and preview steps.
struct OnboardingFeatureCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let accent: OnboardingAccent
    let symbol: String
    let title: String
    var detail: String? = nil

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme, contrast: contrast)
        let tint = accent.tint(palette)
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(palette.surface.opacity(colorScheme == .dark ? 0.35 : 0.85), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                if let detail {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.surface(palette), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(contrast == .increased ? 0.9 : 0.18), lineWidth: contrast == .increased ? 1.5 : 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Fades and lifts children in one after another; instant with Reduce Motion.
struct OnboardingStagger: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible || reduceMotion ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 12)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.smooth(duration: 0.45).delay(0.08 * Double(index) + 0.1)) { visible = true }
            }
    }
}

extension View {
    func onboardingStagger(_ index: Int) -> some View { modifier(OnboardingStagger(index: index)) }
}
