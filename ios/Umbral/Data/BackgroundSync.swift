import Foundation
import BackgroundTasks
import WidgetKit

/// Sync oportunista en segundo plano. iOS decide el momento real de
/// ejecución dentro de su propio presupuesto — esto NO es "al segundo que
/// WHOOP sube un dato" (eso necesitaría un webhook con servidor público,
/// que un iPhone no puede recibir). Es lo máximo que cabe dentro de la app:
/// pedirle a iOS que, cuando le convenga cerca de la hora preferida, nos
/// deje despertar un momento y traer datos frescos de WHOOP.
///
/// Standalone a propósito — no depende de que UmbralStore esté vivo, porque
/// esto puede ejecutarse con la app totalmente suspendida.
enum BackgroundSync {
    static let taskId = "com.umbral.app.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            handle(refreshTask)
        }
    }

    static func reschedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = nextRun()
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func nextRun() -> Date {
        let hour = UserDefaults.standard.object(forKey: "umbral.autoSyncHour") as? Int ?? 8
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = 0
        let candidate = cal.date(from: comps) ?? Date().addingTimeInterval(3600)
        return candidate > Date() ? candidate : (cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86400))
    }

    private static func handle(_ task: BGAppRefreshTask) {
        reschedule() // deja programado el siguiente antes de nada

        let work = Task {
            let ok = await refreshOnce()
            task.setTaskCompleted(success: ok)
        }
        task.expirationHandler = { work.cancel() }
    }

    private static func refreshOnce() async -> Bool {
        guard let clientId = KeychainHelper.get("whoop.clientId"), !clientId.isEmpty,
              let clientSecret = KeychainHelper.get("whoop.clientSecret"), !clientSecret.isEmpty,
              let tokensJSON = KeychainHelper.get("whoop.tokens"),
              let data = tokensJSON.data(using: .utf8),
              var tokens = try? JSONDecoder().decode(WhoopTokens.self, from: data)
        else { return false }

        do {
            if tokens.expiresAt <= Date().addingTimeInterval(60) {
                tokens = try await WhoopAuth.refresh(refreshToken: tokens.refreshToken, clientId: clientId, clientSecret: clientSecret)
                if let newData = try? JSONEncoder().encode(tokens), let s = String(data: newData, encoding: .utf8) {
                    KeychainHelper.set(s, key: "whoop.tokens")
                }
            }
            let days = try await WhoopAPIService.fetchRecentDays(token: tokens.accessToken, daysBack: 2)
            guard let today = days.first(where: { $0.date == UDate.today() }) ?? days.sorted(by: { $0.date > $1.date }).first else {
                return true
            }
            let plan = await PlanFetcher.fetchTodayPlan(date: today.date)
            let workoutMinutes = today.workouts?.reduce(0) { $0 + ($1.durationMin ?? 0) } ?? 0
            WidgetShared.write(WidgetSnapshot(
                date: today.date, recoveryScore: today.recoveryScore, hrv: today.hrvRmssdMilli,
                sleepPerformance: today.sleepPerformancePercentage, threshold: UMetrics.threshold,
                isLive: true, updatedAt: Date(),
                sessionTitle: plan?.titulo ?? today.workouts?.first?.sportName,
                sessionDiscipline: plan?.disciplina,
                sessionMinutes: plan?.minutos ?? (workoutMinutes > 0 ? workoutMinutes : nil)
            ))
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            return false
        }
    }
}
