import Foundation

/// Versión mínima de planes.json — solo lo necesario para saber la sesión
/// de hoy fuera de la app viva (BackgroundSync, fallback del widget). No
/// reutiliza los modelos completos de la app (viven en su target, no en
/// Shared) — a propósito, para no acoplar el widget al store entero.
enum PlanFetcher {
    private struct RawEntry: Decodable { let titulo: String?; let disciplina: String?; let duracion_prevista: Int? }
    private struct RawPlan: Decodable { let semana: String; let dias: [String: RawEntry]? }

    struct TodayPlan { var titulo: String; var disciplina: String; var minutos: Int? }

    static func fetchTodayPlan(date: String) async -> TodayPlan? {
        guard let url = URL(string: "https://raw.githubusercontent.com/\(UMetrics.defaultRepo)/\(UMetrics.defaultBranch)/data/planes.json"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let plans = try? JSONDecoder().decode([RawPlan].self, from: data)
        else { return nil }

        let monday = mondayOf(date)
        guard let entry = plans.first(where: { $0.semana == monday })?.dias?[date],
              let titulo = entry.titulo, !titulo.isEmpty
        else { return nil }
        return TodayPlan(titulo: titulo, disciplina: entry.disciplina ?? "—", minutos: entry.duracion_prevista)
    }

    private static func mondayOf(_ iso: String) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.calendar = cal; f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: iso) else { return iso }
        let weekday = cal.component(.weekday, from: d)
        let sinceMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -sinceMonday, to: d) else { return iso }
        return f.string(from: monday)
    }
}
