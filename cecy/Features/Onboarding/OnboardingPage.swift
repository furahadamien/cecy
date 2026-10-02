import SwiftUI

struct OnboardingPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .title) private var symbolSize = 28.0
    @AccessibilityFocusState private var headingFocused: Bool
    let title: String
    let subtitle: String?
    let symbol: String
    let step: Int
    let totalSteps: Int
    let optional: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: symbolSize, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .padding(18)
                        .background(palette.sage, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityHidden(true)
                    Text(title).font(TrackerTypography.pageTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingFocused)
                        .accessibilityIdentifier("onboardingHeading")
                    if let subtitle {
                        Text(subtitle).font(.body).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            content
        }
        .trackerFormStyle()
        .safeAreaInset(edge: .top, spacing: 0) {
            ProgressView(value: Double(step), total: Double(totalSteps))
                .accessibilityLabel("Onboarding progress")
                .accessibilityValue("Step \(step) of \(totalSteps)")
                .accessibilityHint(optional ? "Optional step" : "")
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(palette.background)
        }
        .navigationTitle("Cecy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { headingFocused = true }
    }
}
