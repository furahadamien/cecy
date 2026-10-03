import Testing
import UIKit

@MainActor
struct AppBrandingTests {
    @Test func appBundleDeclaresPrimaryIcon() throws {
        let icons = try #require(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
        let files = try #require(primary["CFBundleIconFiles"] as? [String])
        #expect(!files.isEmpty)
        #expect(Bundle.main.object(forInfoDictionaryKey: "UILaunchStoryboardName") as? String == "LaunchScreen")
    }

    @Test func launchArtworkKeepsTransparentOuterEdges() throws {
        let image = try #require(UIImage(named: "LaunchIcon")?.cgImage)
        let side = 120
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(
                data: bytes.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * side + x) * 4 + 3] }
        for index in 0..<side {
            #expect(alpha(index, 0) == 0)
            #expect(alpha(index, side - 1) == 0)
            #expect(alpha(0, index) == 0)
            #expect(alpha(side - 1, index) == 0)
        }
        // Keep actual artwork, not an accidentally empty transparent asset.
        #expect(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] == 255 })
    }

    @Test(arguments: [
        CGSize(width: 320, height: 568),
        CGSize(width: 568, height: 320),
        CGSize(width: 393, height: 852),
        CGSize(width: 768, height: 1024),
        CGSize(width: 1024, height: 768)
    ])
    func launchArtworkPreservesTaglineAndFits(size: CGSize) throws {
        let controller = try #require(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
        let view = try #require(controller.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let imageView = try #require(view.subviews.compactMap { $0 as? UIImageView }.first)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        #expect(!labels.contains { $0.text?.lowercased() == "cecy" })
        let tagline = try #require(labels.first { $0.text == "Your rhythm. Your records." })
        #expect(imageView.image != nil)
        #expect(imageView.contentMode == .scaleAspectFit)
        #expect(!imageView.isAccessibilityElement)
        #expect(imageView.frame.size == CGSize(width: 120, height: 120))
        #expect(abs(imageView.center.x - view.bounds.midX) < 1)
        #expect(abs(tagline.frame.minY - imageView.frame.maxY - 24) < 1)
        for element in [imageView, tagline] {
            #expect(!element.hasAmbiguousLayout)
            #expect(view.bounds.contains(element.frame))
        }
    }
}
