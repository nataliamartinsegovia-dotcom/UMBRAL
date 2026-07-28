import SwiftUI

/// Top bar · componente 06 del design system, "SIEMPRE VISIBLE". Es chrome
/// real (no contenido de scroll) — por eso el contenido nunca puede
/// deslizarse por debajo del status bar / Dynamic Island: hay una barra
/// fija reservando ese espacio, igual que en cualquier app nativa normal.
struct UmbralScreen<Content: View>: View {
    var onRefresh: (() async -> Void)? = nil
    @ViewBuilder var content: () -> Content
    var trailing: AnyView? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("umbral")
                    .font(UType.section(20))
                    .foregroundStyle(.umbralHueso)
                Spacer()
                if let trailing { trailing }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .overlay(alignment: .bottom) {
                DashedDivider(color: .umbralLineaDark.opacity(0.6))
            }

            ScrollView {
                content()
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(RefreshableIfNeeded(onRefresh: onRefresh))
        }
        .background(InkBackground())
    }
}

private struct RefreshableIfNeeded: ViewModifier {
    let onRefresh: (() async -> Void)?
    func body(content: Content) -> some View {
        if let onRefresh {
            content.refreshable { await onRefresh() }
        } else {
            content
        }
    }
}

/// Chip de sincronización — vive en el top bar, visible siempre, como en
/// el panel web (`.sync-chip`).
struct SyncChip: View {
    @ObservedObject var store: UmbralStore

    var body: some View {
        HStack(spacing: 6) {
            UmbralSyncIcon()
                .umbralIconStyle(store.whoopConnected ? .umbralTeja : .umbralHumo, lineWidth: 1.25)
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(store.whoopSyncing ? 360 : 0))
                .animation(store.whoopSyncing ? .linear(duration: 1.1).repeatForever(autoreverses: false) : .default, value: store.whoopSyncing)
            Text(label)
                .font(UType.label(9))
        }
        .foregroundStyle(.umbralHumo)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(Rectangle().stroke(Color.umbralLineaDark, lineWidth: 1))
    }

    private var label: String {
        if store.whoopSyncing { return "SINCRONIZANDO…" }
        if store.whoopConnected { return "WHOOP · EN VIVO" }
        return "WHOOP · \(store.lastSyncLabel)"
    }
}
