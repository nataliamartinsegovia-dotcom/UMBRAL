import SwiftUI

enum UmbralTab: Hashable {
    case hoy, semana, registro, records
}

struct RootView: View {
    @StateObject private var store = UmbralStore()
    @State private var selected: UmbralTab = .hoy
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            InkBackground()

            // Cada pestaña vive en su propio NavigationStack, siempre montado
            // (solo se le cambia la opacidad) — así no se pierde la
            // navegación al entrar en Semana/Registro y volver.
            tabContent(.hoy) { NavigationStack { HoyView(store: store) } }
            tabContent(.semana) { NavigationStack { SemanaView(store: store) } }
            tabContent(.registro) { NavigationStack { RegistroView(store: store) } }
            tabContent(.records) { NavigationStack { RecordsView(store: store) } }
        }
        .overlay(alignment: .bottom) {
            UmbralTabBar(selected: $selected) { store.showUserPanel = true }
        }
        .preferredColorScheme(.dark)
        .task { await store.refreshAll() }
        .sheet(isPresented: $store.showUserPanel) { UserPanel(store: store) }
        .alert("Umbral", isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, store.dirty { Task { await store.save() } }
        }
    }

    @ViewBuilder
    private func tabContent<V: View>(_ tab: UmbralTab, @ViewBuilder content: () -> V) -> some View {
        content()
            .opacity(selected == tab ? 1 : 0)
            .allowsHitTesting(selected == tab)
    }
}

/// Footer propio — no el TabView nativo — porque el botón central (ola,
/// animado) y los iconos monolínea del design system no encajan en un
/// tabItem estándar de iOS.
private struct UmbralTabBar: View {
    @Binding var selected: UmbralTab
    var onWave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.hoy, label: "Hoy") { UmbralSquiggleIcon() }
            tabButton(.semana, label: "Semana") { UmbralGridIcon() }
            waveButton
            tabButton(.registro, label: "Registro") { UmbralLupaIcon() }
            tabButton(.records, label: "Récords") { UmbralRibbonIcon() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.umbralTinta))
        .overlay(Capsule().stroke(Color.umbralLineaDark, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    private func tabButton<S: Shape>(_ tab: UmbralTab, label: String, @ViewBuilder icon: () -> S) -> some View {
        let isSelected = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                icon().umbralIconStyle(isSelected ? .umbralTeja : .umbralHumo, lineWidth: 1.4)
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(isSelected ? .umbralTeja : .umbralHumo)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var waveButton: some View {
        Button(action: onWave) {
            ZStack {
                Circle().fill(Color.umbralHueso.opacity(0.06))
                UmbralWaveIcon(color: .umbralTeja).frame(width: 28, height: 16)
            }
            .frame(width: 46, height: 46)
            .overlay(Circle().stroke(Color.umbralTeja.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Panel de usuario")
    }
}
