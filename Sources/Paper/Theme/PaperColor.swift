import SwiftUI
import AppKit

/// A concrete sRGB color used throughout the theme. Stores fixed components so a
/// theme renders identically regardless of the system appearance, and vends both
/// SwiftUI `Color` and AppKit `NSColor` (the editor needs the latter).
struct PaperColor: Equatable, Hashable, Codable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
        self.a = alpha
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }

    /// A copy at a different opacity.
    func opacity(_ value: Double) -> PaperColor { PaperColor(r, g, b, value) }

    /// Relative luminance (WCAG), used to pick readable foregrounds over the accent.
    var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension Color {
    /// Best-effort conversion back to a `PaperColor` for the settings color well.
    var paperColor: PaperColor {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return PaperColor(Double(ns.redComponent), Double(ns.greenComponent),
                          Double(ns.blueComponent), Double(ns.alphaComponent))
    }
}
