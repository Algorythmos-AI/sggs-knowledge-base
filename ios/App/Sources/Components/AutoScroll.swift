import SwiftUI
import UIKit

/// Hands-free reading pace. Base points-per-second at the default Gurmukhi size; the controller
/// scales it by the reader's font size so a larger font does not read faster.
enum AutoScrollPace: String, CaseIterable, Identifiable {
    case slow, steady, brisk
    var id: String { rawValue }
    var label: String {
        switch self { case .slow: return "Slow"; case .steady: return "Steady"; case .brisk: return "Brisk" }
    }
    var basePointsPerSecond: CGFloat {
        switch self { case .slow: return 14; case .steady: return 26; case .brisk: return 44 }
    }
    static let storageKey = "sggs_autoscroll_pace"
}

/// Pure, testable step math (no UIKit state): the next content offset given the current one.
enum AutoScrollMath {
    static func nextOffset(current y: CGFloat, maxY: CGFloat, pointsPerSecond: CGFloat, dt: TimeInterval) -> CGFloat {
        guard dt > 0, dt < 1 else { return y }           // ignore a stalled or first frame
        return min(max(0, maxY), y + pointsPerSecond * CGFloat(dt))
    }
    static func pointsPerSecond(_ pace: AutoScrollPace, fontSize: CGFloat, lowPower: Bool,
                                override env: [String: String] = DebugHooks.environment) -> CGFloat {
        if let s = env["SGGS_AUTOSCROLL_PPS"], let v = Double(s) { return CGFloat(v) }
        let scaled = pace.basePointsPerSecond * max(0.75, fontSize / 24)
        return lowPower ? scaled * 0.5 : scaled
    }
}

/// Drives a real `UIScrollView` at a steady pace from a `CADisplayLink`, so lazy loading and
/// the reader's own progress saving keep working (it is a genuine scroll). Pauses the instant
/// the reader touches the page; never auto-starts; reaching the end never marks a bani read.
@MainActor
final class AutoScrollController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    /// True once a scroll view has been located — the reader only offers the control then.
    @Published private(set) var available = false

    weak var scrollView: UIScrollView?
    var pace: AutoScrollPace = .steady
    var fontSize: CGFloat = 24
    /// Called when the pace reaches the end (so the reader can restore chrome), never marks read.
    var onReachEnd: (() -> Void)?
    /// Called on every automatic pause caused by a touch, so the reader can restore chrome.
    var onUserInterrupt: (() -> Void)?

    private var link: CADisplayLink?

    func attach(_ sv: UIScrollView?) {
        guard sv !== scrollView else { return }   // idempotent: never re-publish for the same view
        scrollView = sv
        available = sv != nil
        if sv == nil { stop() }
    }

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard available, scrollView != nil, !isRunning else { return }
        isRunning = true
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        link?.invalidate(); link = nil
    }

    /// Fully tear down (view disappeared) — safe to call repeatedly.
    func stop() { pause() }

    @objc private func tick(_ link: CADisplayLink) {
        guard isRunning, let sv = scrollView else { return }
        if sv.isTracking || sv.isDragging || sv.isDecelerating {   // the reader touched the page
            pause(); onUserInterrupt?(); return
        }
        let maxY = max(0, sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom)
        let pps = AutoScrollMath.pointsPerSecond(pace, fontSize: fontSize,
                                                 lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        let y = AutoScrollMath.nextOffset(current: sv.contentOffset.y, maxY: maxY, pointsPerSecond: pps,
                                          dt: link.targetTimestamp - link.timestamp)
        sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: y), animated: false)
        if y >= maxY { pause(); onReachEnd?() }
    }
}

/// A zero-size probe placed inside a SwiftUI `ScrollView`; walks up to the hosting `UIScrollView`
/// and hands it to the controller. If SwiftUI ever stops using a `UIScrollView`, the controller
/// simply never becomes `available` and the reader hides the control.
struct ScrollViewProbe: UIViewRepresentable {
    let onFound: (UIScrollView?) -> Void
    func makeUIView(context: Context) -> ProbeView { ProbeView(onFound: onFound) }
    func updateUIView(_ uiView: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        let onFound: (UIScrollView?) -> Void
        init(onFound: @escaping (UIScrollView?) -> Void) { self.onFound = onFound; super.init(frame: .zero); isUserInteractionEnabled = false }
        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
        private weak var last: UIScrollView?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var v: UIView? = superview
            while let cur = v, !(cur is UIScrollView) { v = cur.superview }
            let found = v as? UIScrollView
            guard found !== last else { return }
            last = found
            onFound(found)
        }
    }
}
