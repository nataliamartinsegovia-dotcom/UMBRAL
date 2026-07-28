import Foundation

// Misma API que usa scripts/fetch_whoop.py, pero como grant OAuth propio de
// la app (independiente del WHOOP_REFRESH_TOKEN del cron de GitHub Actions,
// para no invalidárselo mutuamente — WHOOP rota el refresh token en cada uso).

enum WhoopConfig {
    static let authURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
    static let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    static let apiBase = "https://api.prod.whoop.com/developer/v2"
    static let redirectURI = "umbral://whoop-callback"
    static let scope = "offline read:recovery read:cycles read:sleep read:workout read:profile read:body_measurement"
}

struct WhoopTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

enum WhoopError: LocalizedError {
    case notConfigured
    case httpError(Int, String)
    case noAccessToken

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Configura Client ID y Client Secret de WHOOP en Ajustes."
        case .httpError(let code, let body): return "WHOOP \(code): \(body)"
        case .noAccessToken: return "Sin sesión de WHOOP activa."
        }
    }
}

private func formEncode(_ dict: [String: String]) -> Data {
    dict.map { k, v in "\(k)=\(v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
        .data(using: .utf8)!
}

private struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

enum WhoopAuth {
    static func authorizeURL(clientId: String, state: String) -> URL? {
        var comps = URLComponents(string: WhoopConfig.authURL)!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: WhoopConfig.redirectURI),
            URLQueryItem(name: "scope", value: WhoopConfig.scope),
            URLQueryItem(name: "state", value: state),
        ]
        return comps.url
    }

    static func exchangeCode(_ code: String, clientId: String, clientSecret: String) async throws -> WhoopTokens {
        try await postToken([
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": WhoopConfig.redirectURI,
        ])
    }

    static func refresh(refreshToken: String, clientId: String, clientSecret: String) async throws -> WhoopTokens {
        try await postToken([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret,
            "scope": "offline",
        ])
    }

    private static func postToken(_ body: [String: String]) async throws -> WhoopTokens {
        var req = URLRequest(url: URL(string: WhoopConfig.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formEncode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw WhoopError.httpError(code, String(data: data, encoding: .utf8) ?? "?")
        }
        let r = try JSONDecoder().decode(TokenResponse.self, from: data)
        return WhoopTokens(accessToken: r.access_token, refreshToken: r.refresh_token,
                            expiresAt: Date().addingTimeInterval(TimeInterval(r.expires_in)))
    }
}

enum WhoopAPIService {
    private struct Page<T: Decodable>: Decodable { let records: [T]; let next_token: String? }

    private struct RecoveryRecord: Decodable {
        let created_at: String
        let score: Score?
        struct Score: Decodable {
            let recovery_score: Double?
            let hrv_rmssd_milli: Double?
            let resting_heart_rate: Double?
        }
    }
    private struct SleepRecord: Decodable {
        let start: String
        let score: Score?
        struct Score: Decodable {
            let sleep_performance_percentage: Double?
            let sleep_efficiency_percentage: Double?
        }
    }
    private struct CycleRecord: Decodable {
        let start: String
        let score: Score?
        struct Score: Decodable { let strain: Double? }
    }
    private struct WorkoutRecord: Decodable {
        let sport_name: String?
        let start: String
        let end: String
        let score: Score?
        struct Score: Decodable { let strain: Double?; let average_heart_rate: Int? }
    }

    private static func get<T: Decodable>(_ path: String, token: String, start: String) async throws -> [T] {
        var comps = URLComponents(string: WhoopConfig.apiBase + path)!
        comps.queryItems = [URLQueryItem(name: "start", value: start), URLQueryItem(name: "limit", value: "25")]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw WhoopError.httpError(code, "GET \(path)")
        }
        return try JSONDecoder().decode(Page<T>.self, from: data).records
    }

    /// Recuperación, sueño, ciclo y entrenos de los últimos `daysBack` días,
    /// combinados en un DayRecord por fecha — mismo mapeo que merge_day() en
    /// scripts/fetch_whoop.py.
    static func fetchRecentDays(token: String, daysBack: Int = 3) async throws -> [DayRecord] {
        let start = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(daysBack) * 86400))

        async let recoveryR: [RecoveryRecord] = get("/recovery", token: token, start: start)
        async let sleepR: [SleepRecord] = get("/activity/sleep", token: token, start: start)
        async let cycleR: [CycleRecord] = get("/cycle", token: token, start: start)
        async let workoutR: [WorkoutRecord] = get("/activity/workout", token: token, start: start)

        let recovery = try await recoveryR
        let sleep = try await sleepR
        let cycles = try await cycleR
        let workouts = try await workoutR

        func dateKey(_ iso: String) -> String { String(iso.prefix(10)) }

        struct Bucket { var rec: RecoveryRecord?; var sleep: SleepRecord?; var cycle: CycleRecord?; var workouts: [WorkoutRecord] = [] }
        var byDate: [String: Bucket] = [:]
        for r in recovery { byDate[dateKey(r.created_at), default: Bucket()].rec = r }
        for s in sleep { byDate[dateKey(s.start), default: Bucket()].sleep = s }
        for c in cycles { byDate[dateKey(c.start), default: Bucket()].cycle = c }
        for w in workouts { byDate[dateKey(w.start), default: Bucket()].workouts.append(w) }

        let iso8601 = ISO8601DateFormatter()
        return byDate.map { date, bucket in
            let workoutEntries: [WorkoutEntry] = bucket.workouts.map { w in
                var minutes: Int?
                if let s = iso8601.date(from: w.start), let e = iso8601.date(from: w.end) {
                    minutes = Int((e.timeIntervalSince(s) / 60).rounded())
                }
                return WorkoutEntry(sportName: w.sport_name, strain: w.score?.strain,
                                     averageHeartRate: w.score?.average_heart_rate, durationMin: minutes)
            }
            return DayRecord(
                date: date,
                recoveryScore: bucket.rec?.score?.recovery_score,
                hrvRmssdMilli: bucket.rec?.score?.hrv_rmssd_milli,
                restingHeartRate: bucket.rec?.score?.resting_heart_rate,
                dayStrain: bucket.cycle?.score?.strain,
                sleepPerformancePercentage: bucket.sleep?.score?.sleep_performance_percentage,
                sleepEfficiencyPercentage: bucket.sleep?.score?.sleep_efficiency_percentage,
                workouts: workoutEntries.isEmpty ? nil : workoutEntries
            )
        }
    }

    struct Profile { let firstName: String?; let lastName: String? }
    struct BodyMeasurement { let heightMeter: Double?; let weightKg: Double? }

    private static func getObject<T: Decodable>(_ path: String, token: String) async throws -> T {
        var req = URLRequest(url: URL(string: WhoopConfig.apiBase + path)!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw WhoopError.httpError(code, "GET \(path)")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// GET /user/profile/basic — nombre y apellidos tal como los tiene registrados en WHOOP.
    static func fetchProfile(token: String) async throws -> Profile {
        struct Raw: Decodable { let first_name: String?; let last_name: String? }
        let r: Raw = try await getObject("/user/profile/basic", token: token)
        return Profile(firstName: r.first_name, lastName: r.last_name)
    }

    /// GET /user/measurement/body — altura en metros, peso en kg.
    static func fetchBodyMeasurement(token: String) async throws -> BodyMeasurement {
        struct Raw: Decodable { let height_meter: Double?; let weight_kilogram: Double? }
        let r: Raw = try await getObject("/user/measurement/body", token: token)
        return BodyMeasurement(heightMeter: r.height_meter, weightKg: r.weight_kilogram)
    }
}
