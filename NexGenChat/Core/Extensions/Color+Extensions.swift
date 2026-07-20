import SwiftUI

extension Color {
    /// Create a Color from a 0xRRGGBB hex integer.
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Create a Color from a "#RRGGBB" / "RRGGBB" string. Falls back to clear.
    init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else {
            self = .clear
            return
        }
        self.init(hex: UInt(value))
    }
}
