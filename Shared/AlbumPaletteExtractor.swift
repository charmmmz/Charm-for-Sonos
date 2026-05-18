import UIKit

struct HueXYColor: Equatable, Sendable {
    var x: Double
    var y: Double
}

struct HueRGBColor: Codable, Equatable, Hashable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    var brightness: Double {
        max(r, g, b)
    }

    var xy: HueXYColor {
        let red = gammaCorrect(r)
        let green = gammaCorrect(g)
        let blue = gammaCorrect(b)

        let x = red * 0.664511 + green * 0.154324 + blue * 0.162028
        let y = red * 0.283881 + green * 0.668433 + blue * 0.047685
        let z = red * 0.000088 + green * 0.072310 + blue * 0.986039
        let total = x + y + z

        guard total > 0 else {
            return HueXYColor(x: 0.3127, y: 0.3290)
        }

        return HueXYColor(
            x: min(max(x / total, 0), 1),
            y: min(max(y / total, 0), 1)
        )
    }

    func gammaCorrect(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        if clamped > 0.04045 {
            return pow((clamped + 0.055) / 1.055, 2.4)
        }
        return clamped / 12.92
    }
}

enum AlbumPaletteExtractor {
    static func palette(from image: UIImage, maxColors: Int = 5) -> [HueRGBColor] {
        guard maxColors > 0 else { return [] }
        let colorLimit = min(maxColors, 5)

        let sampledColors = image.sampledHueColors()
        var buckets: [ColorBucketKey: ColorBucket] = [:]

        for color in sampledColors where color.isUsefulAlbumColor {
            let key = ColorBucketKey(color)
            buckets[key, default: ColorBucket()].add(color)
        }

        var palette: [HueRGBColor] = []
        for bucket in buckets.values.sorted(by: { $0.score > $1.score }) {
            let color = bucket.averageColor
            guard !palette.contains(where: { $0.distance(to: color) < 0.28 }) else {
                continue
            }
            palette.append(color)
            if palette.count == colorLimit {
                return palette
            }
        }

        if palette.isEmpty, let fallback = fallbackColor(from: sampledColors) {
            return [fallback]
        }

        return palette
    }

    static func motionPalette(from palette: [HueRGBColor]) -> [HueRGBColor] {
        guard palette.count == 1, let base = palette.first else {
            return palette
        }

        let hsl = rgbToHSL(base)
        if hsl.s < 0.12 {
            return [
                base,
                hslToRGB(h: hsl.h, s: 0, l: clamp(hsl.l + 0.16)),
                hslToRGB(h: hsl.h, s: 0, l: clamp(hsl.l - 0.12))
            ]
        }

        return [
            base,
            hslToRGB(h: hsl.h - 0.025, s: clamp(hsl.s * 0.92), l: clamp(hsl.l + 0.08)),
            hslToRGB(h: hsl.h + 0.025, s: clamp(hsl.s * 0.90), l: clamp(hsl.l - 0.07)),
            hslToRGB(h: hsl.h + 0.05, s: clamp(hsl.s * 0.82), l: clamp(hsl.l + 0.03))
        ]
    }

    private static func fallbackColor(from colors: [HueRGBColor]) -> HueRGBColor? {
        guard !colors.isEmpty else { return nil }

        let total = colors.reduce(HueRGBColor(r: 0, g: 0, b: 0)) { sum, color in
            HueRGBColor(
                r: sum.r + color.r,
                g: sum.g + color.g,
                b: sum.b + color.b
            )
        }
        return readableLightColor(HueRGBColor(
            r: total.r / Double(colors.count),
            g: total.g / Double(colors.count),
            b: total.b / Double(colors.count)
        ))
    }

    private static func readableLightColor(_ color: HueRGBColor) -> HueRGBColor {
        let maxComponent = color.brightness
        guard maxComponent > 0 else {
            return HueRGBColor(r: 0.3, g: 0.3, b: 0.3)
        }

        let targetMax = min(max(maxComponent, 0.3), 0.82)
        let scale = targetMax / maxComponent
        return HueRGBColor(
            r: min(max(color.r * scale, 0), 1),
            g: min(max(color.g * scale, 0), 1),
            b: min(max(color.b * scale, 0), 1)
        )
    }

    private static func rgbToHSL(_ color: HueRGBColor) -> (h: Double, s: Double, l: Double) {
        let r = clamp(color.r)
        let g = clamp(color.g)
        let b = clamp(color.b)
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let lightness = (maxValue + minValue) / 2

        guard maxValue != minValue else {
            return (0, 0, lightness)
        }

        let delta = maxValue - minValue
        let saturation: Double
        if lightness > 0.5 {
            saturation = delta / (2 - maxValue - minValue)
        } else {
            saturation = delta / (maxValue + minValue)
        }

        let hue: Double
        if maxValue == r {
            hue = ((g - b) / delta + (g < b ? 6 : 0)) / 6
        } else if maxValue == g {
            hue = ((b - r) / delta + 2) / 6
        } else {
            hue = ((r - g) / delta + 4) / 6
        }

        return (hue, saturation, lightness)
    }

    private static func hslToRGB(h: Double, s: Double, l: Double) -> HueRGBColor {
        let hue = positiveModulo(h, 1)
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        return HueRGBColor(
            r: hueToRGB(p: p, q: q, t: hue + 1 / 3),
            g: hueToRGB(p: p, q: q, t: hue),
            b: hueToRGB(p: p, q: q, t: hue - 1 / 3)
        )
    }

    private static func hueToRGB(p: Double, q: Double, t: Double) -> Double {
        var value = t
        if value < 0 { value += 1 }
        if value > 1 { value -= 1 }
        if value < 1 / 6 { return p + (q - p) * 6 * value }
        if value < 1 / 2 { return q }
        if value < 2 / 3 { return p + (q - p) * (2 / 3 - value) * 6 }
        return p
    }

    private static func positiveModulo(_ value: Double, _ divisor: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private struct ColorBucketKey: Hashable {
    let r: Int
    let g: Int
    let b: Int

    init(_ color: HueRGBColor) {
        r = Int((color.r * 5).rounded())
        g = Int((color.g * 5).rounded())
        b = Int((color.b * 5).rounded())
    }
}

private struct ColorBucket {
    private var rTotal: Double = 0
    private var gTotal: Double = 0
    private var bTotal: Double = 0
    private var count: Double = 0
    private var saturationTotal: Double = 0

    mutating func add(_ color: HueRGBColor) {
        rTotal += color.r
        gTotal += color.g
        bTotal += color.b
        saturationTotal += color.saturation
        count += 1
    }

    var averageColor: HueRGBColor {
        guard count > 0 else {
            return HueRGBColor(r: 0, g: 0, b: 0)
        }
        return HueRGBColor(r: rTotal / count, g: gTotal / count, b: bTotal / count)
    }

    var score: Double {
        count * max(saturationTotal / max(count, 1), 0.1) * max(averageColor.brightness, 0.1)
    }
}

private extension UIImage {
    func sampledHueColors() -> [HueRGBColor] {
        guard let cgImage else { return [] }

        let size = 24
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var raw = [UInt8](repeating: 0, count: size * size * 4)

        guard let context = CGContext(
            data: &raw,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        var colors: [HueRGBColor] = []
        colors.reserveCapacity(size * size)

        for index in stride(from: 0, to: raw.count, by: 4) {
            let alpha = Double(raw[index + 3]) / 255.0
            guard alpha > 0.1 else { continue }

            colors.append(HueRGBColor(
                r: Double(raw[index]) / 255.0,
                g: Double(raw[index + 1]) / 255.0,
                b: Double(raw[index + 2]) / 255.0
            ))
        }

        return colors
    }

}

private extension HueRGBColor {
    var saturation: Double {
        let maxComponent = max(r, g, b)
        let minComponent = min(r, g, b)
        guard maxComponent > 0 else { return 0 }
        return (maxComponent - minComponent) / maxComponent
    }

    var isUsefulAlbumColor: Bool {
        brightness >= 0.14 && saturation >= 0.22
    }

    func distance(to color: HueRGBColor) -> Double {
        let rDelta = r - color.r
        let gDelta = g - color.g
        let bDelta = b - color.b
        return sqrt(rDelta * rDelta + gDelta * gDelta + bDelta * bDelta)
    }
}
