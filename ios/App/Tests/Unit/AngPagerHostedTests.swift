import XCTest
import SwiftUI
import UIKit
@testable import SGGS

/// Drives the real `AngPager.Coordinator` against a live `UIPageViewController` in a `UIWindow`, to
/// prove the UIKit boundary behaves: programmatic turns are synchronous and converge, including the
/// three-in-a-row sequence that the shipped build swallowed, and a set with no window still lands.
@MainActor
final class AngPagerHostedTests: XCTestCase {

    private func makeCoordinator(startAt index: Int, inWindow: Bool)
        -> (AngPager<Text>.Coordinator, UIPageViewController, UIWindow?) {
        let pager = AngPager<Text>(index: index) { Text("Ang \($0)") }
        let coord = pager.makeCoordinator()
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = coord
        pvc.delegate = coord
        var window: UIWindow?
        if inWindow {
            let w = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            w.rootViewController = pvc
            w.isHidden = false
            window = w
        }
        coord.attach(pvc)
        return (coord, pvc, window)
    }

    func testInitialPageIsShown() {
        let (coord, _, _) = makeCoordinator(startAt: 42, inWindow: true)
        XCTAssertEqual(coord.currentIndex(), 42)
    }

    func testThreeConsecutiveAdjacentTurnsConverge() {
        let (coord, _, _) = makeCoordinator(startAt: 1180, inWindow: true)
        for target in [1181, 1182, 1183] {
            coord.parent.index = target
            coord.reconcile()
            XCTAssertEqual(coord.currentIndex(), target, "programmatic turn to \(target) did not land")
        }
    }

    func testReverseTurnConverges() {
        let (coord, _, _) = makeCoordinator(startAt: 200, inWindow: true)
        coord.parent.index = 199
        coord.reconcile()
        XCTAssertEqual(coord.currentIndex(), 199)
    }

    func testFarJumpConverges() {
        let (coord, _, _) = makeCoordinator(startAt: 5, inWindow: true)
        coord.parent.index = 900
        coord.reconcile()
        XCTAssertEqual(coord.currentIndex(), 900)
    }

    func testSetWithNoWindowStillLands() {
        let (coord, _, _) = makeCoordinator(startAt: 10, inWindow: false)
        coord.parent.index = 11
        coord.reconcile()
        XCTAssertEqual(coord.currentIndex(), 11)
    }

    /// A theme/accent change re-renders the open page in place: the builder runs again for the
    /// visible index, on the SAME hosting controller (so scroll position and state survive).
    func testParentUpdateRefreshesTheVisiblePageInPlace() {
        var built: [Int] = []
        let pager = AngPager<Text>(index: 7) { i in built.append(i); return Text("Ang \(i)") }
        let coord = pager.makeCoordinator()
        let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pvc.dataSource = coord
        pvc.delegate = coord
        coord.attach(pvc)
        let before = pvc.viewControllers?.first
        built.removeAll()

        coord.parent = pager          // what updateUIViewController does on any parent change
        coord.refreshVisible()
        coord.reconcile()

        XCTAssertEqual(built, [7], "the visible page — and only it — is rebuilt")
        XCTAssertTrue(pvc.viewControllers?.first === before, "same controller: nothing was remounted")
        XCTAssertEqual(coord.currentIndex(), 7)
    }

    func testBoundsClampedAtTheEnds() {
        let (coord, _, _) = makeCoordinator(startAt: 2, inWindow: true)
        coord.parent.index = 0
        coord.reconcile()
        XCTAssertEqual(coord.currentIndex(), 1)
        coord.parent.index = 99999
        coord.reconcile()
        XCTAssertEqual(coord.currentIndex(), 1430)
    }
}
