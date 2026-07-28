import SwiftUI

/// Subpágina GitHub del panel de usuario — a dónde van los cambios
/// (planes/récords), no de dónde vienen los datos (eso es WHOOP).
struct GitHubPanelView: View {
    @ObservedObject var store: UmbralStore
    @Environment(\.dismiss) private var dismiss

    @State private var tokenDraft = ""
    @State private var repoDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ALMACENAMIENTO · GUARDADO AUTOMÁTICO").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text("GitHub.").font(UType.section(24)).foregroundStyle(.umbralTinta)
                }

                Text("Fine-grained token con permiso Contents: Read and write sobre este repo. Se guarda en el Keychain de tu iPhone. Planes y récords se guardan solos, unos segundos después de cada cambio.")
                    .font(.system(size: 12))
                    .foregroundStyle(.umbralHumo)

                PapelField(label: "Token") {
                    SecureField("github_pat_...", text: $tokenDraft).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
                PapelField(label: "Repositorio") {
                    TextField(UMetrics.defaultRepo, text: $repoDraft).autocorrectionDisabled().textInputAutocapitalization(.never)
                }

                VStack(spacing: 0) {
                    PapelSpecRow(label: "Estado", value: store.saving ? "Guardando…" : (store.dirty ? "Sin guardar" : "Al día"))
                }
                .padding(16)
                .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))

                PapelPrimaryButton(title: "Desconectar", destructive: true) {
                    store.githubDisconnect()
                    tokenDraft = ""
                    repoDraft = UMetrics.defaultRepo
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationTitle("GitHub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbar {
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
        }
    }
}
