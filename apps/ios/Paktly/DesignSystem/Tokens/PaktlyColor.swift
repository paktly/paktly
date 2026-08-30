import SwiftUI

enum PaktlyColor {
    static let background = Color(light: 0xF8F5ED, dark: 0x111A16)
    static let surface = Color(light: 0xFFFDF8, dark: 0x19241F)
    static let ink = Color(light: 0x18251F, dark: 0xF7F5EC)
    static let secondaryInk = Color(light: 0x65716B, dark: 0xA9B5AE)
    static let forest = Color(light: 0x214C3A, dark: 0xBFF1D3)
    static let mint = Color(light: 0xBFF1D3, dark: 0x285940)
    static let coral = Color(light: 0xFF816F, dark: 0xE87D6F)
    static let lavender = Color(light: 0xD9D1FF, dark: 0x514B70)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}
