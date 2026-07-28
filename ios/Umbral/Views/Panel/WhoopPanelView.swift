import SwiftUI
import AuthenticationServices

/// Subpágina WHOOP del panel de usuario — conexión OAuth propia (ver
/// WhoopService.swift) y la preferencia de sincronización automática, que
/// vive aquí porque BackgroundSync solo habla con WHOOP, nunca con GitHub.
struct WhoopPanelView: View {
    @ObservedObject var store: UmbralStore
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    @State private var whoopIdDraft = ""
    @State private var whoopSecretDraft = ""
    @State private var whoopBusy = false
    @State private var whoopError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONEXIÓN · LECTURA EN VIVO").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text("WHOOP.").font(UType.section(24)).foregroundStyle(.umbralTinta)
                }

                if store.whoopConnected {
                    connectedBlock
                } else {
                    disconnectedBlock
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationTitle("WHOOP")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            whoopIdDraft = store.whoopClientId
            whoopSecretDraft = store.whoopClientSecret
        }
    }

    private var connectedBlock: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 0) {
                HStack {
                    Text("Estado").font(UType.label(9)).foregroundStyle(.umbralHumo)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(Color.umbralTeja).frame(width: 6, height: 6)
                        Text("Conectado").font(UType.card(13)).foregroundStyle(.umbralTinta)
                    }
                }
                .padding(.vertical, 8)
                .overlay(DashedDivider(color: .umbralLineaLight), alignment: .bottom)
                PapelSpecRow(label: "Último dato en vivo", value: store.whoopLiveDate.map { UDate.label($0) })
                PapelSpecRow(label: "Próxima sincronización", value: nextSyncLabel)
            }
            .padding(16)
            .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                Picker("Sincronizar cada mañana a las", selection: $store.autoSyncHour) {
                    ForEach(0..<24, id: \.self) { h in Text(String(format: "%02d:00", h)).tag(h) }
                }
                .tint(.umbralTeja)
                Text("iOS decide el momento exacto dentro de esa franja — no es instantáneo, pero es automático en segundo plano. El cron de GitHub Actions ya sincroniza todas las mañanas a las 8h con o sin la app abierta.")
                    .font(.system(size: 12))
                    .foregroundStyle(.umbralHumo)
            }

            PapelPrimaryButton(title: "Desconectar", destructive: true) { store.whoopDisconnect() }
        }
    }

    private var nextSyncLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE d MMM · HH:mm"
        return f.string(from: BackgroundSync.nextRun())
    }

    private var disconnectedBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Client ID y Client Secret de tu app en developer.whoop.com. Añade también umbral://whoop-callback como Redirect URI en el dashboard de WHOOP.")
                .font(.system(size: 12))
                .foregroundStyle(.umbralHumo)
            PapelField(label: "Client ID") {
                SecureField("", text: $whoopIdDraft).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
            PapelField(label: "Client Secret") {
                SecureField("", text: $whoopSecretDraft).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
            PapelPrimaryButton(title: whoopBusy ? "Conectando…" : "Conectar con WHOOP") {
                Task { await connectWhoop() }
            }
            .disabled(whoopIdDraft.isEmpty || whoopSecretDraft.isEmpty || whoopBusy)
            .opacity(whoopIdDraft.isEmpty || whoopSecretDraft.isEmpty ? 0.5 : 1)
            if let whoopError {
                Text(whoopError).font(.system(size: 12)).foregroundStyle(.umbralTeja)
            }
        }
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
