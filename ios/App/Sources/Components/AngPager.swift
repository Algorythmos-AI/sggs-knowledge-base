import SwiftUI
import UIKit

/// Horizontal, finger-tracked pager over an integer index (Ang 1…1430), backed by
/// `UIPageViewController(.scroll)`. This is the primitive Apple Books/Photos use: 1:1 drag
/// tracking at 120 Hz, native rubber-band at the ends, live neighbours (so a page's scroll
/// position is preserved when you swipe back), a built-in direction-lock against vertical
/// scrolling inside each page, and VoiceOver three-finger page scroll — none of which a SwiftUI
/// `ScrollView` of 1,430 pages gives for free.
///
/// `index` is the single source of truth (two-way). The pager writes it only when a swipe
/// *settles*; an external change (Jump, deep link, chevrons) is pushed in via `setViewControllers`.
/// Each page is a SwiftUI view hosted in an `IndexedHost`; the caller's `page` closure must inject
/// whatever environment the content needs (it is invoked from UIKit, outside the SwiftUI tree).
struct AngPager<Page: View>: UIViewControllerRepresentable {
    @Binding var index: Int
    var bounds: ClosedRange<Int> = 1...1430
    var reduceMotion = false
    @ViewBuilder var page: (Int) -> Page
    var onSettle: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .clear
        context.coordinator.setCurrent(index, in: pvc, animated: false)
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncIfNeeded(to: index, in: pvc)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: AngPager
        /// True between `willTransitionTo` and `didFinishAnimating` — `setViewControllers` must not
        /// be called during a live transition (the classic UIPageViewController crash / stale cache).
        private var isTransitioning = false
        /// An external index requested mid-transition; applied on completion, latest wins.
        private var pendingTarget: Int?

        init(_ parent: AngPager) { self.parent = parent }

        private func host(_ i: Int) -> IndexedHost<Page> {
            IndexedHost(index: i, root: parent.page(i))
        }

        private func currentIndex(_ pvc: UIPageViewController) -> Int? {
            (pvc.viewControllers?.first as? IndexedHost<Page>)?.index
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

        // MARK: delegate
        func pageViewController(_ pvc: UIPageViewController,
                                willTransitionTo pending: [UIViewController]) {
            isTransitioning = true
        }
        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTransitioning = false
            if completed, let cur = currentIndex(pvc) {
                if parent.index != cur { parent.index = cur }
                parent.onSettle(cur)
            }
            if let t = pendingTarget { pendingTarget = nil; syncIfNeeded(to: t, in: pvc) }
        }

        // MARK: external navigation
        func syncIfNeeded(to i: Int, in pvc: UIPageViewController) {
            let clamped = min(max(parent.bounds.lowerBound, i), parent.bounds.upperBound)
            guard let cur = currentIndex(pvc) else { setCurrent(clamped, in: pvc, animated: false); return }
            guard cur != clamped else { return }
            if isTransitioning { pendingTarget = clamped; return }
            let adjacent = abs(cur - clamped) == 1
            setCurrent(clamped, in: pvc,
                       animated: adjacent && !parent.reduceMotion,
                       direction: clamped > cur ? .forward : .reverse)
        }

        func setCurrent(_ i: Int, in pvc: UIPageViewController,
                        animated: Bool, direction: UIPageViewController.NavigationDirection = .forward) {
            let clamped = min(max(parent.bounds.lowerBound, i), parent.bounds.upperBound)
            isTransitioning = animated
            pvc.setViewControllers([host(clamped)], direction: direction, animated: animated) { [weak self] done in
                // a far (non-animated) jump re-sets neighbours synchronously; clear the guard
                if !animated { self?.isTransitioning = false }
                _ = done
            }
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
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
