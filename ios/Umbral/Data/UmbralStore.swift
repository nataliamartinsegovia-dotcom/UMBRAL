import Foundation
import SwiftUI
import WidgetKit

// MARK: - Fechas ISO en UTC, igual que index.html

enum UDate {
    static var utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = utcCalendar
        f.timeZone = utcCalendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func date(_ iso: String) -> Date {
        formatter.date(from: iso) ?? Date(timeIntervalSince1970: 0)
    }

    static func iso(_ date: Date) -> String { formatter.string(from: date) }

    static func today() -> String { iso(Date()) }

    static func add(_ iso: String, _ days: Int) -> String {
        let d = date(iso)
        guard let next = utcCalendar.date(byAdding: .day, value: days, to: d) else { return iso }
        return self.iso(next)
    }

    static func mondayOf(_ iso: String) -> String {
        let d = date(iso)
        let weekday = utcCalendar.component(.weekday, from: d) // domingo=1 ... sábado=7
        let sinceMonday = (weekday + 5) % 7
        return add(iso, -sinceMonday)
    }

    static func label(_ iso: String, day: Bool = true, month: Bool = true, weekday: Bool = false) -> String {
        let d = date(iso)
        let f = DateFormatter()
        f.calendar = utcCalendar
        f.timeZone = utcCalendar.timeZone
        f.locale = Locale(identifier: "es_ES")
        var parts: [String] = []
        if weekday { parts.append("EEEE") }
        if day { parts.append("d") }
        if month { parts.append("MMM") }
        f.setLocalizedDateFormatFromTemplate(parts.joined())
        return f.string(from: d)
    }

    static func daysUntil(_ iso: String, from today: String) -> Int {
        max(0, utcCalendar.dateComponents([.day], from: date(today), to: date(iso)).day ?? 0)
    }
}

struct WeekMetrics {
    var recMedia: Int?
    var adherenciaTexto: String
    var adherenciaPct: Int?
    var tension: Double?
    var totalMin: Int
}

@MainActor
final class UmbralStore: ObservableObject {
    @Published var dias: [DayRecord] = []
    @Published var planes: [PlanSemana] = []
    @Published var records: [RecordItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var dirty = false
    @Published private(set) var saving = false
    private var autosaveTask: Task<Void, Never>?
    @Published var lastSyncLabel = "—"
    @Published var showUserPanel = false
    @Published var autoSyncHour: Int {
        didSet {
            UserDefaults.standard.set(autoSyncHour, forKey: "umbral.autoSyncHour")
            BackgroundSync.reschedule()
        }
    }

    @Published var repo: String {
        didSet { KeychainHelper.set(repo, key: "umbral.repo") }
    }
    @Published var token: String {
        didSet { KeychainHelper.set(token, key: "umbral.token") }
    }

    // MARK: - WHOOP (grant OAuth propio de la app, ver WhoopService.swift)

    @Published var whoopClientId: String {
        didSet { KeychainHelper.set(whoopClientId, key: "whoop.clientId") }
    }
    @Published var whoopClientSecret: String {
        didSet { KeychainHelper.set(whoopClientSecret, key: "whoop.clientSecret") }
    }
    @Published var whoopConnected = false
    @Published var whoopSyncing = false
    @Published var whoopLiveDate: String?
    private var whoopTokens: WhoopTokens? {
        didSet {
            whoopConnected = whoopTokens != nil
            guard let whoopTokens, let data = try? JSONEncoder().encode(whoopTokens),
                  let s = String(data: data, encoding: .utf8) else {
                if whoopTokens == nil { KeychainHelper.set(nil, key: "whoop.tokens") }
                return
            }
            KeychainHelper.set(s, key: "whoop.tokens")
        }
    }
    private var whoopRefreshTask: Task<String, Error>?

    let today = UDate.today()
    let threshold = UMetrics.threshold

    init() {
        let savedHour = UserDefaults.standard.object(forKey: "umbral.autoSyncHour") as? Int
        autoSyncHour = savedHour ?? 8
        repo = KeychainHelper.get("umbral.repo") ?? UMetrics.defaultRepo
        token = KeychainHelper.get("umbral.token") ?? ""
        whoopClientId = KeychainHelper.get("whoop.clientId") ?? ""
        whoopClientSecret = KeychainHelper.get("whoop.clientSecret") ?? ""
        if let s = KeychainHelper.get("whoop.tokens"), let data = s.data(using: .utf8),
           let t = try? JSONDecoder().decode(WhoopTokens.self, from: data) {
            whoopTokens = t
            whoopConnected = true
        }
    }

    func whoopAuthorizeURL(state: String) -> URL? {
        WhoopAuth.authorizeURL(clientId: whoopClientId, state: state)
    }

    func whoopExchangeCode(_ code: String) async throws {
        whoopTokens = try await WhoopAuth.exchangeCode(code, clientId: whoopClientId, clientSecret: whoopClientSecret)
    }

    func whoopDisconnect() {
        whoopTokens = nil
        whoopLiveDate = nil
    }

    /// Devuelve un access_token válido, refrescando si hace falta.
    /// Single-flight: si ya hay un refresco en vuelo, todo el mundo espera el mismo resultado
    /// en vez de disparar refrescos duplicados (WHOOP invalida el refresh token en cada uso).
    private func whoopValidAccessToken() async throws -> String {
        guard let whoopTokens else { throw WhoopError.noAccessToken }
        if whoopTokens.expiresAt > Date().addingTimeInterval(60) { return whoopTokens.accessToken }
        if let whoopRefreshTask { return try await whoopRefreshTask.value }
        let task = Task<String, Error> { [weak self] in
            guard let self else { throw WhoopError.noAccessToken }
            let fresh = try await WhoopAuth.refresh(refreshToken: whoopTokens.refreshToken, clientId: self.whoopClientId, clientSecret: self.whoopClientSecret)
            self.whoopTokens = fresh
            return fresh.accessToken
        }
        whoopRefreshTask = task
        defer { whoopRefreshTask = nil }
        return try await task.value
    }

    /// Lee recuperación/sueño/carga/entrenos recientes directo de WHOOP y los
    /// fusiona sobre `dias`, sin esperar al cron diario de GitHub Actions.
    func refreshLiveWhoop() async {
        guard whoopConnected else { return }
        whoopSyncing = true
        defer { whoopSyncing = false }
        do {
            let accessToken = try await whoopValidAccessToken()
            let liveDays = try await WhoopAPIService.fetchRecentDays(token: accessToken)
            var byDateLocal = byDate
            for live in liveDays {
                byDateLocal[live.date] = (byDateLocal[live.date] ?? DayRecord(date: live.date)).mergingLiveWhoop(live)
            }
            dias = byDateLocal.values.sorted { $0.date > $1.date }
            whoopLiveDate = liveDays.map(\.date).max()
            publishWidgetSnapshot()
        } catch {
            errorMessage = "WHOOP: \(error.localizedDescription)"
        }
    }

    /// Deja una foto de "hoy" en el App Group para que el widget la lea sin
    /// tener que hablar con WHOOP/GitHub por su cuenta, y le pide refrescar.
    private func publishWidgetSnapshot() {
        guard let day = byDate[today] else { return }
        let s = session(for: today)
        WidgetShared.write(WidgetSnapshot(
            date: today, recoveryScore: day.recoveryScore, hrv: day.hrvRmssdMilli,
            sleepPerformance: day.sleepPerformancePercentage, threshold: threshold,
            isLive: whoopConnected, updatedAt: Date(),
            sessionTitle: s?.titulo, sessionDiscipline: s?.disciplina, sessionMinutes: s.map(\.minutos)
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private var service: GitHubService { GitHubService(repo: repo) }

    var byDate: [String: DayRecord] {
        Dictionary(dias.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var hasToken: Bool { !token.isEmpty }

    // MARK: - Carga

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let diasR: [DayRecord]? = service.fetchJSON("data/index.json", as: [DayRecord].self)
        async let planesR: [PlanSemana]? = service.fetchJSON("data/planes.json", as: [PlanSemana].self)
        async let recordsR: [RecordItem]? = service.fetchJSON("data/records.json", as: [RecordItem].self)

        var loadedDias = (await diasR) ?? []
        let loadedPlanes = (await planesR) ?? []
        let loadedRecords = (await recordsR) ?? []

        if loadedDias.isEmpty {
            if let manifest = await service.fetchJSON("data/manifest.json", as: [String].self) {
                let results = await withTaskGroup(of: DayRecord?.self) { group -> [DayRecord] in
                    for d in manifest {
                        group.addTask { await self.service.fetchJSON("data/\(d).json", as: DayRecord.self) }
                    }
                    var out: [DayRecord] = []
                    for await r in group { if let r { out.append(r) } }
                    return out
                }
                loadedDias = results
            }
        }

        dias = loadedDias.sorted { $0.date > $1.date }
        planes = loadedPlanes
        records = loadedRecords
        dirty = false

        if let latest = dias.first {
            lastSyncLabel = UDate.label(latest.date)
        }
        publishWidgetSnapshot()
    }

    // MARK: - Sesiones derivadas (Hoy / Semana / Registro)

    func discipline(for w: WorkoutEntry?) -> String {
        guard let s = w?.sportName?.lowercased() else { return "—" }
        if s.contains("running") { return "Carrera" }
        if s.contains("walking") || s.contains("hiking") { return "Caminar" }
        if s.contains("weightlifting") || s.contains("strength") { return "Fuerza" }
        if s.contains("functional") { return "Crossfit" }
        if s.contains("hiit") { return "Hyrox" }
        if s.contains("yoga") || s.contains("pilates") { return "Movilidad" }
        if s.contains("cycling") || s.contains("bik") { return "Bici" }
        if s.contains("rowing") { return "Remo" }
        return w?.sportName ?? "—"
    }

    var sessions: [SessionEntry] {
        let byDateLocal = byDate
        var fechas = Set<String>()
        for plan in planes {
            for (iso, entry) in plan.dias where entry.titulo != nil { fechas.insert(iso) }
        }
        for d in dias where !(d.workouts ?? []).isEmpty { fechas.insert(d.date) }

        return fechas.map { iso -> SessionEntry in
            let entry = planEntry(for: iso)
            let day = byDateLocal[iso]
            let ws = day?.workouts ?? []
            var cats: [String] = []
            if let z = entry?.zonaObjetivo { cats.append("Z\(z)") }
            if let r = entry?.rpe { cats.append("RPE \(r)") }
            let minutos = ws.reduce(0) { $0 + ($1.durationMin ?? 0) } != 0
                ? ws.reduce(0) { $0 + ($1.durationMin ?? 0) }
                : (entry?.duracionPrevista ?? 0)
            if minutos > 0 { cats.append("\(minutos) min") }

            let titulo = entry?.titulo ?? (ws.compactMap { $0.sportName }.isEmpty ? "Sesión Whoop" : ws.compactMap { $0.sportName }.joined(separator: " + "))
            let disc = entry?.disciplina ?? discipline(for: ws.first)

            return SessionEntry(
                fecha: iso, titulo: titulo, disciplina: disc, cats: cats,
                desc: entry?.descripcion ?? "", resultado: entry?.resultado ?? "",
                sensaciones: entry?.sensaciones ?? "", rpe: entry?.rpe, zonaObjetivo: entry?.zonaObjetivo,
                rec: day?.recoveryScore, hrv: day?.hrvRmssdMilli, strain: day?.dayStrain, sueno: day?.sleepPerformancePercentage,
                workouts: ws, hecho: !ws.isEmpty, planificado: entry?.titulo != nil, minutos: minutos
            )
        }.sorted { $0.fecha > $1.fecha }
    }

    func planEntry(for iso: String) -> DayPlanEntry? {
        let monday = UDate.mondayOf(iso)
        return planes.first { $0.semana == monday }?.dias[iso]
    }

    func session(for iso: String) -> SessionEntry? {
        sessions.first { $0.fecha == iso }
    }

    // MARK: - Semana (lectura + edición)

    func weekPlanIndex(_ monday: String) -> Int {
        if let idx = planes.firstIndex(where: { $0.semana == monday }) { return idx }
        var plan = PlanSemana(semana: monday)
        for i in 0..<7 { plan.dias[UDate.add(monday, i)] = DayPlanEntry() }
        planes.append(plan)
        planes.sort { $0.semana > $1.semana }
        return planes.firstIndex(where: { $0.semana == monday })!
    }

    func dayEntryBinding(monday: String, iso: String) -> Binding<DayPlanEntry> {
        Binding(
            get: {
                let idx = self.weekPlanIndex(monday)
                return self.planes[idx].dias[iso] ?? DayPlanEntry()
            },
            set: { newValue in
                let idx = self.weekPlanIndex(monday)
                self.planes[idx].dias[iso] = newValue
                self.markDirty()
            }
        )
    }

    func focoBinding(monday: String) -> Binding<String> {
        Binding(
            get: { self.planes[self.weekPlanIndex(monday)].foco ?? "" },
            set: { newValue in
                let idx = self.weekPlanIndex(monday)
                self.planes[idx].foco = newValue.isEmpty ? nil : newValue
                self.markDirty()
            }
        )
    }

    func bloque(monday: String) -> String {
        planes.first { $0.semana == monday }?.bloque ?? "—"
    }

    func range(_ from: String, _ to: String) -> [DayRecord?] {
        var out: [DayRecord?] = []
        var c = from
        var guardIters = 0
        while c <= to && guardIters < 400 {
            out.append(byDate[c])
            c = UDate.add(c, 1)
            guardIters += 1
        }
        return out
    }

    func tension(at iso: String) -> Double? {
        let ag = range(UDate.add(iso, -6), iso).compactMap { $0?.dayStrain }
        let cr = range(UDate.add(iso, -27), iso).compactMap { $0?.dayStrain }
        guard !ag.isEmpty, !cr.isEmpty else { return nil }
        let mA = ag.reduce(0, +) / Double(ag.count)
        let mC = cr.reduce(0, +) / Double(cr.count)
        guard mC != 0 else { return nil }
        return mA / mC
    }

    func metrics(forWeek monday: String) -> WeekMetrics {
        let diasSemana = range(monday, UDate.add(monday, 6))
        let conRec = diasSemana.compactMap { $0?.recoveryScore }
        let recMedia = conRec.isEmpty ? nil : Int((conRec.reduce(0, +) / Double(conRec.count)).rounded())

        let plan = planes.first { $0.semana == monday }
        var planCount = 0, hechoCount = 0
        for offset in 0..<7 {
            let iso = UDate.add(monday, offset)
            guard let e = plan?.dias[iso], let t = e.titulo, !t.isEmpty, e.disciplina != "Descanso" else { continue }
            planCount += 1
            if !(byDate[iso]?.workouts ?? []).isEmpty { hechoCount += 1 }
        }

        let totalMin = diasSemana.reduce(0) { $0 + (($1?.workouts ?? []).reduce(0) { $0 + ($1.durationMin ?? 0) }) }

        return WeekMetrics(
            recMedia: recMedia,
            adherenciaTexto: planCount > 0 ? "\(hechoCount)/\(planCount)" : "—",
            adherenciaPct: planCount > 0 ? Int((Double(hechoCount) / Double(planCount) * 100).rounded()) : nil,
            tension: tension(at: UDate.add(monday, 6)),
            totalMin: totalMin
        )
    }

    func refreshAll() async {
        await load()
        await refreshLiveWhoop()
    }

    // MARK: - Guardado

    /// Marca cambios pendientes y programa un guardado silencioso en
    /// GitHub — no hay botón "Guardar", se guarda solo unos segundos
    /// después de la última edición. `save()` también corre al pasar la
    /// app a background, como red de seguridad.
    func markDirty() {
        dirty = true
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    func save() async {
        autosaveTask?.cancel()
        guard hasToken else {
            errorMessage = "Configura tu token de GitHub en el panel de usuario para guardar."
            return
        }
        guard dirty, !saving else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let planesJSON = String(data: try enc.encode(planes), encoding: .utf8) ?? "[]"
            let recordsJSON = String(data: try enc.encode(records), encoding: .utf8) ?? "[]"
            try await service.putFile(path: "data/planes.json", content: planesJSON, token: token)
            try await service.putFile(path: "data/records.json", content: recordsJSON, token: token)
            dirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
