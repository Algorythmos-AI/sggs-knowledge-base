import SwiftUI
import UIKit
import os

/// File-scope (a `static let` isn't allowed on a property of a generic type's nested class).
private let angPagerLog = Logger(subsystem: "org.sggs", category: "Pager")

/// Horizontal, finger-tracked pager over an integer index (Ang 1…1430), backed by
/// `UIPageViewController(.scroll)`. This is the primitive Apple Books/Photos use: 1:1 drag
/// tracking at 120 Hz, native rubber-band at the ends, live neighbours (so a page's scroll
/// position is preserved when you swipe back), a built-in direction-lock against vertical
/// scrolling inside each page, and VoiceOver three-finger page scroll — none of which a SwiftUI
/// `ScrollView` of 1,430 pages gives for free.
///
/// `index` is a one-way input: the caller (ReaderScreen) owns `router.readerAng`, this pager only
/// reads it and, when a finger swipe *settles*, reports the new index back through `onSettle`
/// (→ `router.pagerSettled`). Programmatic navigation (chevrons, pills, Jump, deep links) flows in
/// via the `index` change → `updateUIViewController` → `reconcile()`.
///
/// All decisions live in the pure `PagerSync`; this shell only performs the effects and reads the
/// live truth (the visible page index, whether the scroll view is under a finger). It **never**
/// calls `setViewControllers(animated: true)` — programmatic turns are a synchronous non-animated
/// set wrapped in a `CATransition`, so no correctness depends on a UIKit completion callback. See
/// `PagerSync` for why the old animated path latched and killed the chevrons.
struct AngPager<Page: View>: UIViewControllerRepresentable {
    /// The desired Ang (read-only input — the router is the single source of truth).
    var index: Int
    var bounds: ClosedRange<Int> = 1...1430
    var reduceMotion = false
    @ViewBuilder var page: (Int) -> Page
    /// Called only when a finger swipe settles on a new page (never for a programmatic turn).
    var onSettle: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .clear
        context.coordinator.attach(pvc)
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshVisible()
        context.coordinator.reconcile()
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: AngPager
        private var sync: PagerSync
        private weak var pvc: UIPageViewController?
        private var watchdogGen = 0
        /// Count of self-heals; surfaced in the pager's UITest identifier so a heal can never
        /// silently mask a logic bug (a passing test must show `-h0`).
        private var heals = 0

        init(_ parent: AngPager) {
            self.parent = parent
            self.sync = PagerSync(bounds: parent.bounds)
        }

        func attach(_ pvc: UIPageViewController) {
            self.pvc = pvc
            setViewControllers(to: clamp(parent.index), transition: .none)
        }

        // MARK: truth

        private func clamp(_ i: Int) -> Int { min(max(parent.bounds.lowerBound, i), parent.bounds.upperBound) }

        /// Internal (not private) so the hosted UIKit test can assert the visible page converges.
        func currentIndex() -> Int? { (pvc?.viewControllers?.first as? IndexedHost<Page>)?.index }

        /// The pager's own scroll view is a stable first subview; if it ever isn't found we treat the
        /// pager as idle (the watchdog + verifySoon still guarantee convergence).
        private var scrollBusy: Bool {
            guard let sv = pvc?.view.subviews.compactMap({ $0 as? UIScrollView }).first else { return false }
            return sv.isTracking || sv.isDragging || sv.isDecelerating
        }

        private func host(_ i: Int) -> IndexedHost<Page> { IndexedHost(index: i, root: parent.page(i)) }

        /// A mounted page is its own `UIHostingController`, so it does not see SwiftUI environment
        /// or closure-captured values change on the parent (a new accent palette stayed stale on the
        /// open Ang until the next page turn). Re-render the visible page in place — same
        /// controller, same SwiftUI identity, so its scroll position and state are kept. Skipped
        /// while a finger is on the pager; the update that follows the settle picks it up.
        func refreshVisible() {
            guard !sync.gestureActive, !scrollBusy,
                  let visible = pvc?.viewControllers?.first as? IndexedHost<Page> else { return }
            visible.update(root: parent.page(visible.index))
        }

        // MARK: effect runner

        func reconcile() {
            guard let pvc else { return }
            run(sync.request(desired: parent.index, visible: currentIndex(), scrollBusy: scrollBusy,
                             reduceMotion: parent.reduceMotion, inWindow: pvc.view.window != nil,
                             now: CACurrentMediaTime()))
        }

        private func run(_ effects: [PagerSync.Effect]) {
            for e in effects {
                switch e {
                case .show(let i, let t):
                    setViewControllers(to: i, transition: t)
                    verifySoon()
                case .settle(let i):
                    parent.onSettle(i)
                    publishIdentifier()
                case .armWatchdog:
                    armWatchdog()
                case .log(let m):
                    heals += 1
                    angPagerLog.error("\(m, privacy: .public)")
                }
            }
        }

        /// The one place `setViewControllers` is called. Always non-animated (synchronous, rebuilds the
        /// neighbour cache, works off-window); the CATransition supplies the visual.
        private func setViewControllers(to i: Int, transition t: PagerSync.Transition) {
            guard let pvc else { return }
            let target = clamp(i)
            if t != .none {
                let tr = CATransition()
                tr.duration = 0.28
                tr.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                switch t {
                case .slide(let fwd): tr.type = .push; tr.subtype = fwd ? .fromRight : .fromLeft
                case .fade: tr.type = .fade
                case .none: break
                }
                pvc.view.layer.add(tr, forKey: "angTurn")   // same key: a newer turn replaces the older
            }
            pvc.setViewControllers([host(target)], direction: .forward, animated: false)
            publishIdentifier()
            #if DEBUG
            assert(currentIndex() == target, "AngPager visible \(String(describing: currentIndex())) != target \(target)")
            #endif
        }

        /// Cheap runtime self-heal: one runloop after a show, if nothing is under a finger and the
        /// visible page still disagrees with the router, reconcile again (I1).
        private func verifySoon() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.pvc != nil, !self.sync.gestureActive, !self.scrollBusy else { return }
                if self.currentIndex() != self.clamp(self.parent.index) { self.reconcile() }
            }
        }

        private func armWatchdog() {
            watchdogGen &+= 1
            let gen = watchdogGen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.watchdogGen == gen, self.pvc != nil else { return }
                self.run(self.sync.watchdog(desired: self.parent.index, visible: self.currentIndex(),
                                            scrollBusy: self.scrollBusy))
            }
        }

        /// Exposes the *visible* page (not the router's Ang) to XCUITests and diagnostics; the
        /// `-h<heals>` suffix (under UI test) makes a masked desync detectable.
        private func publishIdentifier() {
            guard let pvc, let cur = currentIndex() else { return }
            #if DEBUG
            let uiTest = ProcessInfo.processInfo.environment["SGGS_UITEST"] == "1"
            pvc.view.accessibilityIdentifier = uiTest ? "angPager-\(cur)-h\(heals)" : "angPager-\(cur)"
            #else
            pvc.view.accessibilityIdentifier = "angPager-\(cur)"
            #endif
        }

        // MARK: data source (neighbours; nil at the bounds → native rubber-band)

        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerBefore vc: UIViewController) -> UIViewController? {
            guard let i = (vc as? IndexedHost<Page>)?.index, i > parent.bounds.lowerBound else { return nil }
            return host(i - 1)
        }
        func pageViewController(_ pvc: UIPageViewController,
                                viewControllerAfter vc: UIViewController) -> UIViewController? {
            guard let i = (vc as? IndexedHost<Page>)?.index, i < parent.bounds.upperBound else { return nil }
            return host(i + 1)
        }

        // MARK: delegate (gesture-driven transitions only)

        func pageViewController(_ pvc: UIPageViewController, willTransitionTo pending: [UIViewController]) {
            sync.gestureBegan()
        }
        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            run(sync.gestureEnded(completed: completed, visible: currentIndex(), scrollBusy: scrollBusy,
                                  reduceMotion: parent.reduceMotion, inWindow: pvc.view.window != nil,
                                  now: CACurrentMediaTime()))
        }
    }
}

/// A container VC that remembers which Ang it renders and embeds the SwiftUI page via a
/// `UIHostingController` pinned with Auto Layout. The pin is load-bearing: a bare hosting
/// controller handed to `UIPageViewController` is not bounded to the page, so a SwiftUI
/// `ScrollView` inside it lays out at full content height and cannot scroll vertically (verified
/// in the pager spike). Pinning to the container's edges gives the hosting view a definite size,
/// so vertical scrolling and the horizontal page pan coexist.
final class IndexedHost<Page: View>: UIViewController {
    let index: Int
    private let hosting: UIHostingController<Page>

    init(index: Int, root: Page) {
        self.index = index
        self.hosting = UIHostingController(rootView: root)
        super.init(nibName: nil, bundle: nil)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) unused") }

    /// Re-render this page in place (see `AngPager.Coordinator.refreshVisible`).
    func update(root: Page) { hosting.rootView = root }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "angPage-\(index)"   // the current page's id, for XCUITests
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hosting.didMove(toParent: self)
    }
}
