import UIKit
import SwiftUI

extension UIImage {
    /// Extracts the most vibrant representative color by sampling a downscaled version.
    func dominantColor() -> Color? {
        guard let cgImage = cgImage else { return nil }

        let size = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: size * size * 4)

        guard let ctx = CGContext(
            data: &raw, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        var bestColor: (r: Double, g: Double, b: Double) = (0.5, 0.5, 0.5)
        var bestScore: Double = -1

        for i in stride(from: 0, to: raw.count, by: 4) {
            let r = Double(raw[i]) / 255.0
            let g = Double(raw[i + 1]) / 255.0
            let b = Double(raw[i + 2]) / 255.0

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC
            let lightness = (maxC + minC) / 2.0
            let saturation = delta < 0.001 ? 0.0 : delta / (1.0 - abs(2.0 * lightness - 1.0))

            // Prefer saturated colors in a comfortable brightness range
            let score = saturation * 2.0
                + (1.0 - abs(lightness - 0.45))
                - (lightness < 0.1 ? 2.0 : 0)
                - (lightness > 0.9 ? 2.0 : 0)

            if score > bestScore {
                bestScore = score
                bestColor = (r, g, b)
            }
        }

        return Color(.sRGB, red: bestColor.r, green: bestColor.g, blue: bestColor.b, opacity: 1)
    }

    func dominantColorHex() -> String? {
        guard let cgImage = cgImage else { return nil }

        let size = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: size * size * 4)

        guard let ctx = CGContext(
            data: &raw, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        var bestR: UInt8 = 128, bestG: UInt8 = 128, bestB: UInt8 = 128
        var bestScore: Double = -1

        for i in stride(from: 0, to: raw.count, by: 4) {
            let r = Double(raw[i]) / 255.0
            let g = Double(raw[i + 1]) / 255.0
            let b = Double(raw[i + 2]) / 255.0

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC
            let lightness = (maxC + minC) / 2.0
            let saturation = delta < 0.001 ? 0.0 : delta / (1.0 - abs(2.0 * lightness - 1.0))

            let score = saturation * 2.0
                + (1.0 - abs(lightness - 0.45))
                - (lightness < 0.1 ? 2.0 : 0)
                - (lightness > 0.9 ? 2.0 : 0)

            if score > bestScore {
                bestScore = score
                bestR = raw[i]; bestG = raw[i + 1]; bestB = raw[i + 2]
            }
        }

        return String(format: "#%02X%02X%02X", bestR, bestG, bestB)
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((val >> 16) & 0xFF) / 255.0,
            green: Double((val >> 8) & 0xFF) / 255.0,
            blue: Double(val & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
