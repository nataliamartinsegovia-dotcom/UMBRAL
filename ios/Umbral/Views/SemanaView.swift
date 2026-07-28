import SwiftUI

private let DIAS_LABEL = ["LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB", "DOM"]

struct SemanaView: View {
    @ObservedObject var store: UmbralStore
    @State private var semAct: String

    init(store: UmbralStore) {
        self.store = store
        _semAct = State(initialValue: UDate.mondayOf(store.today))
    }

    private var met: WeekMetrics { store.metrics(forWeek: semAct) }
    private var raceDays: Int { UDate.daysUntil(UMetrics.raceDateISO, from: store.today) }

    var body: some View {
        UmbralScreen(content: {
            LazyVStack(alignment: .leading, spacing: 22, pinnedViews: [.sectionHeaders]) {
                header
                analysisCard
                Section {
                    dayList
                } header: {
                    weekNav
                        .background(Color.umbralTinta)
                        .padding(.bottom, 4)
                }
            }
        }, trailing: AnyView(SyncChip(store: store)))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Plantilla y análisis").capLabel().foregroundStyle(.umbralHueso)
                Text("Semana").font(UType.section()).foregroundStyle(.umbralHueso)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Hyrox Madrid").capLabel().foregroundStyle(.umbralHueso)
                Text("\(raceDays) días").font(UType.card(16)).foregroundStyle(.umbralTeja)
            }
        }
    }

    private var weekNav: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Semana · \(UDate.label(semAct)) – \(UDate.label(UDate.add(semAct, 6)))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.umbralHueso)
            HStack(spacing: 8) {
                FilterChip(label: "◄ SEMANA") { semAct = UDate.add(semAct, -7) }
                FilterChip(label: "HOY") { semAct = UDate.mondayOf(store.today) }
                FilterChip(label: "SEMANA ►") { semAct = UDate.add(semAct, 7) }
            }
        }
        .padding(16)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Análisis de esta semana").capLabel().foregroundStyle(.umbralHueso)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                weekStat("Recuperación media", met.recMedia.map { "\($0)%" } ?? "—")
                weekStat("Adherencia", met.adherenciaTexto)
                weekStat("Tensión tejido", met.tension.map { String(format: "%.1f", $0) } ?? "—", warn: (met.tension ?? 0) > 1.3)
                weekStat("Volumen total", met.totalMin > 0 ? "\(met.totalMin) min" : "—")
            }
            DashedDivider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Foco de la semana").capLabel().foregroundStyle(.umbralHueso)
                TextField("Base aeróbica, técnica bajo fatiga…", text: store.focoBinding(monday: semAct))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.umbralHueso)
                    .padding(10)
                    .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
            }
            Text("Bloque: \(store.bloque(monday: semAct))")
                .font(UType.label(10))
                .foregroundStyle(.umbralHumo)
        }
        .padding(20)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    private func weekStat(_ label: String, _ value: String, warn: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(UType.label(9)).foregroundStyle(.umbralHumo)
            Text(value)
                .font(UType.data(24))
                .foregroundStyle(warn ? .umbralTeja : .umbralHueso)
        }
    }

    private var dayList: some View {
        VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let iso = UDate.add(semAct, offset)
                NavigationLink {
                    DayEditorView(store: store, monday: semAct, iso: iso, label: DIAS_LABEL[offset])
                } label: {
                    DayRow(store: store, iso: iso, label: DIAS_LABEL[offset])
                }
                .buttonStyle(.plain)
                if offset < 6 { DashedDivider(color: .umbralLineaDark.opacity(0.6)) }
            }
        }
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

}

private struct DayRow: View {
    @ObservedObject var store: UmbralStore
    let iso: String
    let label: String

    private var entry: DayPlanEntry { store.planEntry(for: iso) ?? DayPlanEntry() }
    private var day: DayRecord? { store.byDate[iso] }
    private var hecho: Bool { !(day?.workouts?.isEmpty ?? true) }
    private var futuro: Bool { iso > store.today }

    private var estado: (text: String, color: Color) {
        if futuro { return entry.titulo != nil ? ("PENDIENTE", .umbralHumo) : ("SIN PLAN", .umbralHumo.opacity(0.6)) }
        if hecho { return ("HECHA", .umbralHueso) }
        if entry.titulo != nil { return ("NO HECHA", .umbralTeja) }
        return ("—", .umbralHumo)
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(label) \(UDate.label(iso, day: true, month: false))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                if iso == store.today {
                    Text("HOY").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.umbralTeja)
                }
            }
            .foregroundStyle(.umbralHueso)
            .frame(width: 60, alignment: .leading)

            if let d = entry.disciplina {
                DisciplineIcon(name: d, color: .umbralHumo).frame(width: 16, height: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let t = entry.titulo, !t.isEmpty {
                    Text(t).font(UType.card(15)).foregroundStyle(.umbralHueso).lineLimit(1)
                    if let d = entry.disciplina {
                        Text(d.uppercased() + (entry.rpe.map { " · RPE \($0)" } ?? "")).font(UType.label(9)).foregroundStyle(.umbralHumo)
                    }
                } else {
                    Text("— sin planificar —").font(.system(size: 12, design: .monospaced)).italic().foregroundStyle(.umbralHumo.opacity(0.7))
                }
            }

            Spacer()

            if let rec = day?.recoveryScore {
                Text("\(Int(rec))%").font(UType.data(16)).foregroundStyle(.umbralHueso)
            }

            HStack(spacing: 5) {
                Circle().fill(estado.color).frame(width: 6, height: 6)
                Text(estado.text).font(UType.label(9)).foregroundStyle(estado.color)
            }

            CaretRight()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(iso == store.today ? Color.umbralTeja.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }
}
