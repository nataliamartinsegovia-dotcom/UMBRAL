import SwiftUI

struct AboutPanelView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                UmbralIsotype(size: 30, color: .umbralTinta, dotColor: .umbralTeja)

                VStack(alignment: .leading, spacing: 4) {
                    Text("UMBRAL").capLabel(opacity: 0.6).foregroundStyle(.umbralTinta)
                    Text("Acerca de.").font(UType.section(24)).foregroundStyle(.umbralTinta)
                }

                VStack(spacing: 0) {
                    PapelSpecRow(label: "Versión", value: appVersion)
                }
                .padding(16)
                .overlay(Rectangle().stroke(Color.umbralLineaLight, lineWidth: 1))

                VStack(alignment: .leading, spacing: 14) {
                    Link(destination: pagesURL) { editorialLink("ver panel web ↗") }
                    Link(destination: repoURL) { editorialLink("ver repositorio ↗") }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PapelBackground())
        .navigationTitle("Acerca de")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.umbralPapel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private func editorialLink(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, design: .serif))
            .italic()
            .underline()
            .foregroundStyle(.umbralTinta)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var repoURL: URL { URL(string: "https://github.com/\(UMetrics.defaultRepo)")! }

    private var pagesURL: URL {
        let parts = UMetrics.defaultRepo.split(separator: "/")
        let owner = parts.first.map(String.init) ?? ""
        let name = parts.last.map(String.init) ?? ""
        return URL(string: "https://\(owner).github.io/\(name)/")!
    }
}
