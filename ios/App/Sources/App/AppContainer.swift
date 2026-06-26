import SwiftUI
import GurbaniSearchKit

/// App-wide dependency root. Owns the CorpusActor + the launch-integrity result + the single shared
/// composition presentation (one root sheet). Injected through the environment.
@MainActor @Observable
final class AppContainer {
    let corpus: CorpusActor?
    let router = Router()
    var startupError: String?
    var integrity: IntegrityReport?
    var activeComposition: CompositionPresentation?
    var meta: CorpusMeta?

    init() {
        do { self.corpus = try CorpusActor() }
        catch { self.corpus = nil; self.startupError = error.localizedDescription }
    }

    func runIntegrity() async {
        guard let corpus else { return }
        integrity = await LaunchIntegrity.run(corpus: corpus)
    }

    func loadMeta() async {
        guard meta == nil, let corpus else { return }
        meta = try? await corpus.meta()
    }
}

/// The shared shabad/hukam modal target (single root `.sheet(item:)`).
enum CompositionPresentation: Identifiable, Hashable {
    case shabad(compId: Int)
    case hukam
    var id: String { switch self { case .shabad(let c): return "shabad-\(c)"; case .hukam: return "hukam" } }
}

/// Generic async load state for screen models.
enum LoadState<T: Sendable>: Sendable {
    case idle, loading, loaded(T), empty, failed(String)
}
