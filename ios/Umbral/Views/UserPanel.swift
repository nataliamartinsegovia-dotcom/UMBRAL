import SwiftUI
import AuthenticationServices

/// Panel de usuario — nuestras preferencias, no una pantalla de la app.
/// Formulario → papel/tinta invertido, regla 01 del design system.
struct UserPanel: View {
    @ObservedObject var store: UmbralStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var tokenDraft = ""
    @State private var repoDraft = ""
    @State private var whoopIdDraft = ""
    @State private var whoopSecretDraft = ""
    @State private var whoopBusy = false
    @State private var whoopError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        UmbralIsotype(size: 40, color: .umbralTinta, dotColor: .umbralTeja)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("umbral").font(UType.card(18)).foregroundStyle(.umbralTinta)
                            Text("registro personal").font(UType.label(9)).foregroundStyle(.umbralHumo)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.umbralPapel)

                Section {
                    Picker("Sincronizar cada mañana a las", selection: $store.autoSyncHour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }
                } header: {
                    Text("Sincronización automática")
                } footer: {
                    Text("iOS decide el momento exacto dentro de esa franja — no es instantáneo, pero es automático en segundo plano. El cron de GitHub Actions ya sincroniza todas las mañanas a las 8h con o sin la app abierta.")
                }
                .listRowBackground(Color.umbralPapel)

                Section {
                    if store.whoopConnected {
                        HStack(spacing: 8) {
                            Circle().fill(Color.umbralTeja).frame(width: 8, height: 8)
                            Text("Conectado" + (store.whoopLiveDate.map { " · último dato \($0)" } ?? ""))
                                .font(.system(size: 13))
                        }
                        Button("Desconectar", role: .destructive) { store.whoopDisconnect() }
                    } else {
                        Text("Client ID y Client Secret de tu app en developer.whoop.com. Añade también umbral://whoop-callback como Redirect URI en el dashboard de WHOOP.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        SecureField("Client ID", text: $whoopIdDraft)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        SecureField("Client Secret", text: $whoopSecretDraft)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                        Button {
                            Task { await connectWhoop() }
                        } label: {
                            if whoopBusy { ProgressView() } else { Text("Conectar con WHOOP") }
                        }
                        .disabled(whoopIdDraft.isEmpty || whoopSecretDraft.isEmpty || whoopBusy)
                        if let whoopError {
                            Text(whoopError).font(.system(size: 12)).foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("WHOOP · lectura en vivo")
                }
                .listRowBackground(Color.umbralPapel)

                Section {
                    Text("Fine-grained token con permiso Contents: Read and write sobre este repo. Se guarda en el Keychain de tu iPhone. Planes y récords se guardan solos, unos segundos después de cada cambio.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    SecureField("github_pat_...", text: $tokenDraft)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    TextField(UMetrics.defaultRepo, text: $repoDraft)
                        .autocorrectionDisabled().textInputAutocapitalization(.never)
                    HStack {
                        Text("Estado").foregroundStyle(.secondary)
                        Spacer()
                        Text(store.saving ? "Guardando…" : (store.dirty ? "Cambios sin guardar" : "Todo guardado"))
                            .foregroundStyle(store.dirty ? .umbralTeja : .secondary)
                    }
                    .font(.system(size: 12))
                } header: {
                    Text("GitHub · planes y récords")
                }
                .listRowBackground(Color.umbralPapel)
            }
            .scrollContentBackground(.hidden)
            .background(PapelBackground())
            .tint(.umbralTeja)
            .navigationTitle("Panel de usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.umbralPapel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        store.token = tokenDraft.trimmingCharacters(in: .whitespaces)
                        store.repo = repoDraft.trimmingCharacters(in: .whitespaces).isEmpty ? UMetrics.defaultRepo : repoDraft
                        dismiss()
                    }
                }
            }
            .onAppear {
                tokenDraft = store.token
                repoDraft = store.repo
                whoopIdDraft = store.whoopClientId
                whoopSecretDraft = store.whoopClientSecret
            }
        }
        .preferredColorScheme(.light)
    }

    private func connectWhoop() async {
        whoopError = nil
        whoopBusy = true
        defer { whoopBusy = false }

        store.whoopClientId = whoopIdDraft.trimmingCharacters(in: .whitespaces)
        store.whoopClientSecret = whoopSecretDraft.trimmingCharacters(in: .whitespaces)

        let state = UUID().uuidString
        guard let url = store.whoopAuthorizeURL(state: state) else {
            whoopError = "Client ID vacío."
            return
        }

        do {
            let callback = try await webAuthenticationSession.authenticate(using: url, callback: .customScheme("umbral"), preferredBrowserSession: .shared, additionalHeaderFields: [:])
            let comps = URLComponents(url: callback, resolvingAgainstBaseURL: false)
            let items = comps?.queryItems ?? []
            guard let returnedState = items.first(where: { $0.name == "state" })?.value, returnedState == state else {
                whoopError = "Respuesta inválida (state no coincide)."
                return
            }
            guard let code = items.first(where: { $0.name == "code" })?.value else {
                whoopError = "WHOOP no devolvió código de autorización."
                return
            }
            try await store.whoopExchangeCode(code)
            await store.refreshLiveWhoop()
        } catch is CancellationError {
            // usuario canceló, no es un error
        } catch {
            whoopError = error.localizedDescription
        }
    }
}
