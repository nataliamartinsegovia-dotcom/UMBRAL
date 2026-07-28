import SwiftUI

private enum UmbralFiltro { case ninguno, sobre, bajo }

struct RegistroView: View {
    @ObservedObject var store: UmbralStore
    @State private var texto = ""
    @State private var discSeleccionadas: Set<String> = []
    @State private var umbralFiltro: UmbralFiltro = .ninguno

    private var disciplinasConteo: [(String, Int)] {
        var counts: [String: Int] = [:]
        for s in store.sessions { counts[s.disciplina, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }
    }

    private var filtradas: [SessionEntry] {
        store.sessions.filter { s in
            if !discSeleccionadas.isEmpty && !discSeleccionadas.contains(s.disciplina) { return false }
            switch umbralFiltro {
            case .sobre: guard let r = s.rec, r >= store.threshold else { return false }
            case .bajo: guard let r = s.rec, r < store.threshold else { return false }
            case .ninguno: break
            }
            if !texto.isEmpty {
                let q = texto.lowercased()
                let hay = [s.titulo, s.desc, s.sensaciones, s.disciplina, s.resultado].joined(separator: " ").lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        UmbralScreen(content: {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                header
                Section {
                    lista
                } header: {
                    VStack(alignment: .leading, spacing: 10) {
                        searchField
                        filtros
                    }
                    .background(Color.umbralTinta)
                    .padding(.bottom, 6)
                }
            }
        }, trailing: AnyView(SyncChip(store: store)))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Histórico buscable").capLabel().foregroundStyle(.umbralHueso)
                Text("Registro").font(UType.section()).foregroundStyle(.umbralHueso)
            }
            Spacer()
            Text("\(filtradas.count) DE \(store.sessions.count)").font(UType.label(10)).foregroundStyle(.umbralHumo)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            UmbralLupaIcon().umbralIconStyle(.umbralHumo).frame(width: 16, height: 16)
            TextField("Buscar por texto: Fran, sled, thrusters…", text: $texto)
                .textFieldStyle(.plain)
                .foregroundStyle(.umbralHueso)
        }
        .padding(14)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(disciplinasConteo, id: \.0) { name, count in
                    FilterChip(label: "\(name) · \(count)", selected: discSeleccionadas.contains(name)) {
                        if discSeleccionadas.contains(name) { discSeleccionadas.remove(name) } else { discSeleccionadas.insert(name) }
                    }
                }
                FilterChip(label: "Sobre umbral", selected: umbralFiltro == .sobre) {
                    umbralFiltro = umbralFiltro == .sobre ? .ninguno : .sobre
                }
                FilterChip(label: "Bajo umbral", selected: umbralFiltro == .bajo) {
                    umbralFiltro = umbralFiltro == .bajo ? .ninguno : .bajo
                }
                if !discSeleccionadas.isEmpty || umbralFiltro != .ninguno || !texto.isEmpty {
                    FilterChip(label: "Limpiar") {
                        discSeleccionadas.removeAll(); umbralFiltro = .ninguno; texto = ""
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var lista: some View {
        if filtradas.isEmpty {
            VStack(spacing: 6) {
                Text("nada aún").font(.system(size: 20, design: .serif)).italic().foregroundStyle(.umbralTeja)
                Text("No hay sesiones que coincidan con el filtro, o todavía no se han registrado.")
                    .font(.system(size: 13)).foregroundStyle(.umbralHumo)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
            .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.umbralLineaDark))
        } else {
            VStack(spacing: 0) {
                ForEach(filtradas.prefix(120)) { s in
                    NavigationLink {
                        // Interconectado con Semana: si la sesión tiene plan, se
                        // edita en el mismo sitio — un único editor por día,
                        // no una copia de solo lectura desincronizable.
                        if s.planificado {
                            DayEditorView(store: store, monday: UDate.mondayOf(s.fecha), iso: s.fecha, label: "SESIÓN")
                        } else {
                            RegistroDetailView(session: s, threshold: store.threshold)
                        }
                    } label: {
                        RegistroRow(session: s, threshold: store.threshold)
                    }
                    .buttonStyle(.plain)
                    if s.id != filtradas.prefix(120).last?.id { DashedDivider(color: .umbralLineaDark.opacity(0.6)) }
                }
            }
            .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
        }
    }
}

private struct RegistroRow: View {
    let session: SessionEntry
    let threshold: Double

    var body: some View {
        HStack(spacing: 14) {
            DisciplineIcon(name: session.disciplina, color: .umbralHueso).frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.titulo).font(UType.card(15)).foregroundStyle(.umbralHueso).lineLimit(1)
                Text("\(session.disciplina) · \(session.cats.joined(separator: ", "))".uppercased())
                    .font(UType.label(9)).foregroundStyle(.umbralHumo)
            }
            Spacer()
            if let rec = session.rec {
                Text("\(Int(rec))%").font(UType.card(15)).foregroundStyle(.umbralHueso)
            }
            Text(UDate.label(session.fecha)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.umbralHumo)
            CaretRight()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

/// Detalle de solo lectura (sesión sin plan asociado) → papel/tinta
/// invertido, regla 01 del design system.
private struct RegistroDetailView: View {
    let session: SessionEntry
    let threshold: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.disciplina.uppercased() + " · " + UDate.label(session.fecha))
                        .capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text(session.titulo).font(UType.section(24)).foregroundStyle(.umbralTinta)
                }

                if !session.desc.isEmpty { prose("Descripción", session.desc) }
                if !session.resultado.isEmpty { prose("Resultado", session.resultado) }
                if !session.sensaciones.isEmpty { prose("Sensaciones", session.sensaciones) }
                if session.desc.isEmpty && session.resultado.isEmpty && session.sensaciones.isEmpty {
                    Text("Sin anotación en esta sesión.").font(.system(size: 13)).foregroundStyle(.umbralHumo)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        UmbralSquiggleIcon().umbralIconStyle(.umbralTinta, lineWidth: 1.25).frame(width: 13, height: 13)
                        Text("Datos Whoop").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    }
                    VStack(spacing: 0) {
                        PapelSpecRow(label: "Recuperación", value: session.rec.map { "\(Int($0)) %" })
                        PapelSpecRow(label: "VFC", value: session.hrv.map { "\(Int($0)) ms" })
                        PapelSpecRow(label: "Sueño", value: session.sueno.map { "\(Int($0)) %" })
                        PapelSpecRow(label: "Carga del día", value: session.strain.map { String(format: "%.1f", $0) })
                        if let z = session.zonaObjetivo { PapelSpecRow(label: "Zona objetivo", value: "Z\(z)") }
                        if let r = session.rpe { PapelSpecRow(label: "Esfuerzo", value: "RPE \(r)") }
                    }
                }
                .padding(16)
                .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .preferredColorScheme(.light)
    }

    private func prose(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
            Text(text).font(.system(size: 14)).foregroundStyle(.umbralTinta.opacity(0.85))
        }
    }
}
