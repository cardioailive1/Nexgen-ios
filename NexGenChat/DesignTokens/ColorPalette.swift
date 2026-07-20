import SwiftUI

/// Central brand color palette, derived from the original NexGen Chat web app.
/// Dark navy surface family with a cyan accent and a violet "Ultra" highlight.
enum AppColor {
    // Backgrounds
    static let background = Color(hex: 0x0F2645)
    static let surface    = Color(hex: 0x162E52)
    static let panel      = Color(hex: 0x1B3560)
    static let lift       = Color(hex: 0x1E3D6E)

    // Text
    static let text  = Color(hex: 0xE8F2FB)
    static let dim   = Color(hex: 0x9BC0D8)
    static let muted = Color(hex: 0x5A84A8)

    // Accent / brand
    static let accent = Color(hex: 0x00C8FF)

    // Model tiers
    static let flash = Color(hex: 0x00AADD)
    static let pro   = Color(hex: 0x00C8FF)
    static let ultra = Color(hex: 0xA78BFA)

    // Status
    static let success = Color(hex: 0x00E87A)
    static let warning = Color(hex: 0xFFB830)
    static let danger  = Color(hex: 0xFF4D4D)

    /// Primary top-to-bottom app background gradient.
    static let backgroundGradient = LinearGradient(
        colors: [Color(hex: 0x0F2645), Color(hex: 0x0A1B33)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Accent gradient used on primary CTAs.
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x00C8FF), Color(hex: 0x0077B6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
