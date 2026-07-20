import SwiftUI

/// App-wide text styles. Uses the system font (SF Pro) for a native iOS feel.
enum AppFont {
    static func largeTitle() -> Font { .system(size: 32, weight: .bold, design: .default) }
    static func title() -> Font      { .system(size: 24, weight: .bold, design: .default) }
    static func headline() -> Font   { .system(size: 18, weight: .semibold, design: .default) }
    static func body() -> Font       { .system(size: 16, weight: .regular, design: .default) }
    static func callout() -> Font    { .system(size: 15, weight: .medium, design: .default) }
    static func caption() -> Font    { .system(size: 13, weight: .regular, design: .default) }
    static func mono() -> Font       { .system(size: 14, weight: .regular, design: .monospaced) }
}
