import SwiftUI
import SwiftData
import GurbaniSearchKit

/// App-wide dependency root. Owns the CorpusActor + the launch-integrity result + the single shared
/// composition presentation (one root sheet). Injected through the environment.
@MainActor @Observable
final class AppContainer {
    let corpus: CorpusActor?
    let router = Router()
    var startupError: String?
    var integrity: IntegrityReport?
    /// The SINGLE root modal target. One `.sheet(item:)` in RootView drives all modals; setting this
    /// while a sheet is up swaps the content (e.g. drilling from a Trail into a shabad), so there is
    /// never more than one sheet competing to present.
    var presentation: Presentation?
    /// Queued modal to present once the current sheet finishes dismissing (see `present` + RootView onDismiss).
    var pendingPresentation: Presentation?
    var meta: CorpusMeta?

    /// The SwiftData store for saved verses. Built explicitly (never via the implicit
    /// `.modelContainer(for:)` result-builder, which fatalErrors on a corrupt store): a broken
    /// bookmarks store must NEVER take scripture reading down with it. Fallback ladder:
    /// persistent → destroy-and-recreate persistent → in-memory (session-only) → nil (hide Save).
    let modelContainer: ModelContainer?
    /// "Saved verses won't persist this session" — set when the persistent store was unusable
    /// and we fell back to in-memory (or nothing). Surfaced as a one-time banner, never a crash.
    var savedStoreDegraded = false

    init() {
        do { self.corpus = try CorpusActor() }
        catch { self.corpus = nil; self.startupError = error.localizedDescription }

        let schema = Schema([SavedLine.self])
        if let persistent = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema)) {
            self.modelContainer = persistent
        } else if let recreated = Self.recreatedPersistentContainer(schema: schema) {
            // one-time recreate: the old store file was corrupt beyond opening; bookmarks are
            // user annotations (never scripture), so a clean store beats a dead feature
            self.modelContainer = recreated
            self.savedStoreDegraded = true
        } else if let memory = try? ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)) {
            self.modelContainer = memory
            self.savedStoreDegraded = true
        } else {
            self.modelContainer = nil
            self.savedStoreDegraded = true
        }
    }

    /// Destroy an unopenable store file and try once more. Returns nil if that also fails.
    private static func recreatedPersistentContainer(schema: Schema) -> ModelContainer? {
        let config = ModelConfiguration(schema: schema)
        let fm = FileManager.default
        let url = config.url
        for suffix in ["", "-shm", "-wal"] {
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        return try? ModelContainer(for: schema, configurations: config)
    }

    /// Present a modal through the single root sheet. If a sheet is already up (e.g. opening a shabad
    /// from inside the Trail/Cluster), queue it and dismiss the current one — RootView's sheet
    /// `onDismiss` then presents the queued modal AFTER the dismiss animation completes (presenting
    /// during the dismiss is dropped by SwiftUI).
    func present(_ p: Presentation) {
        guard presentation != nil else { presentation = p; return }
        pendingPresentation = p
        presentation = nil
    }

    /// Called from RootView's sheet onDismiss: flush any queued modal. If another modal was already
    /// presented in the meantime (rapid taps), keep it and drop the stale queue entry.
    func flushPendingPresentation() {
        guard let pending = pendingPresentation else { return }
        pendingPresentation = nil
        guard presentation == nil else { return }
        presentation = pending
    }

    func runIntegrity() async {
        guard let corpus else { return }
        integrity = await LaunchIntegrity.run(corpus: corpus)
    }

    /// Manual re-verify from the failure screen (clears the report so the "verifying" state
    /// shows, then re-runs the full check — a transient I/O failure shouldn't need a reinstall).
    func retryIntegrity() async {
        integrity = nil
        await runIntegrity()
    }

    func loadMeta() async {
        guard meta == nil, let corpus else { return }
        meta = try? await corpus.meta()
    }
}

/// The shared shabad/hukam modal target (passed to ShabadSheet).
enum CompositionPresentation: Identifiable, Hashable {
    case shabad(compId: Int)
    case hukam
    var id: String { switch self { case .shabad(let c): return "shabad-\(c)"; case .hukam: return "hukam" } }
}

/// Every root modal, behind ONE `.sheet(item:)`. Identifiable only (associated values needn't be Hashable).
enum Presentation: Identifiable {
    case shabad(compId: Int)
    case hukam
    case trail(TrailStart)
    case cluster(center: String, cluster: ConstellationCluster)
    var id: String {
        switch self {
        case .shabad(let c): return "shabad-\(c)"
        case .hukam: return "hukam"
        case .trail(let t): return "trail-\(t.id)"
        case .cluster(let center, let cl): return "cluster-\(center)-\(cl.co)"
        }
    }
    /// The shabad/hukam subset, for ShabadSheet.
    var composition: CompositionPresentation? {
        switch self { case .shabad(let c): return .shabad(compId: c); case .hukam: return .hukam; default: return nil }
    }
}

/// A verse the Semantic Trail starts (or steps to). Carries verbatim text so the Trail can pin it.
struct TrailStart: Identifiable, Hashable {
    let id: Int            // line id
    let gurmukhi: String
    let translit: String
    let ang: Int
    let compId: Int
}

/// Generic async load state for screen models.
enum LoadState<T: Sendable>: Sendable {
    case idle, loading, loaded(T), empty, failed(String)
}
