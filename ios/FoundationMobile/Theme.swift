import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x0a0e27)
    static let surface = Color(hex: 0x0f1636)
    static let border = Color(hex: 0x1e2a5a)
    static let muted = Color(hex: 0x9aa3c7)
    static let brandGreen = Color(hex: 0x34d399)
    static let brandCyan = Color(hex: 0x22d3ee)
    static let voice = Color(hex: 0x818cf8)
    static let share = Color(hex: 0x2dd4bf)
    static let market = Color(hex: 0x22d3ee)
    static var pillBg: Color { brandGreen.opacity(0.12) }

    static let ringLabels: [Int: String] = [
        0: "Ring 0 — Founder",
        1: "Ring 1 — Admin",
        2: "Ring 2 — Steward",
        3: "Ring 3 — Contributor",
        4: "Ring 4 — Member",
        5: "Ring 5 — Guest",
    ]
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xff) / 255.0
        let g = Double((hex >> 8) & 0xff) / 255.0
        let b = Double(hex & 0xff) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
