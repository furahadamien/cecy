import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct RecordCardLayoutTests {
    @Test(arguments: [320.0, 600.0], [ColorScheme.light, .dark])
    func recordsFitNarrowAndWideLayoutsWithoutClipping(width: Double, scheme: ColorScheme) throws {
        let session = TrackerSession.preview(withHistory: true)
        let day = try LocalDay(key: 20260929)
        let period = Period(start: try day.adding(days: -4), end: day)
        let symptom = SymptomEntry(day: day, kind: .headache, value: 2, notes: "Synthetic private note")
        let activity = SexualActivityEntry(day: day, activities: [.other], notes: "Synthetic private note")
        func measuredHeight(_ size: DynamicTypeSize) -> CGFloat {
            let content = VStack(spacing: 16) {
                PeriodRecordSummary(session: session, period: period)
                SymptomRecordView(session: session, entry: symptom)
                SexualActivityRecordView(session: session, entry: activity)
            }
            .environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, scheme)
            let host = UIHostingController(rootView: content)
            host.traitOverrides.accessibilityContrast = .high
            let measured = host.sizeThatFits(in: CGSize(width: width, height: 10_000))
            #expect(measured.width.isFinite && measured.height.isFinite)
            #expect(measured.width <= width + 1)
            #expect(measured.height > 0 && measured.height < 10_000)
            return measured.height
        }
        #expect(measuredHeight(.accessibility5) > measuredHeight(.large))
    }
}
