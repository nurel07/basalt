import SwiftUI
import CoreText

extension Font {
    // MARK: - Typography System
    
    // Headings
    /// H1: 32pt, Semibold (600)
    static let basaltH1 = Font.system(size: 32, weight: .semibold)
    
    /// H2: 26pt, Semibold (600)
    static let basaltH2 = Font.system(size: 28, weight: .semibold)
    
    /// H3: 20pt, Semibold (600)
    static let basaltH3 = Font.system(size: 20, weight: .semibold)
    
    // Body Text
    /// Large: 18pt, Regular (400)
    static let basaltLarge = Font.system(size: 18, weight: .regular)
    
    /// Medium: 16pt, Regular (400)
    static let basaltMedium = Font.system(size: 17, weight: .regular)
    
    /// Small: 14pt, Regular (400)
    static let basaltSmall = Font.system(size: 14, weight: .regular)
    
    // Emphasized Body Text (Semibold/600)
    /// Large Emphasized: 18pt, Semibold (600)
    static let basaltLargeEmphasized = Font.system(size: 18, weight: .semibold)
    
    /// Medium Emphasized: 16pt, Semibold (600)
    static let basaltMediumEmphasized = Font.system(size: 17, weight: .semibold)
    
    /// Small Emphasized: 14pt, Semibold (600)
    static let basaltSmallEmphasized = Font.system(size: 14, weight: .semibold)
    
    /// Caption: 11pt, Regular (400) - For auxiliary text
    static let basaltCaption = Font.system(size: 11, weight: .regular)
    
    // MARK: - Serif Variants (Fraunces Variable Font)
    // Using variable font with: wght=600, WONK=1
    
    /// Create Fraunces font with variable axes: wght=600, WONK=1
    private static func fraunces(size: CGFloat) -> Font {
        // For variable fonts, use traits with weight setting
        // The font name for variable fonts is typically the family name
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: "Fraunces"
        ]).addingAttributes([
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                0x77676874: 600,  // 'wght' = 600
                0x574F4E4B: 1     // 'WONK' = 1
            ]
        ])
        
        let uiFont = UIFont(descriptor: descriptor, size: size)
        return Font(uiFont)
    }
    
    /// H1 Serif: 32pt (Fraunces wght=600, WONK=1)
    static let basaltH1Serif = fraunces(size: 32)
    
    /// H2 Serif: 26pt (Fraunces wght=600, WONK=1)
    static let basaltH2Serif = fraunces(size: 26)
    
    /// Body Serif: 16pt (Fraunces wght=600, WONK=1)
    static let basaltBodySerif = fraunces(size: 16)
}

