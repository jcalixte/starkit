import Foundation
import StarkitCore

/// C6 — notice a **Script** being saved, and make it real before the next **Summon**.
///
/// The quiet load-bearing component (`DESIGN.md` §7): F2's cache, F4's already-done build, F10's red
/// menu bar and F11's new **Script** all rest on this firing. Nothing breaks when it stops — every
/// **Script** already built keeps working — which is exactly why it has to say so when it fails.
///
/// This file holds the filesystem half of the registry as well as the stream, because they are one
/// job: a **Keyword** becomes visible by appearing in `src/scripts/` and in `registry.gleam`, and the
/// second is derived from the first. `StarkitCore.Registry` owns what the file *says*.
struct Watcher {
    /// Where the **Keywords** live. Watched, listed and nothing else — the **Artefacts** Gleam writes
    /// go under `build/`, so a build cannot make this directory change and re-trigger the stream.
    static func scripts(in home: URL) -> URL { home.appending(path: "src/scripts") }

    static func registry(in home: URL) -> URL { home.appending(path: "src/registry.gleam") }

    /// Rewrite `registry.gleam` from whatever is in `src/scripts/`, and report whether the file
    /// actually changed.
    ///
    /// **Writes only on a difference.** Not an optimisation: the file is one of C5's shared modules,
    /// so an identical rewrite would move its mtime, invalidate every **Artefact**, and cost a full
    /// rebuild on every save of anything. The comparison is on bytes for the same reason the
    /// generated text is `gleam format`-clean.
    @discardableResult
    static func regenerate(home: URL) throws(Refusal) -> Bool {
        let directory = Self.scripts(in: home)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            throw Refusal(
                "Starkit cannot find your Scripts at \(directory.path).",
                detail: "Run scripts/install.sh, or set STARKIT_HOME to where they are."
            )
        }

        let keywords = names
            .filter { $0.hasSuffix(".gleam") }
            .map { String($0.dropLast(".gleam".count)) }
        let source = Registry.source(for: keywords)

        let file = Self.registry(in: home)
        if let existing = try? String(contentsOf: file, encoding: .utf8), existing == source {
            return false
        }

        do {
            try Data(source.utf8).write(to: file, options: .atomic)
        } catch {
            throw Refusal(
                "Starkit could not write \(file.path).",
                detail: "\(error)"
            )
        }
        return true
    }
}
