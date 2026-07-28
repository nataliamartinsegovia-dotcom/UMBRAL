import SwiftUI

/// Qué se guarda y dónde — responde dentro de la propia app la pregunta de
/// almacenamiento en vez de dejarla implícita. Confirmación de borrado a
/// dos toques en vez de .alert() nativo: el botón de confirmación de un
/// alert lo pinta iOS de rojo de sistema, y la regla 02 no admite un
/// segundo acento.
struct PrivacyPanelView: View {
    @ObservedObject var store: UmbralStore
    @State private var confirmingWipe = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRIVACIDAD").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text("Tus datos.").font(UType.section(24)).foregroundStyle(.umbralTinta)
                }

                Text("Umbral es de un único uso: el tuyo. No está pensado para compartirse ni para que lo use nadie más.")
                    .font(.system(size: 14))
                    .foregroundStyle(.umbralTinta.opacity(0.85))

                VStack(spacing: 0) {
                    PapelSpecRow(label: "Credenciales (WHOOP, GitHub)", value: "Keychain de este iPhone")
                    PapelSpecRow(label: "Planes y récords", value: "Tu repositorio de GitHub")
                    PapelSpecRow(label: "Hora de sincronización", value: "Este iPhone")
                }
                .padding(16)
                .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))

                VStack(alignment: .leading, spacing: 10) {
                    if confirmingWipe {
                        Text("¿Seguro? Borra el token de GitHub, las credenciales de WHOOP y tus preferencias de este iPhone. No borra nada de tu repositorio.")
                            .font(.system(size: 12))
                            .foregroundStyle(.umbralTeja)
                        HStack(spacing: 10) {
                            PapelPrimaryButton(title: "Sí, borrar", destructive: true) {
                                store.wipeLocalData()
                                confirmingWipe = false
                            }
                            PapelGhostButton(title: "Cancelar") { confirmingWipe = false }
                        }
                    } else {
                        PapelGhostButton(title: "Borrar datos locales", tone: .umbralTeja) { confirmingWipe = true }
                        Text("No borra nada de tu repositorio de GitHub.")
                            .font(.system(size: 11))
                            .foregroundStyle(.umbralHumo)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationTitle("Datos y privacidad")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
