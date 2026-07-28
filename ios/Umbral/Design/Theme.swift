import SwiftUI

// Tipografía del design system UMBRAL 18 · dirección Lewalk. Paleta y
// UMetrics viven en Shared/UmbralPalette.swift (los usa también el widget).
// Serif itálica = Georgia (ver Font.umbralSerif en Shared/UmbralPalette.swift,
// misma fuente que el isotipo/icono) para titulares, SF Pro para todo lo
// demás — hasta que se añadan los binarios reales de Fraunces / Instrument
// Sans a Resources/Fonts.

enum UType {
    /// H0 · hero
    static func hero(_ size: CGFloat = 52) -> Font {
        .umbralSerif(size)
    }
    /// H1 · sección
    static func section(_ size: CGFloat = 26) -> Font {
        .umbralSerif(size)
    }
    /// H2 · card
    static func card(_ size: CGFloat = 20) -> Font {
        .umbralSerif(size)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    /// Label · caps, tracking amplio
    static func label(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }
    /// Dato · tabular
    static func data(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

struct CapLabel: ViewModifier {
    var opacity: Double = 0.55
    func body(content: Content) -> some View {
        content
            .font(UType.label())
            .tracking(1.2)
            .textCase(.uppercase)
            .opacity(opacity)
    }
}

extension View {
    func capLabel(opacity: Double = 0.55) -> some View {
        modifier(CapLabel(opacity: opacity))
    }
    func tabularData() -> some View {
        self.monospacedDigit()
    }
}
