import SwiftUI

struct TrackerSettingsView: View {
    var body: some View {
        TrackerPage(title: "Settings", subtitle: "Your information. Your choices.") {
            TrackerCard(highlighted: true) { PrivacyDetails() }
            TrackerCard {
                Text("About predictions").font(.headline).accessibilityAddTraits(.isHeader)
                Text("Four recorded starts provide the three completed intervals needed for a first estimate. Up to six recent intervals are used.")
                Text("The center uses the median. The window extends two days around the shortest and longest intervals, beginning at least one day after the latest start.")
                Text("A spread above 14 days means this simple model cannot provide a window. Six intervals with a spread of seven days or less receive Moderate confidence; other eligible estimates receive Low confidence.")
                Text("These labels are provisional—not measured probabilities. The window represents possible start dates, not bleeding duration.")
                Text("Not medical advice. Do not use estimates for contraception, diagnosis, or fertility planning.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            TrackerCard {
                Text("Internal prototype").font(.headline)
                Text("Review dates before saving. Editing or deleting saved records, export, and additional privacy controls are not available in this phase. This build is not ready for public use.")
                Text("Cecy \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}