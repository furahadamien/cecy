import SwiftUI

struct OnboardingPage<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @AccessibilityFocusState private var headingFocused: Bool
    let title: String
    let subtitle: String
    let symbol: String
    let step: Int
    let optional: Bool
    @ViewBuilder var content: Content

    var body: some View {
        let palette = TrackerPalette(scheme: colorScheme)
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 64, height: 64)
                        .background(palette.sage, in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityHidden(true)
                    Text(title).font(.largeTitle.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($headingFocused)
                        .accessibilityIdentifier("onboardingHeading")
                    Text(subtitle).font(.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            content
        }
        .formStyle(.grouped)
        .environment(\.defaultMinListRowHeight, 48)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(palette.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Step \(step) of 12").fontWeight(.medium)
                    Spacer()
                    if optional { Text("Optional") }
                }.font(.caption).foregroundStyle(.secondary)
                ProgressView(value: Double(step), total: 12)
                    .accessibilityLabel("Onboarding progress")
                    .accessibilityValue("Step \(step) of 12")
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(palette.background)
        }
        .navigationTitle("Cecy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { headingFocused = true }
    }
}