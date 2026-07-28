import Foundation

/// Foto de "hoy" que la app principal deja en el App Group para que el
/// widget la lea sin tener que reautenticar WHOOP ni GitHub por su cuenta.
struct WidgetSnapshot: Codable {
    var date: String
    var recoveryScore: Double?
    var hrv: Double?
    var sleepPerformance: Double?
    var threshold: Double
    var isLive: Bool
    var updatedAt: Date
    /// Sesión de hoy (planificada o ya hecha vía Whoop) — para el widget
    /// mediano, que la muestra a la derecha.
    var sessionTitle: String?
    var sessionDiscipline: String?
    var sessionMinutes: Int?
}

enum WidgetShared {
    static let appGroupId = "group.com.umbral.app"
    private static let snapshotKey = "umbral.todaySnapshot"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    static func read() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
