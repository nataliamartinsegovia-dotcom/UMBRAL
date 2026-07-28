import SwiftUI

/// Subpágina Perfil del panel de usuario — bio libre + próximos retos.
/// Primera de la lista de nav (antes de WHOOP): es contenido de identidad/
/// objetivos con flujo de edición propio, no una conexión técnica.
struct PerfilPanelView: View {
    @ObservedObject var store: UmbralStore
    @State private var mostrarNuevoReto = false

    private var proximosRetos: [RetoItem] {
        store.perfil.retos.filter { $0.fecha >= store.today }.sorted { $0.fecha < $1.fecha }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SOBRE TI").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text("Perfil.").font(UType.section(24)).foregroundStyle(.umbralTinta)
                }

                PapelField(label: "Sobre ti") {
                    ZStack(alignment: .topLeading) {
                        if store.perfil.bio.map(\.isEmpty) ?? true {
                            Text("Quién eres, por qué entrenas, qué te trajo hasta aquí…")
                                .foregroundStyle(.umbralTinta.opacity(0.35))
                                .padding(.top, 8).padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: store.bioBinding)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Próximos retos").font(UType.card(17)).foregroundStyle(.umbralTinta)
                        Spacer()
                        PapelPrimaryButton(title: "+ Nuevo reto") { mostrarNuevoReto = true }
                    }
                    if proximosRetos.isEmpty {
                        vacio
                    } else {
                        VStack(spacing: 0) {
                            ForEach(proximosRetos) { retoRow($0) }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .sheet(isPresented: $mostrarNuevoReto) { NuevoRetoSheet(store: store) }
    }

    private func retoRow(_ reto: RetoItem) -> some View {
        let dias = UDate.daysUntil(reto.fecha, from: store.today)
        let meta = [reto.disciplina, reto.lugar].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(reto.nombre).font(UType.card(16)).foregroundStyle(.umbralTinta)
                if !meta.isEmpty {
                    Text(meta.uppercased()).font(UType.label(9)).foregroundStyle(.umbralTinta.opacity(0.55))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(UDate.label(reto.fecha)).font(UType.label(9)).foregroundStyle(.umbralHumo)
                Text("\(dias) días").font(UType.card(14)).foregroundStyle(.umbralTeja)
            }
            Button { store.deleteReto(reto) } label: {
                Text("Borrar").font(.system(size: 12, weight: .medium)).foregroundStyle(.umbralTeja)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .overlay(DashedDivider(color: .umbralLineaLight), alignment: .bottom)
    }

    private var vacio: some View {
        VStack(spacing: 6) {
            Text("añade tu primer reto").font(.umbralSerif(18)).foregroundStyle(.umbralTeja)
            Text("Una carrera, una competición, una fecha límite — lo que te esté empujando ahora mismo.")
                .font(.system(size: 13)).foregroundStyle(.umbralHumo)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.umbralLineaLight))
    }
}

/// Formulario → papel/tinta invertido (regla 01), trasplante directo de
/// NuevoRecordSheet en RecordsView.swift.
private struct NuevoRetoSheet: View {
    @ObservedObject var store: UmbralStore
    @Environment(\.dismiss) private var dismiss
    @State private var nombre = ""
    @State private var fecha = UDate.today()
    @State private var disciplina: String?
    @State private var lugar = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hyrox Madrid, Maratón de Valencia…", text: $nombre)
                    DatePicker("Fecha", selection: Binding(
                        get: { UDate.date(fecha) },
                        set: { fecha = UDate.iso($0) }
                    ), displayedComponents: .date)
                    Picker("Disciplina", selection: $disciplina) {
                        Text("Sin especificar").tag(String?.none)
                        ForEach(DISC_LIST.filter { $0 != "Descanso" }, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    TextField("Lugar (opcional)", text: $lugar)
                }
                .listRowBackground(Color.umbralPapel)
            }
            .scrollContentBackground(.hidden)
            .background(PapelBackground())
            .tint(.umbralTeja)
            .navigationTitle("Nuevo reto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.umbralPapel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        guard !nombre.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.addReto(RetoItem(
                            nombre: nombre, fecha: fecha,
                            disciplina: disciplina,
                            lugar: lugar.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lugar
                        ))
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
