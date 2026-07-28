import SwiftUI

// Iconografía monolínea 1.25px del design system (punto 03): trazo redondo,
// sin relleno, gestual — no geométrica. Paths tomados literalmente de los
// SVG de "Umbral. Desing System.html" / IC.* en index.html, reescalados
// desde su viewBox 24×24 original a cualquier frame.

private func pt(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX + x / 24 * rect.width, y: rect.minY + y / 24 * rect.height)
}

/// Icono "recuperación" / "hoy": línea que ondula + base punteada.
/// SVG: M3 15 Q7 11 12 12 T21 8 · line 3,15–21,15 dasharray
struct UmbralSquiggleIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(3, 15, in: rect))
        p.addQuadCurve(to: pt(12, 12, in: rect), control: pt(7, 11, in: rect))
        p.addQuadCurve(to: pt(21, 8, in: rect), control: pt(17, 13, in: rect))
        return p
    }
}

struct UmbralSquiggleBaseline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(3, 15, in: rect))
        p.addLine(to: pt(21, 15, in: rect))
        return p
    }
}

/// Icono "semana": rejilla de calendario.
/// SVG: rect 3,4,18,17 · line 3,9–21,9 · line 9,9–9,21 · line 15,9–15,21
struct UmbralGridIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: pt(3, 4, in: rect).x, y: pt(3, 4, in: rect).y,
                          width: pt(21, 21, in: rect).x - pt(3, 4, in: rect).x,
                          height: pt(21, 21, in: rect).y - pt(3, 4, in: rect).y))
        p.move(to: pt(3, 9, in: rect)); p.addLine(to: pt(21, 9, in: rect))
        p.move(to: pt(9, 9, in: rect)); p.addLine(to: pt(9, 21, in: rect))
        p.move(to: pt(15, 9, in: rect)); p.addLine(to: pt(15, 21, in: rect))
        return p
    }
}

/// Icono "registro": lupa.
/// SVG: circle 11,11 r6 · line 15.5,15.5–21,21
struct UmbralLupaIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = pt(11, 11, in: rect)
        let r = pt(17, 11, in: rect).x - c.x
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: pt(15.5, 15.5, in: rect)); p.addLine(to: pt(21, 21, in: rect))
        return p
    }
}

/// Icono "récord": cinta/banderín.
/// SVG: M6 4 L6 20 L12 15 L18 20 L18 4 (abierto arriba, sin cerrar)
struct UmbralRibbonIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(6, 4, in: rect))
        p.addLine(to: pt(6, 20, in: rect))
        p.addLine(to: pt(12, 15, in: rect))
        p.addLine(to: pt(18, 20, in: rect))
        p.addLine(to: pt(18, 4, in: rect))
        return p
    }
}

/// Icono "añadir": cruz.
struct UmbralPlusIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(12, 5, in: rect)); p.addLine(to: pt(12, 19, in: rect))
        p.move(to: pt(5, 12, in: rect)); p.addLine(to: pt(19, 12, in: rect))
        return p
    }
}

/// Icono "engranaje"/ajustes reemplazado por el propio isotipo — ver UmbralIsotype.

/// Icono "vfc": latido.
/// SVG: polyline 3,13 8,13 10,7 13,19 15,13 21,13
struct UmbralVfcIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(3, 13, in: rect))
        for (x, y): (CGFloat, CGFloat) in [(8, 13), (10, 7), (13, 19), (15, 13), (21, 13)] {
            p.addLine(to: pt(x, y, in: rect))
        }
        return p
    }
}

/// Icono "descanso"/"sueño": luna.
/// SVG: M18 14 A7 7 0 1 1 10 6 A5 5 0 0 0 18 14 Z
struct UmbralMoonIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let start = pt(18, 14, in: rect)
        p.move(to: start)
        p.addArc(center: pt(11, 10, in: rect), radius: pt(18, 10, in: rect).x - pt(11, 10, in: rect).x,
                  startAngle: .degrees(16), endAngle: .degrees(310), clockwise: false)
        p.addArc(center: pt(13, 10, in: rect), radius: pt(18, 10, in: rect).x - pt(13, 10, in: rect).x,
                  startAngle: .degrees(310), endAngle: .degrees(90), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// Icono "sesión"/"carga": caja con línea — reutilizado tal cual en index.html (IC.carga = IC.sesión).
/// SVG: rect 4,6,16,12 · line 4,12–20,12
struct UmbralSessionIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let a = pt(4, 6, in: rect), b = pt(20, 18, in: rect)
        p.addRect(CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y))
        p.move(to: pt(4, 12, in: rect)); p.addLine(to: pt(20, 12, in: rect))
        return p
    }
}

/// Icono "crossfit": barbell fino.
/// SVG: rect 3,9,4,6 · rect 17,9,4,6 · line 7,12–17,12 (grosor 2)
struct UmbralCrossfitIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: pt(3, 9, in: rect).x, y: pt(3, 9, in: rect).y,
                          width: pt(7, 15, in: rect).x - pt(3, 9, in: rect).x, height: pt(7, 15, in: rect).y - pt(3, 9, in: rect).y))
        p.addRect(CGRect(x: pt(17, 9, in: rect).x, y: pt(17, 9, in: rect).y,
                          width: pt(21, 15, in: rect).x - pt(17, 9, in: rect).x, height: pt(21, 15, in: rect).y - pt(17, 9, in: rect).y))
        p.move(to: pt(7, 12, in: rect)); p.addLine(to: pt(17, 12, in: rect))
        return p
    }
}

/// Icono "hyrox": trineo/tejado.
/// SVG: M4 20 L4 10 L12 6 L20 10 L20 20 · line 4,14–20,14
struct UmbralHyroxIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(4, 20, in: rect))
        for (x, y): (CGFloat, CGFloat) in [(4, 10), (12, 6), (20, 10), (20, 20)] {
            p.addLine(to: pt(x, y, in: rect))
        }
        p.move(to: pt(4, 14, in: rect)); p.addLine(to: pt(20, 14, in: rect))
        return p
    }
}

/// Icono "carrera": figura corriendo, abstracta.
/// SVG: circle 15,5 r1.5 · path M7,20 L11,14 L14,10 L18,12 · path M8,15 L11,13
struct UmbralCarreraIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = pt(15, 5, in: rect)
        let r = pt(16.5, 5, in: rect).x - c.x
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: pt(7, 20, in: rect))
        for (x, y): (CGFloat, CGFloat) in [(11, 14), (14, 10), (18, 12)] { p.addLine(to: pt(x, y, in: rect)) }
        p.move(to: pt(8, 15, in: rect)); p.addLine(to: pt(11, 13, in: rect))
        return p
    }
}

/// Icono "gimnásticos": anillas.
/// SVG: line 4,12–20,12 · circle 12,7 r2.5 · line 12,9.5–12,12
struct UmbralGimnasticosIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(4, 12, in: rect)); p.addLine(to: pt(20, 12, in: rect))
        let c = pt(12, 7, in: rect)
        let r = pt(14.5, 7, in: rect).x - c.x
        p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        p.move(to: pt(12, 9.5, in: rect)); p.addLine(to: pt(12, 12, in: rect))
        return p
    }
}

/// Icono "fuerza": barbell grueso.
/// SVG: rect 2,10,3,4 · rect 19,10,3,4 · line 5,12–19,12 (grosor 2.5)
struct UmbralFuerzaIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(x: pt(2, 10, in: rect).x, y: pt(2, 10, in: rect).y,
                          width: pt(5, 14, in: rect).x - pt(2, 10, in: rect).x, height: pt(5, 14, in: rect).y - pt(2, 10, in: rect).y))
        p.addRect(CGRect(x: pt(19, 10, in: rect).x, y: pt(19, 10, in: rect).y,
                          width: pt(22, 14, in: rect).x - pt(19, 10, in: rect).x, height: pt(22, 14, in: rect).y - pt(19, 10, in: rect).y))
        p.move(to: pt(5, 12, in: rect)); p.addLine(to: pt(19, 12, in: rect))
        return p
    }
}

/// Icono "movilidad": zigzag de estiramiento.
/// SVG: M4 12 L8 8 L12 14 L16 10 L20 15
struct UmbralMovilidadIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(4, 12, in: rect))
        for (x, y): (CGFloat, CGFloat) in [(8, 8), (12, 14), (16, 10), (20, 15)] { p.addLine(to: pt(x, y, in: rect)) }
        return p
    }
}

/// Icono "sync whoop": flechas circulares.
struct UmbralSyncIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: pt(11, 9.5, in: rect), radius: pt(18, 9.5, in: rect).x - pt(11, 9.5, in: rect).x,
                  startAngle: .degrees(190), endAngle: .degrees(-30), clockwise: false)
        p.addArc(center: pt(13, 14.5, in: rect), radius: pt(20, 14.5, in: rect).x - pt(13, 14.5, in: rect).x,
                  startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
        p.move(to: pt(18, 4, in: rect)); p.addLine(to: pt(18, 7, in: rect)); p.addLine(to: pt(15, 7, in: rect))
        p.move(to: pt(6, 20, in: rect)); p.addLine(to: pt(6, 17, in: rect)); p.addLine(to: pt(9, 17, in: rect))
        return p
    }
}

/// Icono "caret": chevron — IC.caret en index.html (apunta abajo; se rota
/// para usos de disclosure lateral).
/// SVG: polyline 6,9 12,15 18,9
struct UmbralCaretIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: pt(6, 9, in: rect))
        p.addLine(to: pt(12, 15, in: rect))
        p.addLine(to: pt(18, 9, in: rect))
        return p
    }
}

/// Devuelve el icono monolínea de una disciplina por nombre — nunca SF Symbols.
struct DisciplineIcon: View {
    let name: String
    var color: Color = .umbralHueso
    var lineWidth: CGFloat = 1.4

    var body: some View {
        Group {
            switch name.lowercased() {
            case "crossfit": UmbralCrossfitIcon().umbralIconStyle(color, lineWidth: lineWidth)
            case "hyrox": UmbralHyroxIcon().umbralIconStyle(color, lineWidth: lineWidth)
            case "carrera": UmbralCarreraIcon().umbralIconStyle(color, lineWidth: lineWidth)
            case "gimnásticos", "gimnasticos": UmbralGimnasticosIcon().umbralIconStyle(color, lineWidth: lineWidth)
            case "fuerza": UmbralFuerzaIcon().umbralIconStyle(color, lineWidth: lineWidth)
            case "movilidad": UmbralMovilidadIcon().umbralIconStyle(color, lineWidth: lineWidth)
            case "descanso": UmbralMoonIcon().umbralIconStyle(color, lineWidth: lineWidth)
            default: UmbralSessionIcon().umbralIconStyle(color, lineWidth: lineWidth)
            }
        }
    }
}

extension Shape {
    func umbralIconStyle(_ color: Color = .umbralHueso, lineWidth: CGFloat = 1.25) -> some View {
        self.stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

/// Isotipo · "u" itálica + punto teja al pie — spec 02A. Marca reducida
/// derivada del wordmark, para usos pequeños (favicon, panel de usuario).
/// El punto va A LA ALTURA DE LA LÍNEA BASE, no flotando por encima.
struct UmbralIsotype: View {
    var size: CGFloat = 32
    var color: Color = .umbralHueso
    var dotColor: Color = .umbralTeja

    var body: some View {
        HStack(alignment: .bottom, spacing: size * 0.03) {
            Text("u")
                .font(.umbralSerif(size))
                .foregroundStyle(color)
                .fixedSize()
            Rectangle()
                .fill(dotColor)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(y: -size * 0.04)
        }
    }
}

/// Botón central del footer: línea de recuperación ondulando sin parar,
/// motivo del icono "recuperación" pero vivo. Abre el panel de usuario.
struct UmbralWaveIcon: View {
    var color: Color = .umbralTeja
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var path = Path()
                let midY = size.height / 2
                let amplitude = size.height * 0.28
                let steps = 40
                for i in 0...steps {
                    let x = CGFloat(i) / CGFloat(steps) * size.width
                    let angle = (x / size.width) * .pi * 2 + CGFloat(t * 2.2)
                    let y = midY + sin(angle) * amplitude
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
