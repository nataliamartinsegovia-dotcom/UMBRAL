import SwiftUI
import Charts

struct HoyView: View {
    @ObservedObject var store: UmbralStore

    private var day: DayRecord? { store.byDate[store.today] }
    private var session: SessionEntry? { store.session(for: store.today) }

    private var thresholdState: ThresholdState {
        guard let rec = day?.recoveryScore else { return .sinDato }
        return rec >= store.threshold ? .sobre : .bajo
    }

    private var last30: [(iso: String, value: Double?)] {
        store.dias.prefix(30).reversed().map { ($0.date, $0.recoveryScore) }
    }

    var body: some View {
        UmbralScreen(onRefresh: { await store.refreshAll() }, content: {
            VStack(alignment: .leading, spacing: 26) {
                header
                metricsGrid
                chartCard
                sessionCard
            }
        }, trailing: AnyView(SyncChip(store: store)))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(UDate.label(store.today, weekday: true).uppercased())
                    .capLabel()
                    .foregroundStyle(.umbralHueso)
                Text("Estado de hoy")
                    .font(UType.section())
                    .foregroundStyle(.umbralHueso)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Techo fisiológico").capLabel().foregroundStyle(.umbralHueso)
                Text(thresholdState == .sobre ? "Sobre umbral · \(Int(store.threshold))%" : "Bajo umbral · \(Int(store.threshold))%")
                    .font(UType.card(16))
                    .foregroundStyle(.umbralTeja)
            }
        }
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 6) {
                UmbralSquiggleIcon().umbralIconStyle(.umbralHueso, lineWidth: 1.25).frame(width: 14, height: 14)
                Text("Recuperación · Whoop").capLabel().foregroundStyle(.umbralHueso)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(day?.recoveryScore.map { "\(Int($0))" } ?? "—")
                    .font(UType.data(64))
                    .foregroundStyle(.umbralHueso)
                if day?.recoveryScore != nil {
                    Text("%").font(UType.label(20)).foregroundStyle(.umbralHumo)
                }
            }
            ThresholdBadge(state: thresholdState, recovery: day?.recoveryScore)
            if day?.recoveryScore != nil {
                Text(thresholdState == .sobre ? "buen día · aprieta con cabeza" : "hoy toca calma · zona máx 3")
                    .font(.umbralSerif(17))
                    .foregroundStyle(.umbralTeja)
            }

            DashedDivider().padding(.vertical, 4)

            VStack(spacing: 14) {
                MetricCell(label: "VFC", value: day?.hrvRmssdMilli.map { "\(Int($0))" } ?? "—", unit: "ms", icon: AnyShape(UmbralVfcIcon()))
                MetricCell(label: "Sueño", value: day?.sleepPerformancePercentage.map { "\(Int($0))" } ?? "—", unit: "%", icon: AnyShape(UmbralMoonIcon()))
                MetricCell(label: "Carga día", value: day?.dayStrain.map { String(format: "%.1f", $0) } ?? "—", icon: AnyShape(UmbralSessionIcon()))
                MetricCell(label: "FC reposo", value: day?.restingHeartRate.map { "\(Int($0))" } ?? "—", unit: "bpm")
            }
        }
        .padding(24)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recuperación vs umbral · 30 días").capLabel().foregroundStyle(.umbralHueso)
                Spacer()
                Text("Puntos teja = sobre umbral").font(UType.label(9)).foregroundStyle(.umbralHumo)
            }
            Chart {
                ForEach(Array(last30.enumerated()), id: \.offset) { _, point in
                    if let v = point.value {
                        LineMark(x: .value("día", point.iso), y: .value("recuperación", v))
                            .foregroundStyle(Color.umbralHueso)
                            .interpolationMethod(.linear)
                        if v >= store.threshold {
                            PointMark(x: .value("día", point.iso), y: .value("recuperación", v))
                                .foregroundStyle(Color.umbralTeja)
                                .symbolSize(28)
                        }
                    }
                }
                RuleMark(y: .value("umbral", store.threshold))
                    .foregroundStyle(Color.umbralHueso.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("UMBRAL \(Int(store.threshold))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.umbralHueso)
                    }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 140)
        }
        .padding(22)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    @ViewBuilder
    private var sessionCard: some View {
        if let s = session {
            NavigationLink {
                DayEditorView(store: store, monday: UDate.mondayOf(store.today), iso: store.today, label: "HOY")
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sesión de hoy · \(s.disciplina)").capLabel().foregroundStyle(.umbralHueso)
                        Text(s.titulo).font(UType.card()).foregroundStyle(.umbralHueso)
                        if !s.desc.isEmpty {
                            Text(s.desc).font(UType.body(13)).foregroundStyle(.umbralHumo)
                        }
                    }
                    Spacer()
                    if s.minutos > 0 {
                        (Text("\(s.minutos)").font(UType.data(36)) + Text(" MIN").font(UType.label(10)).foregroundStyle(.umbralHumo))
                            .foregroundStyle(.umbralHueso)
                    }
                }
                .padding(24)
                .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                DayEditorView(store: store, monday: UDate.mondayOf(store.today), iso: store.today, label: "HOY")
            } label: {
                VStack(spacing: 6) {
                    Text("Sin sesión planificada para hoy").capLabel().foregroundStyle(.umbralHueso)
                    Text("Toca para planificar el día")
                        .font(UType.card(16))
                        .foregroundStyle(.umbralHueso)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.umbralLineaDark))
            }
            .buttonStyle(.plain)
        }
    }
}
