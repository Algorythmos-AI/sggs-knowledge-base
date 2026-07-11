import SwiftUI
import GurbaniSearchKit

/// Browse the Granth by Raag / Section / Author (meta-driven). Tapping jumps the Reader to the
/// first Ang of that division. Stack-less: pushed inside the Explore tab's NavigationStack.
struct IndexScreen: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
                if let meta = container.meta {
                    List {
                        Section("Raags") {
                            ForEach(meta.raags) { r in
                                Button { container.router.openAng(r.firstAng) } label: {
                                    HStack {
                                        GurmukhiText(verbatim: r.name, size: 18)
                                        Spacer()
                                        Text("Ang \(String(r.firstAng))").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        Section("Sections") {
                            ForEach(meta.sections) { s in
                                Button { container.router.openAng(s.firstAng) } label: {
                                    HStack { GurmukhiText(verbatim: s.name, size: 18); Spacer()
                                        Text("Ang \(String(s.firstAng))").font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                        Section("Authors") {
                            ForEach(meta.authors) { a in
                                Button { container.router.openAng(a.firstAng) } label: {
                                    HStack { Text(a.name); Spacer()
                                        Text("\(a.nLines) lines").font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
        }
        .navigationTitle("Index")
        .task { await container.loadMeta() }
    }
}
