import SwiftUI

struct BasaltGlass: ViewModifier {
    var tint: Color? = nil
    
    func body(content: Content) -> some View {
        if let tint {
            content.glassEffect(.regular.interactive().tint(tint))
        } else {
            content.glassEffect(.regular.interactive())
        }
    }
}

extension View {
    func basaltGlass(tint: Color? = nil) -> some View {
        modifier(BasaltGlass(tint: tint))
    }
}
