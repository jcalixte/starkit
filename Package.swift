// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Starkit",
    platforms: [.macOS(.v14)],
    targets: [
        // The pure, tested logic (Staleness, Keyword) moves into a `StarkitCore` library at
        // T1.3: SwiftPM cannot cleanly link an executable target into a test target, so
        // anything with tests has to live outside the executable.
        .executableTarget(
            name: "Starkit",
            path: "Sources/Starkit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Throwaway, deleted at Checkpoint A along with `Sources/PasteSpike` and
        // `scripts/spike-paste.sh`. A separate bundle rather than a flag on Starkit, so that
        // removing it leaves nothing behind in code that survives — and so that the Accessibility
        // grant it needs is its own and not Starkit's.
        .executableTarget(
            name: "PasteSpike",
            path: "Sources/PasteSpike",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
