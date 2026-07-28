import Foundation

enum GitHubError: LocalizedError {
    case badResponse(Int, String)
    case noToken

    var errorDescription: String? {
        switch self {
        case .badResponse(let code, let msg): return "GitHub \(code): \(msg)"
        case .noToken: return "Sin token de acceso configurado"
        }
    }
}

/// Lee data/*.json del repo público vía raw.githubusercontent.com y,
/// cuando hay token, escribe planes.json / records.json vía la API de
/// contenidos de GitHub — mismo flujo que ghPutFile en index.html.
struct GitHubService {
    var repo: String = UMetrics.defaultRepo
    var branch: String = UMetrics.defaultBranch

    private var decoder: JSONDecoder { JSONDecoder() }

    func fetchJSON<T: Decodable>(_ path: String, as type: T.Type) async -> T? {
        guard let url = URL(string: "https://raw.githubusercontent.com/\(repo)/\(branch)/\(path)") else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try decoder.decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    func putFile(path: String, content: String, token: String) async throws {
        guard !token.isEmpty else { throw GitHubError.noToken }
        let url = URL(string: "https://api.github.com/repos/\(repo)/contents/\(path)")!

        var getReq = URLRequest(url: url)
        getReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        getReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        var sha: String?
        if let (data, response) = try? await URLSession.shared.data(for: getReq),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            sha = obj["sha"] as? String
        }

        var body: [String: Any] = [
            "message": "umbral (ios): actualizar \((path as NSString).lastPathComponent)",
            "content": Data(content.utf8).base64EncodedString(),
        ]
        if let sha { body["sha"] = sha }

        var putReq = URLRequest(url: url)
        putReq.httpMethod = "PUT"
        putReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        putReq.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        putReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        putReq.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: putReq)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GitHubError.badResponse(code, msg ?? "error desconocido")
        }
    }
}
