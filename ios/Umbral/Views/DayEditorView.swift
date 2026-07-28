import SwiftUI

/// Editor de un día — detalle + formulario, regla 01 del design system:
/// invierte a papel/tinta mientras el resto de la app se queda en tinta.
struct DayEditorView: View {
    @ObservedObject var store: UmbralStore
    let monday: String
    let iso: String
    let label: String

    private var entryBinding: Binding<DayPlanEntry> { store.dayEntryBinding(monday: monday, iso: iso) }
    private var day: DayRecord? { store.byDate[iso] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(label) · \(UDate.label(iso))".uppercased()).capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text(entryBinding.wrappedValue.titulo?.isEmpty == false ? entryBinding.wrappedValue.titulo! : "Sesión sin título")
                        .font(UType.section(24))
                        .foregroundStyle(.umbralTinta)
                }

                field("Título de la sesión") {
                    TextField("Series Z3, sled push técnico…", text: Binding(
                        get: { entryBinding.wrappedValue.titulo ?? "" },
                        set: { entryBinding.wrappedValue.titulo = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Disciplina").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(DISC_LIST, id: \.self) { d in
                            DisciplineBox(name: d, selected: entryBinding.wrappedValue.disciplina == d) {
                                entryBinding.wrappedValue.disciplina = d
                            }
                        }
                    }
                }

                sliderRow("Zona objetivo", value: Binding(
                    get: { Double(entryBinding.wrappedValue.zonaObjetivo ?? 3) },
                    set: { entryBinding.wrappedValue.zonaObjetivo = Int($0) }
                ), range: 1...6, format: { "\(Int($0))" })

                sliderRow("RPE", value: Binding(
                    get: { Double(entryBinding.wrappedValue.rpe ?? 7) },
                    set: { entryBinding.wrappedValue.rpe = Int($0) }
                ), range: 1...10, format: { "\(Int($0))" })

                sliderRow("Duración", value: Binding(
                    get: { Double(entryBinding.wrappedValue.duracionPrevista ?? 45) },
                    set: { entryBinding.wrappedValue.duracionPrevista = Int($0) }
                ), range: 10...120, step: 5, format: { "\(Int($0)) min" })

                field("Descripción") {
                    TextField("Calentar 10' · 4×8' Z3 con 2' recuperación", text: Binding(
                        get: { entryBinding.wrappedValue.descripcion ?? "" },
                        set: { entryBinding.wrappedValue.descripcion = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                }

                field("Resultado") {
                    TextField("21:04, 100kg, 7,5 rondas", text: Binding(
                        get: { entryBinding.wrappedValue.resultado ?? "" },
                        set: { entryBinding.wrappedValue.resultado = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                }

                field("Sensaciones") {
                    TextField("Piernas pesadas desde el warm-up", text: Binding(
                        get: { entryBinding.wrappedValue.sensaciones ?? "" },
                        set: { entryBinding.wrappedValue.sensaciones = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.plain)
                }

                whoopPanel
                autosaveStatus
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .preferredColorScheme(.light)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
            content()
                .font(.system(size: 14))
                .foregroundStyle(.umbralTinta)
                .padding(10)
                .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1, format: (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                Spacer()
                Text(format(value.wrappedValue)).font(UType.card(14)).foregroundStyle(.umbralTinta)
            }
            Slider(value: value, in: range, step: step)
                .tint(.umbralTeja)
        }
    }

    private var whoopPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                UmbralSquiggleIcon().umbralIconStyle(.umbralTinta, lineWidth: 1.25).frame(width: 13, height: 13)
                Text("Datos Whoop de \(UDate.label(iso))").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
            }
            VStack(spacing: 0) {
                specRow("Recuperación", day?.recoveryScore.map { "\(Int($0)) %" })
                specRow("VFC (RMSSD)", day?.hrvRmssdMilli.map { "\(Int($0)) ms" })
                specRow("FC reposo", day?.restingHeartRate.map { "\(Int($0)) bpm" })
                specRow("Rendimiento sueño", day?.sleepPerformancePercentage.map { "\(Int($0)) %" })
                specRow("Carga del día", day?.dayStrain.map { String(format: "%.1f", $0) })
                if let ws = day?.workouts, !ws.isEmpty {
                    ForEach(Array(ws.enumerated()), id: \.offset) { i, w in
                        specRow("Whoop · Actividad \(i + 1)", (w.sportName ?? "—").replacingOccurrences(of: "-", with: " "))
                        specRow("Duración", w.durationMin.map { "\($0) min" })
                        specRow("FC media", w.averageHeartRate.map { "\($0) bpm" })
                    }
                } else {
                    Text("Sin actividad registrada por Whoop este día")
                        .font(.system(size: 12)).foregroundStyle(.umbralHumo)
                        .padding(.vertical, 10)
                }
            }
        }
        .padding(16)
        .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))
    }

    private func specRow(_ label: String, _ value: String?) -> some View {
        HStack {
            Text(label).font(UType.label(9)).foregroundStyle(.umbralHumo)
            Spacer()
            Text(value ?? "—").font(UType.card(13)).foregroundStyle(.umbralTinta)
        }
        .padding(.vertical, 8)
        .overlay(DashedDivider(color: .umbralLineaLight), alignment: .bottom)
    }

    @ViewBuilder
    private var autosaveStatus: some View {
        if store.dirty || store.saving {
            Text(store.saving ? "GUARDANDO…" : "SIN GUARDAR — SE GUARDA SOLO")
                .font(UType.label(9))
                .foregroundStyle(.umbralHumo)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// Caja de disciplina — icono real + label, tamaño y forma idénticos para
/// las 7, en vez de chips que se ensanchan según el texto ("Gimnásticos"
/// no puede verse distinto a "Fuerza"). Versión papel: tinta invertida.
private struct DisciplineBox: View {
    let name: String
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                DisciplineIcon(name: name, color: selected ? .umbralPapel : .umbralTinta, lineWidth: 1.4)
                    .frame(width: 20, height: 20)
                Text(name)
                    .font(UType.label(10))
                    .tracking(0.6)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selected ? Color.umbralPapel : .umbralTinta)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(selected ? Color.umbralTinta : Color.clear)
            .overlay(Rectangle().stroke(selected ? Color.umbralTinta : Color.umbralLineaLight, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
