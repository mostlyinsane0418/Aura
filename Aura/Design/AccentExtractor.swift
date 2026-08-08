import CoreImage
import SwiftUI
import UIKit

/// Derives a per-journey accent colour from its hero image.
///
/// Aura has no brand colour on purpose — a fixed accent would compete with the
/// photography, and every journey would look like every other one. Instead each
/// journey borrows its own palette from its hero frame, which is why a Lisbon
/// afternoon and a Reykjavík evening feel different before you read a word.
@MainActor
final class AccentExtractor {
    static let shared = AccentExtractor()

    private let context = CIContext(options: [.workingColorSpace: NSNull()])
    private var cache: [String: Color] = [:]

    private init() {}

    func accent(for image: UIImage, key: String) -> Color {
        if let cached = cache[key] { return cached }

        let accent = Self.dominantColor(of: image).map(Self.makeLegible) ?? .accentColor
        cache[key] = accent
        return accent
    }

    /// Mean colour of the image. Averaging is crude next to a k-means dominant-colour
    /// pass, but it is stable frame to frame — no flicker as thumbnails resolve — and
    /// after saturation clamping the difference is not visible at accent size.
    private static func dominantColor(of image: UIImage) -> HSB? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let extent = CIVector(
            x: ciImage.extent.origin.x,
            y: ciImage.extent.origin.y,
            z: ciImage.extent.size.width,
            w: ciImage.extent.size.height
        )
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extent]
        ), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        shared.context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: 1
        ).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        return HSB(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// An average colour is usually muddy and often too dark or too pale to read as
    /// an accent. Keep the hue — that is the part that carries the memory — and force
    /// saturation and brightness into a band that stays legible on both canvases.
    private static func makeLegible(_ hsb: HSB) -> Color {
        Color(
            hue: hsb.hue,
            saturation: min(max(hsb.saturation * 1.6, 0.45), 0.85),
            brightness: min(max(hsb.brightness * 1.1, 0.55), 0.9)
        )
    }

    private struct HSB {
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
    }
}
