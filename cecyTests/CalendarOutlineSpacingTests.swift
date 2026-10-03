import SwiftUI
import Testing
@testable import cecy

@MainActor struct CalendarOutlineSpacingTests {
    @Test func monthAndListOutlinesHaveClearGapsAtMinimumTapSize() {
        for size in [CGFloat(44), 48, 80] {
            for spacing in [CGFloat(0), 2, 6, 8] {
                let shape = RoundedRectangle(cornerRadius: 12).inset(by: CalendarOutlineMetrics.outerInset)
                let first = shape.path(in: CGRect(x: 0, y: 0, width: size, height: size)).boundingRect
                let right = shape.path(in: CGRect(x: size + spacing, y: 0, width: size, height: size)).boundingRect
                let below = shape.path(in: CGRect(x: 0, y: size + spacing, width: size, height: size)).boundingRect
                #expect(right.minX - first.maxX >= 6)
                #expect(below.minY - first.maxY >= 6)
                #expect(first.width >= 38)
            }
        }
    }

    @Test func simultaneousPeriodAndOvulationOutlinesRemainSeparated() {
        // Both strokes are two points wide; a four-point inset difference leaves air.
        #expect(CalendarOutlineMetrics.nestedInset - CalendarOutlineMetrics.outerInset >= 4)
        let outer = RoundedRectangle(cornerRadius: 12).inset(by: CalendarOutlineMetrics.outerInset)
            .path(in: CGRect(x: 0, y: 0, width: 44, height: 44)).boundingRect
        let inner = RoundedRectangle(cornerRadius: 12).inset(by: CalendarOutlineMetrics.nestedInset)
            .path(in: CGRect(x: 0, y: 0, width: 44, height: 44)).boundingRect
        #expect(outer.contains(inner))
        #expect(inner.width >= 30)
    }
}
