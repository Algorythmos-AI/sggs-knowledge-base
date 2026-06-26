// swift-tools-version: 6.0
import PackageDescription

// GurbaniSearchKit — the fidelity-critical search/verify core for the SGGS iOS app.
// Foundation only: NO GRDB, NO SwiftUI. Ported byte-identically from webapp/serve.py +
// webapp/verify.py and pinned by the golden vectors under ../../../contract/.
let package = Package(
    name: "GurbaniSearchKit",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "GurbaniSearchKit", targets: ["GurbaniSearchKit"]),
    ],
    targets: [
        .target(name: "GurbaniSearchKit"),
        .testTarget(
            name: "GurbaniSearchKitTests",
            dependencies: ["GurbaniSearchKit"]
        ),
    ]
)
