import SwiftUI

// Paleta del design system UMBRAL 18. Vive en Shared/ porque tanto la app
// como el widget de pantalla de inicio la necesitan.

extension Color {
    static let umbralTinta = Color(hex: "0A0A0A")
    static let umbralHueso = Color(hex: "F2EDE0")
    static let umbralPapel = Color(hex: "F5F1E8")
    static let umbralTeja  = Color(hex: "D94A2B")
    static let umbralHumo  = Color(hex: "8A8378")
    static let umbralLineaDark = Color(hex: "4A463D")
    static let umbralLineaLight = Color(hex: "C9C3B3")

    init(hex: String) {
        let s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// Permite `.foregroundStyle(.umbralHueso)` (ShapeStyle), no solo Color.umbralHueso.
extension ShapeStyle where Self == Color {
    static var umbralTinta: Color { .umbralTinta }
    static var umbralHueso: Color { .umbralHueso }
    static var umbralPapel: Color { .umbralPapel }
    static var umbralTeja: Color { .umbralTeja }
    static var umbralHumo: Color { .umbralHumo }
}

enum UMetrics {
    static let threshold = 67.0
    static let raceDateISO = "2026-12-12"
    static let defaultRepo = "nataliamartinsegovia-dotcom/UMBRAL"
    static let defaultBranch = "main"
}
