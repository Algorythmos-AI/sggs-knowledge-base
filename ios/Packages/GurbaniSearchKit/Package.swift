// swift-tools-version: 6.0
import PackageDescription

// The fidelity-critical search/verify core for the SGGS iOS app.
//  - GurbaniSearchKit: Foundation only (NO SQLite, NO SwiftUI) — the portable, golden-tested core.
//  - CSQLite:          the VENDORED SQLite 3.51.0 amalgamation (FTS5) — pins unicode61 tokenization +
//                      bm25 ranking to be byte-identical on every device/iOS version (matches the exact
//                      engine that built the corpus index + the golden vectors). NOT the system SQLite.
//  - GurbaniDB:        the read-only SQLite seam that satisfies CandidateSource, over CSQLite.
// Ported byte-identically from webapp/serve.py + webapp/verify.py and pinned by ../../../contract/.
let package = Package(
    name: "GurbaniSearchKit",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "GurbaniSearchKit", targets: ["GurbaniSearchKit"]),
        .library(name: "GurbaniDB", targets: ["GurbaniDB"]),
        // Dependency-free pahar math for extensions (widgets/watch): links kilobytes, not CSQLite.
        .library(name: "GurbaniPahar", targets: ["GurbaniPahar"]),
    ],
    targets: [
        .target(name: "GurbaniPahar"),
        .target(name: "GurbaniSearchKit", dependencies: ["GurbaniPahar"]),
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include",
            cSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_FTS4"),
                .define("SQLITE_ENABLE_FTS3_TOKENIZER"),
                .define("SQLITE_THREADSAFE", to: "2"),
                .define("SQLITE_DQS", to: "3"),
            ]
        ),
        .target(
            name: "GurbaniDB",
            dependencies: ["GurbaniSearchKit", "CSQLite"]
        ),
        .testTarget(
            name: "GurbaniSearchKitTests",
            dependencies: ["GurbaniSearchKit"]
        ),
        .testTarget(
            name: "GurbaniDBTests",
            dependencies: ["GurbaniDB", "GurbaniSearchKit", "CSQLite"]   // CSQLite: StepErrorTests builds its own tiny DBs
        ),
    ]
)
