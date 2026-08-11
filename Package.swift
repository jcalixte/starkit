// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Starkit",
    platforms: [.macOS(.v14)],
    targets: [
        // Everything that has tests lives here. SwiftPM cannot cleanly link an executable target
        // into a test target, so the split is forced by the tooling rather than chosen — but it
        // lands in the right place anyway, because the rules worth testing are exactly the ones
        // this design made pure. `Staleness` and `Effect` now — reading a reply is separable from
        // obtaining one, which is the same line C5 sits on — and `Keyword` joins them at T2.3.
        // `Refusal` lives here because both of them throw it, not because it is tested.
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
