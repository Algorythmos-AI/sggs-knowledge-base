// swift-tools-version: 6.0
import PackageDescription

// The fidelity-critical search/verify core for the SGGS iOS app.
//  - GurbaniSearchKit: Foundation only (NO SQLite, NO SwiftUI) — the portable, golden-tested core.
//  - GurbaniDB:        the read-only SQLite seam (system SQLite3) that satisfies CandidateSource.
// Both ported byte-identically from webapp/serve.py + webapp/verify.py and pinned by the golden
// vectors under ../../../contract/.
let package = Package(
    name: "GurbaniSearchKit",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "GurbaniSearchKit", targets: ["GurbaniSearchKit"]),
        .library(name: "GurbaniDB", targets: ["GurbaniDB"]),
    ],
    targets: [
        .target(name: "GurbaniSearchKit"),
        .target(
            name: "GurbaniDB",
            dependencies: ["GurbaniSearchKit"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "GurbaniSearchKitTests",
            dependencies: ["GurbaniSearchKit"]
        ),
        .testTarget(
            name: "GurbaniDBTests",
            dependencies: ["GurbaniDB", "GurbaniSearchKit"]
        ),
    ]
)
