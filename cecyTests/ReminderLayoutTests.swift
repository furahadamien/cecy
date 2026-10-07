import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct ReminderLayoutTests {
    @Test(arguments: [280.0, 600.0], [ColorScheme.light, .dark])
    func reminderChoicesAndPreviewsWrap(width: Double, scheme: ColorScheme) {
        func height(_ size: DynamicTypeSize) -> CGFloat {
            let content = VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: .constant(true)) { ReminderChoiceLabel(kind: .daily) }
                Toggle(isOn: .constant(true)) { ReminderChoiceLabel(kind: .window) }
                ReminderMessageFields(daily: true, window: true, showDetails: .constant(true))
            }
            .environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, scheme)
            let host = UIHostingController(rootView: content)
            let measured = host.sizeThatFits(in: CGSize(width: width, height: 20_000))
            #expect(measured.width.isFinite && measured.height.isFinite)
            #expect(measured.width <= width + 1)
            #expect(measured.height > 0 && measured.height < 20_000)
            return measured.height
        }
        #expect(height(.accessibility5) > height(.large))
    }
}