import Foundation
import StarkitCore

/// C5 — bring the **Artefacts** up to date, or **Refuse**.
///
/// Two jobs that look unrelated and are not. `build()` compiles the whole project, because there
/// is only one; `staleness(of:)` then decides, per **Script**, whether that build's failure is
/// *this* **Script**'s problem. Without the second, the first would make one broken **Script** take
/// the other four down with it — see `Staleness` and ADR 0002.
struct Builder {
    let toolchain: Toolchain
    let home: URL

    /// The **Shelf**-owned modules every **Script** is compiled against.
    ///
    /// `starkit.gleam` is the **Vocabulary**; `entry.gleam` is the protocol every run goes through;
    /// `registry.gleam` names them all. A change to any one of them invalidates every **Artefact**,
    /// which is why `install.sh` compares before it copies — vendoring an identical file would move
    /// its mtime and mark all five **Stale** for nothing.
    static let sharedModules = ["starkit.gleam", "entry.gleam", "registry.gleam"]

    func build() throws(Refusal) {
        let process = Process()
        process.executableURL = toolchain.gleam
        process.arguments = ["build"]
        process.currentDirectoryURL = home

        // One pipe for both streams. Gleam writes progress to stdout and diagnostics to stderr, and
        // a compile error reads as one message with its "Compiling starkit" line above it.
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        // Not `waitUntilExit()`. Measured at T1.4: it costs 63–68 ms on this machine no matter how
        // quickly the child exits, and it pays that even when the pipe has already reached EOF, so
        // it is a polling loop rather than a wait. Against F4's 40 ms budget that overhead is larger
        // than the build it was timing. `terminationHandler` fires on notification and is free.
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        do {
            try process.run()
        } catch {
            throw Refusal(
                "The Toolchain is unusable: gleam could not be started from "
                    + "\(toolchain.gleam.path)."
            )
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        exited.wait()

        guard process.terminationStatus == 0 else {
            throw Refusal(
                "Your Scripts do not compile.",
                detail: String(decoding: data, as: UTF8.self).withoutTerminalColour
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    /// Whether this **Script**'s **Artefact** was built from the source on disk.
    ///
    /// Reading the mtimes is C5's job and comparing them is not: the rule itself is pure and lives
    /// in `StarkitCore`, where it is tested without a filesystem.
    func staleness(of keyword: String) throws(Refusal) -> Staleness {
        let source = home.appending(path: "src/scripts/\(keyword).gleam")
        guard let sourceModified = modified(source) else {
            throw Refusal("There is no Script at \(source.path).")
        }
        return Staleness.of(
            source: sourceModified,
            artefact: modified(artefact(of: keyword)),
            shared: Self.sharedModules.compactMap { name in
                modified(home.appending(path: "src/\(name)")).map {
                    SharedModule(name: name, modified: $0)
                }
            }
        )
    }

    /// Gleam's build layout, mirroring `src/`. Not a documented interface — the single reference
    /// to it on the Swift side, and a watched tension in DESIGN.md §9.
    func artefact(of keyword: String) -> URL {
        home.appending(path: "build/dev/javascript/starkit/scripts/\(keyword).mjs")
    }

    private func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
