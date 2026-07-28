import SwiftUI

/// Regla 03 del sistema: separación por línea, nunca cajas cerradas.
struct DashedDivider: View {
    var color: Color = .umbralLineaDark
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .overlay(
                GeometryReader { geo in
                    Path { p in
                        p.move(to: .zero)
                        p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            )
    }
}

enum ThresholdState { case sobre, bajo, sinDato }

struct ThresholdBadge: View {
    let state: ThresholdState
    let recovery: Double?

    var body: some View {
        Group {
            switch state {
            case .sinDato:
                Text("SIN LECTURA HOY")
                    .foregroundStyle(.umbralHumo)
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.umbralLineaDark, lineWidth: 1))
            case .sobre:
                Text("SOBRE UMBRAL · \(Int(recovery ?? 0))%")
                    .foregroundStyle(.umbralTinta)
                    .background(Color.umbralHueso)
            case .bajo:
                Text("BAJO UMBRAL · \(Int(recovery ?? 0))%")
                    .foregroundStyle(.white)
                    .background(Color.umbralTeja)
            }
        }
        .font(UType.label(10))
        .tracking(1.0)
        .padding(.horizontal, 10).padding(.vertical, 5)
    }
}

struct FilterChip: View {
    let label: String
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(UType.label(10))
                .tracking(1.0)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selected ? Color.umbralTinta : .umbralHueso)
                .background(selected ? Color.umbralHueso : Color.clear)
                .overlay(
                    Rectangle().stroke(selected ? Color.umbralHueso : Color.umbralLineaDark, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    let title: String
    var destructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 12)
                .foregroundStyle(.umbralTinta)
                .background(destructive ? Color.umbralTeja : Color.umbralHueso)
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 12)
                .foregroundStyle(.umbralHueso)
                .overlay(Rectangle().stroke(Color.umbralHueso, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Espejo papel de PrimaryButton/GhostButton — polaridad invertida (regla 01),
/// mismo acento teja para el estado destructivo (regla 02: un solo acento,
/// nunca el rojo de sistema).
struct PapelPrimaryButton: View {
    let title: String
    var destructive: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 12)
                .foregroundStyle(destructive ? .white : Color.umbralPapel)
                .background(destructive ? Color.umbralTeja : Color.umbralTinta)
        }
        .buttonStyle(.plain)
    }
}

struct PapelGhostButton: View {
    let title: String
    var tone: Color = .umbralTinta
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 20).padding(.vertical, 12)
                .foregroundStyle(tone)
                .overlay(Rectangle().stroke(tone, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Campo de formulario en polaridad papel — promovido desde DayEditorView,
/// lo reutilizan WHOOP/GitHub/Datos y privacidad en el panel de usuario.
struct PapelField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.umbralTinta)
                .padding(10)
                .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))
        }
    }
}

/// Fila de especificación en polaridad papel — label fino + dato, separados
/// por línea punteada. Promovida desde DayEditorView/RegistroDetailView.
struct PapelSpecRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack {
            Text(label).font(UType.label(9)).foregroundStyle(.umbralHumo)
            Spacer()
            Text(value ?? "—").font(UType.card(13)).foregroundStyle(.umbralTinta)
        }
        .padding(.vertical, 8)
        .overlay(DashedDivider(color: .umbralLineaLight), alignment: .bottom)
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    var unit: String = ""
    var icon: AnyShape? = nil

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if let icon { icon.umbralIconStyle(.umbralHueso, lineWidth: 1.25).frame(width: 13, height: 13) }
                Text(label).capLabel()
            }
            Spacer()
            (Text(value).font(UType.data(22)) + Text(unit.isEmpty ? "" : " \(unit)").font(UType.label(11)).foregroundStyle(.umbralHumo))
                .tabularData()
                .foregroundStyle(.umbralHueso)
        }
    }
}

/// Chevron propio (regla 03: iconografía monolínea, nunca SF Symbols) —
/// IC.caret apunta abajo por defecto, se rota para disclosure lateral.
struct CaretRight: View {
    var color: Color = .umbralHumo
    var body: some View {
        UmbralCaretIcon()
            .umbralIconStyle(color, lineWidth: 1.4)
            .rotationEffect(.degrees(-90))
            .frame(width: 12, height: 12)
    }
}

/// Fondo tinta full-bleed, como el .app del panel web.
struct InkBackground: View {
    var body: some View {
        Color.umbralTinta.ignoresSafeArea()
    }
}

/// Fondo papel para menús/detalle/formulario (regla 01). Deja una franja
/// tinta exactamente detrás del status bar/Dynamic Island: preferredColorScheme
/// no siempre repinta el estilo del status bar del sistema en vistas
/// empujadas por NavigationStack, y reloj/wifi en blanco sobre papel es
/// ilegible. Corte limpio, sin degradado — encaja con la regla 07.
struct PapelBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.umbralPapel.ignoresSafeArea()
                Color.umbralTinta
                    .frame(height: geo.safeAreaInsets.top)
                    .ignoresSafeArea(edges: .top)
            }
        }
    }
}
