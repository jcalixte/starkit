import CryptoKit
import Foundation
import StarkitCore

/// C5 — bring the **Artefacts** up to date, or **Refuse**.
///
/// `build()` compiles the whole project, because there is only one; `remember()` writes down what
/// that build compiled; `staleness(of:)` then decides, per **Script**, whether a *later* failed build
/// is *this* **Script**'s problem. Without the last two the first would make one broken **Script**
/// take the other four down with it — see `Staleness` and ADR 0002.
struct Builder {
    let toolchain: Toolchain
    let home: URL

    /// A change to the *contents* of any one of these invalidates every **Artefact**. Vendoring a
    /// byte-identical file over one, which `install.sh` does on every install, does not.
    static let sharedModules = ["starkit.gleam", "entry.gleam", "registry.gleam"]

    func build() throws(Refusal) {
        let process = Process()
        process.executableURL = toolchain.gleam
        process.arguments = ["build"]
        process.currentDirectoryURL = home

        // One pipe for both streams: Gleam writes progress to stdout and diagnostics to stderr, and
        // interleaving them is what makes a compile error read as one message.
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output

        // Not `waitUntilExit()`. Measured at T1.4: it costs 63–68 ms however quickly the child
        // exits, even when the pipe has already reached EOF — it is a polling loop, and the overhead
        // alone exceeds F4's 40 ms budget. `terminationHandler` fires on notification and is free.
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

    /// Call only after `build()` returns without **Refusing**: at that instant every **Artefact** on
    /// disk matches the source beside it, and this records *which* source that was.
    ///
    /// A failure to write is deliberately not a **Refusal** — it costs only that the next failed
    /// build over-refuses, which is the safe direction, and the next successful build fixes it.
    func remember() {
        var built: [String: String] = [:]
        for name in Self.sharedModules {
            if let hash = hash(home.appending(path: "src/\(name)")) { built[name] = hash }
        }
        for keyword in keywords() {
            if let hash = hash(source(of: keyword)) { built["scripts/\(keyword)"] = hash }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: built, options: [.sortedKeys])
        else { return }
        try? data.write(to: record)
    }

    /// Bring the **Artefact** up to date, and **Refuse** only when it is *this* **Script**'s problem
    /// — see [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md).
    ///
    /// Must stay the single F4 path: both the bar's ↩ and the debug CLI reach it, and two copies
    /// would be two ways to decide whether a **Script** may run.
    func ensureCurrent(_ keyword: String) throws(Refusal) {
        // Held rather than thrown: a project that does not compile is only *this* **Script**'s
        // problem if this **Script** changed since the project last compiled, and that question has
        // not been asked yet.
        var failed: Refusal?
        do {
            try build()
            remember()
        } catch {
            failed = error
        }

        let why = switch try staleness(of: keyword) {
        case .current: nil as String?
        case .artefactMissing: "there is no Artefact for it"
        case .sourceChanged: "it has changed since it was last built"
        case .sharedModuleChanged(let module): "\(module) changed since it was last built"
        }
        guard let why else { return }

        throw Refusal(
            "Starkit cannot run \"\(keyword)\": \(why).",
            // With no compile error the build succeeded and the **Artefact** is still not where
            // Starkit looks — a layout Gleam never promised to keep (DESIGN.md §9) — so name the
            // path rather than report this as a missing **Script**.
            detail: failed?.detail ?? "Expected it at \(artefact(of: keyword).path)."
        )
    }

    /// Hashing the files is C5's job; comparing them is `StarkitCore`'s, where the rule is tested
    /// without a filesystem.
    func staleness(of keyword: String) throws(Refusal) -> Staleness {
        let source = source(of: keyword)
        guard let sourceHash = hash(source) else {
            throw Refusal("There is no Script at \(source.path).")
        }
        let built = remembered()
        return Staleness.of(
            source: sourceHash,
            asBuilt: built["scripts/\(keyword)"],
            artefactExists: FileManager.default.fileExists(atPath: artefact(of: keyword).path),
            shared: Self.sharedModules.compactMap { name in
                hash(home.appending(path: "src/\(name)")).map { hash in
                    SharedModule(name: name, source: hash, asBuilt: built[name])
                }
            }
        )
    }

    /// Gleam's build layout, mirroring `src/`. Not a documented interface — the single reference
    /// to it on the Swift side, and a watched tension in DESIGN.md §9.
    func artefact(of keyword: String) -> URL {
        home.appending(path: "build/dev/javascript/starkit/scripts/\(keyword).mjs")
    }

    private func source(of keyword: String) -> URL {
        home.appending(path: "src/scripts/\(keyword).gleam")
    }

    /// Starkit's own bookkeeping, beside `manifests.json` rather than inside Gleam's `build/`, so
    /// that `gleam clean` and Gleam's own layout have nothing to do with it.
    private var record: URL { home.appending(path: "built.json") }

    private func remembered() -> [String: String] {
        guard let data = try? Data(contentsOf: record),
            let built = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            // Fails closed: every hash then compares against `nil` and every **Script** is
            // **Stale**. The alternative is running an **Artefact** that might not match its source.
            return [:]
        }
        return built
    }

    private func keywords() -> [String] {
        let scripts = home.appending(path: "src/scripts")
        let names = try? FileManager.default.contentsOfDirectory(atPath: scripts.path)
        return (names ?? [])
            .filter { $0.hasSuffix(".gleam") }
            .map { String($0.dropLast(".gleam".count)) }
    }

    /// SHA-256 of the bytes, or `nil` when there is no file to read. A hash and not an mtime because
    /// it is the same question Gleam asks of the same file — see `Staleness`.
    private func hash(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
