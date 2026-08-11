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
    ]
)
