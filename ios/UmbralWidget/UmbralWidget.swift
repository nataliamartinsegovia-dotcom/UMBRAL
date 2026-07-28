import WidgetKit
import SwiftUI

// Widget de pantalla de inicio: recuperación de hoy vs umbral. Lee la foto
// que deja la app en el App Group (rápido, sin red); si está vencida o no
// existe, cae a leer directamente el data/index.json + data/planes.json
// públicos del repo — el mismo dato que ya deja el cron diario de GitHub
// Actions.

private struct RawDay: Decodable {
    let date: String
    let recovery_score: Double?
    let hrv_rmssd_milli: Double?
    let sleep_performance_percentage: Double?
}

struct UmbralEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UmbralEntry {
        UmbralEntry(date: Date(), snapshot: WidgetSnapshot(
            date: "", recoveryScore: 66, hrv: 66, sleepPerformance: 70,
            threshold: UMetrics.threshold, isLive: false, updatedAt: Date(),
            sessionTitle: "Series Z3", sessionDiscipline: "Crossfit", sessionMinutes: 45
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (UmbralEntry) -> Void) {
        completion(UmbralEntry(date: Date(), snapshot: WidgetShared.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UmbralEntry>) -> Void) {
        Task {
            var snap = WidgetShared.read()
            let staleAfter: TimeInterval = 6 * 3600
            if snap == nil || Date().timeIntervalSince(snap!.updatedAt) > staleAfter {
                if let fetched = await fetchFallback() { snap = fetched }
            }
            let entry = UmbralEntry(date: Date(), snapshot: snap)
            let next = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date().addingTimeInterval(7200)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchFallback() async -> WidgetSnapshot? {
        let path = "https://raw.githubusercontent.com/\(UMetrics.defaultRepo)/\(UMetrics.defaultBranch)/data/index.json"
        guard let url = URL(string: path),
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let days = try? JSONDecoder().decode([RawDay].self, from: data),
              let latest = days.sorted(by: { $0.date > $1.date }).first
        else { return nil }
        let plan = await PlanFetcher.fetchTodayPlan(date: latest.date)
        return WidgetSnapshot(
            date: latest.date, recoveryScore: latest.recovery_score, hrv: latest.hrv_rmssd_milli,
            sleepPerformance: latest.sleep_performance_percentage, threshold: UMetrics.threshold,
            isLive: false, updatedAt: Date(),
            sessionTitle: plan?.titulo, sessionDiscipline: plan?.disciplina, sessionMinutes: plan?.minutos
        )
    }
}

struct UmbralWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UmbralEntry

    private var recovery: Double? { entry.snapshot?.recoveryScore }
    private var threshold: Double { entry.snapshot?.threshold ?? UMetrics.threshold }
    private var sobre: Bool { (recovery ?? -1) >= threshold }

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(alignment: .top, spacing: 0) {
                    recoveryColumn.frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(Color.umbralLineaDark).frame(width: 1).padding(.vertical, 2)
                    sessionColumn.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 16)
                }
                .padding(16)
            } else {
                recoveryColumn.padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color.umbralTinta, for: .widget)
    }

    private var recoveryColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(Color.umbralTeja).frame(width: 6, height: 6)
                Text(entry.snapshot?.isLive == true ? "EN VIVO" : "WHOOP")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
            }
            .foregroundStyle(.umbralHumo)

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(recovery.map { "\(Int($0))" } ?? "—")
                    .font(.system(size: family == .systemSmall ? 40 : 44, weight: .semibold))
                    .foregroundStyle(.umbralHueso)
                if recovery != nil {
                    Text("%").font(.system(size: 14)).foregroundStyle(.umbralHumo)
                }
            }

            Text(recovery == nil ? "SIN LECTURA" : (sobre ? "SOBRE UMBRAL · \(Int(threshold))%" : "BAJO UMBRAL · \(Int(threshold))%"))
                .font(.system(size: 9, weight: .medium))
                .tracking(0.6)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .foregroundStyle(recovery == nil ? .umbralHumo : (sobre ? .umbralTinta : .white))
                .background(recovery == nil ? Color.umbralLineaDark.opacity(0.4) : (sobre ? Color.umbralHueso : Color.umbralTeja))
        }
    }

    /// Solo en el widget mediano/horizontal: la sesión de hoy, a la derecha.
    private var sessionColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.snapshot?.sessionTitle, !title.isEmpty {
                Text((entry.snapshot?.sessionDiscipline ?? "SESIÓN").uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(.umbralHumo)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.umbralHueso)
                    .lineLimit(2)
                Spacer(minLength: 2)
                if let min = entry.snapshot?.sessionMinutes, min > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(min)").font(.system(size: 22, weight: .semibold)).foregroundStyle(.umbralHueso)
                        Text("MIN").font(.system(size: 9, weight: .medium)).foregroundStyle(.umbralHumo)
                    }
                }
            } else {
                Text("SESIÓN DE HOY").font(.system(size: 9, weight: .medium)).tracking(0.6).foregroundStyle(.umbralHumo)
                Spacer(minLength: 2)
                Text("Sin planificar").font(.system(size: 14, weight: .medium)).italic().foregroundStyle(.umbralHumo)
            }
        }
    }
}

struct UmbralWidget: Widget {
    let kind = "UmbralWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            UmbralWidgetView(entry: entry)
        }
        .configurationDisplayName("Umbral")
        .description("Recuperación de hoy vs umbral fisiológico y la sesión del día.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct UmbralWidgetBundle: WidgetBundle {
    var body: some Widget {
        UmbralWidget()
    }
}
