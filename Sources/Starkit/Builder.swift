import CryptoKit
import Foundation
import StarkitCore

/// C5 — bring the **Artefacts** up to date, or **Refuse**.
///
/// Three jobs that look unrelated and are not. `build()` compiles the whole project, because there
/// is only one; `remember()` writes down what that build compiled; `staleness(of:)` then decides, per
/// **Script**, whether a *later* failed build is *this* **Script**'s problem. Without the last two,
/// the first would make one broken **Script** take the other four down with it — see `Staleness` and
/// ADR 0002.
struct Builder {
    let toolchain: Toolchain
    let home: URL

    /// The **Shelf**-owned modules every **Script** is compiled against.
    ///
    /// `starkit.gleam` is the **Vocabulary**; `entry.gleam` is the protocol every run goes through;
    /// `registry.gleam` names them all. A change to any one of them invalidates every **Artefact**.
    /// Since T1.4 that means a change to their *contents*: vendoring a byte-identical file over one
    /// of them, which `install.sh` does on every install, no longer marks anything **Stale**.
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

    /// Write down what a successful build compiled, so a later failed one can be attributed.
    ///
    /// Called only after `build()` returns without **Refusing**, and the ordering is the point: at
    /// that instant every **Artefact** on disk matches the source beside it, and this is the record
    /// of *which* source that was.
    ///
    /// A failure to write is not a **Refusal**. The worst it costs is that the next failed build
    /// cannot attribute blame and refuses **Scripts** it did not need to, which is the safe
    /// direction, and the next successful build fixes it. Refusing to run over a file Starkit keeps
    /// for its own bookkeeping would be worse than the problem.
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

    /// Bring the **Artefact** up to date, or **Refuse** — and **Refuse** only when it is *this*
    /// **Script**'s problem.
    ///
    /// All five **Scripts** share one Gleam project, so a broken `youtube.gleam` fails the build that
    /// `work` also needs. `Staleness` is what turns that into one **Refusal** instead of five — see
    /// [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md).
    ///
    /// The F4 path, and the only one: the bar reaches it at ↩ and the debug CLI reaches it per
    /// invocation. Two copies of this would be two ways to decide whether a **Script** may run.
    func ensureCurrent(_ keyword: String) throws(Refusal) {
        // The build's own **Refusal** is held rather than thrown. A project that does not compile is
        // only *this* **Script**'s problem if this **Script** changed since the project last
        // compiled, and that question has not been asked yet.
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
            // The compile error verbatim when there was one — it is the only thing here that says
            // what to fix, and there is nothing Starkit could add to a Gleam diagnostic by rewording
            // it. With no compile error, the build succeeded and the **Artefact** is still not where
            // Starkit looks: that path is a layout Gleam never promised to keep (DESIGN.md §9), so
            // name it rather than report this as a missing **Script**.
            detail: failed?.detail ?? "Expected it at \(artefact(of: keyword).path)."
        )
    }

    /// Whether this **Script**'s **Artefact** was built from the source on disk.
    ///
    /// Hashing the files is C5's job and comparing the hashes is not: the rule itself is pure and
    /// lives in `StarkitCore`, where it is tested without a filesystem.
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
            // No record, or one nothing can read. Every hash then compares against `nil`, every
            // **Script** is **Stale**, and the next successful build writes a good one. Failing
            // closed is the only safe direction: the alternative is running an **Artefact** that
            // might not be what is on disk.
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

    /// SHA-256 of the bytes, or `nil` when there is no file to read.
    ///
    /// The same question Gleam asks of the same file, which is the whole reason this is a hash and
    /// not an mtime (see `Staleness`). SHA-256 over five files of about a kilobyte each costs
    /// nothing worth measuring, and CryptoKit is Apple's, so it adds no dependency.
    private func hash(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
