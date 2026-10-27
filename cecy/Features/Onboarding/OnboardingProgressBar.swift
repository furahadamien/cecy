import SwiftUI

/// A capsule that fills with the colors of the steps already visited.
/// VoiceOver and UI tests still see a native progress indicator.
struct OnboardingProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let step: Int
    let totalSteps: Int
    var optional = false

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme, contrast: contrast)
        let steps = OnboardingFlowView.Step.allCases
        let visited = steps.prefix(max(1, min(step, steps.count))).map { $0.accent.tint(palette) }
        let colors = visited.count > 1 ? visited : visited + visited
        let fraction = Double(step) / Double(max(totalSteps, 1))
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.accent.opacity(contrast == .increased ? 0.30 : 0.12))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geometry.size.height, geometry.size.width * fraction))
            }
        }
        .frame(height: 8)
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: step)
        .accessibilityRepresentation {
            ProgressView(value: Double(step), total: Double(totalSteps))
        }
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(step) of \(totalSteps)")
        .accessibilityHint(optional ? "Optional step" : "")
    }
}
