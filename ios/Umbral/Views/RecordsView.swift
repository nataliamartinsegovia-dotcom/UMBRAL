import SwiftUI

struct RecordsView: View {
    @ObservedObject var store: UmbralStore
    @State private var mostrarNuevo = false
    @State private var confirmarBorrado: Int?

    var body: some View {
        UmbralScreen(content: {
            VStack(alignment: .leading, spacing: 18) {
                header
                if store.records.isEmpty {
                    vacio
                } else {
                    ForEach(Array(store.records.enumerated()), id: \.element.id) { i, _ in
                        RecordCard(store: store, index: i, onDelete: { confirmarBorrado = i })
                    }
                }
            }
        }, trailing: AnyView(SyncChip(store: store)))
        .sheet(isPresented: $mostrarNuevo) { NuevoRecordSheet(store: store) }
        .alert("¿Borrar este récord y su historial?", isPresented: Binding(
            get: { confirmarBorrado != nil }, set: { if !$0 { confirmarBorrado = nil } }
        )) {
            Button("Borrar", role: .destructive) {
                if let i = confirmarBorrado { store.records.remove(at: i); store.markDirty() }
                confirmarBorrado = nil
            }
            Button("Cancelar", role: .cancel) { confirmarBorrado = nil }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Marcas personales").capLabel().foregroundStyle(.umbralHueso)
                Text("Récords").font(UType.section()).foregroundStyle(.umbralHueso)
            }
            Spacer()
            PrimaryButton(title: "+ Nuevo récord") { mostrarNuevo = true }
        }
    }

    private var vacio: some View {
        VStack(spacing: 6) {
            Text("crea tu primer récord").font(.system(size: 20, design: .serif)).italic().foregroundStyle(.umbralTeja)
            Text("Puede ser tu mejor 5K, la carga máxima en peso muerto, la sesión más larga en Z2.")
                .font(.system(size: 13)).foregroundStyle(.umbralHumo)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.umbralLineaDark))
    }
}

private struct RecordCard: View {
    @ObservedObject var store: UmbralStore
    let index: Int
    var onDelete: () -> Void
    @State private var nuevoValor = ""
    @State private var nuevaFecha = UDate.today()

    private var record: RecordItem { store.records[index] }
    private var mejor: RecordEntry? {
        record.historial.sorted { record.tipo.menorMejor ? $0.valor < $1.valor : $0.valor > $1.valor }.first
    }
    private var cronologico: [RecordEntry] { record.historial.sorted { $0.fecha > $1.fecha } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(record.disciplina ?? "") · \(record.tipo.label)".uppercased())
                        .font(UType.label(9)).foregroundStyle(.umbralHumo)
                    Text(record.nombre ?? "—").font(UType.card(22)).foregroundStyle(.umbralHueso)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Mejor marca").font(UType.label(9)).foregroundStyle(.umbralHumo)
                    Text(mejor.map { record.tipo.format($0.valor) } ?? "—")
                        .font(UType.data(30)).foregroundStyle(.umbralTeja)
                }
            }

            if !cronologico.isEmpty {
                DashedDivider(color: .umbralLineaDark.opacity(0.6))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Historial · \(cronologico.count) intento\(cronologico.count == 1 ? "" : "s")")
                        .font(UType.label(9)).foregroundStyle(.umbralHumo)
                    ForEach(cronologico) { h in
                        HStack {
                            Text(UDate.label(h.fecha) + (h.nota.map { " · \($0)" } ?? ""))
                                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.umbralHumo)
                            Spacer()
                            Text(record.tipo.format(h.valor)).font(UType.card(13)).foregroundStyle(.umbralHueso)
                        }
                    }
                }
            }

            DashedDivider(color: .umbralLineaDark.opacity(0.6))
            HStack(spacing: 8) {
                TextField(record.tipo.label, text: $nuevoValor)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.umbralHueso)
                    .padding(9)
                    .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
                DatePicker("", selection: Binding(
                    get: { UDate.date(nuevaFecha) },
                    set: { nuevaFecha = UDate.iso($0) }
                ), displayedComponents: .date)
                .labelsHidden()
                .colorScheme(.dark)
            }
            HStack {
                GhostButton(title: "+ Añadir intento") { addAttempt() }
                Spacer()
                Button("Borrar", action: onDelete)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.umbralTeja)
            }
        }
        .padding(22)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    private func addAttempt() {
        guard let parsed = record.tipo.parse(nuevoValor) else { return }
        store.records[index].historial.append(RecordEntry(fecha: nuevaFecha, valor: parsed))
        store.markDirty()
        nuevoValor = ""
    }
}

/// Formulario → papel/tinta invertido, regla 01 del design system.
private struct NuevoRecordSheet: View {
    @ObservedObject var store: UmbralStore
    @Environment(\.dismiss) private var dismiss
    @State private var disciplina = DISC_LIST.first ?? "Crossfit"
    @State private var nombre = ""
    @State private var tipo: RecordTipo = .tiempo

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Disciplina", selection: $disciplina) {
                        ForEach(DISC_LIST.filter { $0 != "Descanso" }, id: \.self) { Text($0) }
                    }
                    TextField("5k, Fran, sentadilla…", text: $nombre)
                    Picker("Tipo", selection: $tipo) {
                        ForEach(RecordTipo.allCases) { Text($0.label).tag($0) }
                    }
                }
                .listRowBackground(Color.umbralPapel)
            }
            .scrollContentBackground(.hidden)
            .background(PapelBackground())
            .tint(.umbralTeja)
            .navigationTitle("Nuevo récord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.umbralPapel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        guard !nombre.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.records.append(RecordItem(disciplina: disciplina, nombre: nombre, tipo: tipo))
                        store.markDirty()
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
