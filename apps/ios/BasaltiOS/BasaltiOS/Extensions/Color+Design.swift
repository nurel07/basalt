import SwiftUI

// MARK: - Stone Palette
// Raw color values from the design system
extension Color {
    // Stone palette - base colors
    static let stone50 = Color(hex: "FEFBF6")
    static let stone100 = Color(hex: "F6F3EE")
    static let stone200 = Color(hex: "E6E3DF")
    static let stone300 = Color(hex: "D1CECA")
    static let stone400 = Color(hex: "BDBAB5")
    static let stone500 = Color(hex: "A9A6A2")
    static let stone600 = Color(hex: "86847F")
    static let stone700 = Color(hex: "6C6965")
    static let stone800 = Color(hex: "6C6965")
    static let stone900 = Color(hex: "302E2B")
    static let stone950 = Color(hex: "161411")
}

// MARK: - Semantic Colors (Dark Mode Only)
extension Color {
    // Backgrounds (Dark Mode values)
    /// Primary Background: Stone/950
    static let basaltBackgroundPrimary = Color.stone950
    
    /// Secondary Background: Stone/900
    static let basaltBackgroundSecondary = Color.stone900
    
    /// Tertiary Background: Stone/950
    static let basaltBackgroundTertiary = Color.stone800
    
    // Text (Dark Mode values)
    /// Primary Text: Stone/50
    static let basaltTextPrimary = Color.stone50
    
    /// Secondary Text: Stone/400
    static let basaltTextSecondary = Color.stone400
}

// MARK: - Helpers
extension Color {
    /// Initialize Color from hex string (e.g., "FEFBF6")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

