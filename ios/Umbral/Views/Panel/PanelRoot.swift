import SwiftUI

/// Raíz del panel de usuario. Un solo scroll — cabecera de perfil, resumen
/// de cuenta, lista de navegación a las 4 subpáginas — siguiendo la misma
/// gramática que el resto de la app: overview arriba, lista-hub que empuja
/// a detalle abajo (igual que Hoy → DayEditorView, Registro → detalle).
/// Papel/tinta invertido (regla 01): el panel es un formulario/menú.
struct PanelRoot: View {
    @ObservedObject var store: UmbralStore
    @Environment(\.dismiss) private var dismiss

    private var nextReto: RetoItem? { store.nextReto }
    private var raceDays: Int? { nextReto.map { UDate.daysUntil($0.fecha, from: store.today) } }
    private var displayName: String {
        let full = store.perfil.nombreCompleto
        return full.isEmpty ? "Hola" : full
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    summary
                    DashedDivider(color: .umbralLineaLight)
                    nav
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(PapelBackground())
            .navigationTitle("Cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.umbralPapel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            UmbralIsotype(size: 26, color: .umbralTinta, dotColor: .umbralTeja)
            Text("\(displayName).")
                .font(UType.section(34))
                .foregroundStyle(.umbralTinta)
            Text(statusLine)
                .font(.system(size: 13))
                .foregroundStyle(.umbralTinta.opacity(0.7))
        }
    }

    private var statusLine: String {
        let base = store.whoopConnected ? "Conectada a WHOOP" : "WHOOP sin conectar"
        guard let sinceDate = store.dias.last?.date else { return base }
        return "\(base) · registrando desde \(UDate.label(sinceDate))"
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 20) {
            summaryStat("Racha", store.currentStreak > 0 ? "\(store.currentStreak) días" : "0 días",
                        color: store.currentStreak > 0 ? .umbralTeja : .umbralTinta)
            summaryStat("WHOOP", store.whoopConnected ? "En vivo" : "Sin conectar",
                        color: store.whoopConnected ? .umbralTeja : .umbralHumo)
            summaryStat("Objetivo", raceDays.map { "\($0) días" } ?? "—",
                        sub: nextReto?.nombre ?? "Sin retos", color: nextReto != nil ? .umbralTeja : .umbralHumo)
            summaryStat("Guardado", store.dirty ? "Sin guardar" : "Al día",
                        color: store.dirty ? .umbralTeja : .umbralTinta)
        }
    }

    private func summaryStat(_ label: String, _ value: String, sub: String? = nil, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(UType.label(9)).foregroundStyle(.umbralHumo)
            Text(value).font(UType.card(17)).foregroundStyle(color)
            if let sub { Text(sub).font(.system(size: 10)).foregroundStyle(.umbralHumo) }
        }
    }

    private var nav: some View {
        VStack(spacing: 0) {
            navRow(title: "Perfil", subtitle: "Bio · próximos retos",
                   value: raceDays.map { "\($0) días" } ?? "Sin retos",
                   valueColor: nextReto != nil ? .umbralTeja : .umbralHumo) {
                PerfilPanelView(store: store)
            }
            DashedDivider(color: .umbralLineaLight.opacity(0.6))
            navRow(title: "WHOOP", subtitle: "Lectura en vivo · sincronización",
                   value: store.whoopConnected ? "Conectado" : "Sin conectar",
                   valueColor: store.whoopConnected ? .umbralTeja : .umbralHumo) {
                WhoopPanelView(store: store)
            }
            DashedDivider(color: .umbralLineaLight.opacity(0.6))
            navRow(title: "GitHub", subtitle: "Guardado de planes y récords",
                   value: store.dirty ? "Sin guardar" : "Al día",
                   valueColor: store.dirty ? .umbralTeja : .umbralTinta) {
                GitHubPanelView(store: store)
            }
            DashedDivider(color: .umbralLineaLight.opacity(0.6))
            navRow(title: "Datos y privacidad", subtitle: "Qué se guarda y dónde",
                   value: nil, valueColor: .umbralTinta) {
                PrivacyPanelView(store: store)
            }
            DashedDivider(color: .umbralLineaLight.opacity(0.6))
            navRow(title: "Acerca de", subtitle: "Versión, repositorio, panel web",
                   value: "1.0", valueColor: .umbralHumo) {
                AboutPanelView()
            }
        }
        .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))
    }

    private func navRow<Destination: View>(
        icon: AnyView? = nil, title: String, subtitle: String, value: String?, valueColor: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                if let icon { icon }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(UType.card(17)).foregroundStyle(.umbralTinta)
                    Text(subtitle.uppercased()).font(UType.label(9)).tracking(0.4).foregroundStyle(.umbralTinta.opacity(0.55))
                }
                Spacer()
                if let value { Text(value).font(UType.label(10)).foregroundStyle(valueColor) }
                CaretRight(color: .umbralHumo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
