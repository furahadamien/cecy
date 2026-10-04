import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor
struct VisualStyleTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func semanticColorsRemainReadable(scheme: ColorScheme) {
        let palette = TrackerPalette(scheme: scheme)
        // WCAG AA for normal-sized text on the solid content layer.
        // Native glass adapts its own material; it needs device-level visual review.
        for background in [palette.background, palette.surface, palette.sage] {
            #expect(contrast(palette.accent, background) >= 4.5)
            #expect(contrast(palette.sexualActivity, background) >= 4.5)
        }
        #expect(contrast(palette.sexualActivity, palette.recordedSurface) >= 4.5)
        #expect(contrast(palette.recorded, palette.recordedSurface) >= 4.5)
        #expect(contrast(palette.recorded, palette.surface) >= 4.5)
        #expect(contrast(.white, palette.action) >= 4.5)
    }

    @Test func layoutPreservesReadableWidthsAndTouchTargets() {
        #expect(TrackerLayout.minimumTarget >= 44)
        #expect(TrackerLayout.readableWidth == 640)
        #expect(TrackerLayout.cardRadius > TrackerLayout.controlRadius)
    }

    private func contrast(_ first: Color, _ second: Color) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func luminance(_ color: Color) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        let converted = UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(converted)
        #expect(alpha == 1)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
