import SwiftUI

private struct PredictionUpdateProgressKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var predictionUpdateInProgress: Bool {
        get { self[PredictionUpdateProgressKey.self] }
        set { self[PredictionUpdateProgressKey.self] = newValue }
    }
}

private struct PredictionUpdateProgress: ViewModifier {
    @Environment(\.predictionUpdateInProgress) private var updating
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .disabled(updating)
            .interactiveDismissDisabled(updating)
            .overlay {
                if updating {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        ProgressView("updating your predictions")
                            .progressViewStyle(.circular)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(24)
                            .background(TrackerPalette(scheme: colorScheme).surface,
                                        in: RoundedRectangle(cornerRadius: 20))
                            .padding(20)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("updating your predictions")
                            .accessibilityIdentifier("updatingPredictions")
                    }
                }
            }
    }
}

extension View {
    func predictionUpdateProgress() -> some View { modifier(PredictionUpdateProgress()) }
}
