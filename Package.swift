// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Starkit",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that has tests lives here: SwiftPM cannot cleanly link an executable target
        // into a test target, so the split is forced by the tooling.
        .target(
            name: "StarkitCore",
            path: "Sources/StarkitCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Starkit",
            dependencies: ["StarkitCore"],
            path: "Sources/Starkit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "StarkitTests",
            dependencies: ["StarkitCore"],
            path: "Tests/StarkitTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
