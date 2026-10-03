import XCTest

/// Scroll along the content margin, away from form toggles and navigation rows.
@MainActor enum UIViewport {
    static func reveal(_ element: XCUIElement, in app: XCUIApplication, searchEarlierFirst: Bool = false,
                       file: StaticString = #filePath, line: UInt = #line) {
        func bounds() -> (top: CGFloat, bottom: CGFloat) {
            let top = app.navigationBars.allElementsBoundByIndex.filter(\.isHittable)
                .map { $0.frame.maxY }.max() ?? (app.frame.minY + 60)
            let keyboard = app.keyboards.firstMatch
            let tabs = app.tabBars.firstMatch
            // Leave the keyboard's accessory bar out of the scroll gesture area.
            let bottom = keyboard.exists ? keyboard.frame.minY - 48
                : tabs.isHittable ? tabs.frame.minY : app.frame.maxY - 24
            return (top + 8, bottom - 8)
        }
        func scroll(by delta: CGFloat, viewport: (top: CGFloat, bottom: CGFloat)) {
            let y = delta > 0 ? viewport.top + 20 : viewport.bottom - 20
            let start = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 12, dy: y))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: delta)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        for attempt in 0..<32 {
            let viewport = bounds()
            let frame = element.exists ? element.frame : .zero
            if frame.height > 0 && element.isHittable,
               frame.minY >= viewport.top && frame.maxY <= viewport.bottom { return }
            let step = max(40, (viewport.bottom - viewport.top) * 0.55)
            let delta: CGFloat
            if frame.height > 0 {
                // Nudge partially visible controls rather than overshooting them repeatedly.
                // Very short drags never cross UIKit's pan-recognition threshold.
                delta = frame.minY < viewport.top
                    ? min(step, max(40, viewport.top + 4 - frame.minY))
                    : -min(step, max(40, frame.maxY - viewport.bottom + 4))
            } else {
                // Lazy rows require a bounded search in both directions; callers can
                // explicitly prefer earlier rows when returning to a previous setting.
                let earlier = attempt < 16 ? searchEarlierFirst : !searchEarlierFirst
                delta = earlier ? step : -step
            }
            scroll(by: delta, viewport: viewport)
        }
        XCTFail("Could not reveal \(element)\n\(app.debugDescription)", file: file, line: line)
    }
}
