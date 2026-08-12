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

/// The stream half: watch `src/`, and call back once per burst of saves.
///
/// Deliberately knows nothing about what to *do* with a save. What follows one — regenerate, build,
/// describe, tell the menu bar — is the same work a launch does, and having two components that both
/// know that sequence is how the two drift. C6 says "something changed"; the delegate owns the answer.
extension Watcher {
    /// A subscription, not a poll — which is why T8.2's idle CPU should stay at zero once this is
    /// running, and why that row says to re-take the measurement here.
    ///
    /// The whole of `src/` and not just `src/scripts/`, because `starkit.gleam`, `entry.gleam` and
    /// `text.gleam` are vendored *into* the watched tree by an install: editing the **Vocabulary**
    /// under someone's feet has to invalidate their **Artefacts** the same way editing a **Script**
    /// does, and C5 already treats those three as shared modules.
    final class Stream {
        /// **FSEvents' own latency window is not usable for this**, measured at T9.2: with it set to
        /// 100 ms, the first save after a pause arrived up to *509 ms* late and blew F10's 500 ms
        /// budget on its own, while later saves in the same burst arrived in 80. `NoDefer` is
        /// documented to report the first event of a quiet period immediately and does not, so the
        /// window is asked for 0 and the coalescing is done below, where it is a number rather than a
        /// hint.
        private static let latency = 0.0

        /// Why coalescing is needed at all: an editor save is several filesystem events. Zed writes a
        /// sibling temporary and renames it over the target, which measured as **two rebuild passes**
        /// at zero latency — the second one wasted, since the first already compiled the final bytes.
        /// 50 ms is far longer than the gap between those two events and far shorter than the budget.
        private static let debounce = 0.05

        private var stream: FSEventStreamRef?
        private let queue = DispatchQueue(label: "dev.apoena.starkit.watcher")

        /// Which burst is current. Only ever touched on `queue` — the callback arrives there and the
        /// timer is scheduled there — so a burst of events cannot race the count that discards it.
        private var burst = 0

        /// Called on `queue`, never the main thread: everything it leads to spawns a process.
        private let changed: () -> Void

        init(changed: @escaping () -> Void) {
            self.changed = changed
        }

        /// Let the last event of a burst win.
        ///
        /// A rebuild runs *on* `queue`, so events arriving while one is under way are not lost: they
        /// wait, and start another burst behind it. That matters more than it looks — a save made
        /// while the previous build is still running is exactly the one that must not be dropped.
        private func coalesce() {
            burst += 1
            let mine = burst
            queue.asyncAfter(deadline: .now() + Self.debounce) { [self] in
                guard mine == burst else { return }
                changed()
            }
        }

        /// Watching `src/` requires no permission — it is inside the user's own home and holds no
        /// TCC-protected directory — which is why C6 could be deferred without deferring a grant.
        func watch(_ directory: URL) throws(Refusal) {
            // Passed as a retained pointer rather than captured: the C callback carries no context of
            // its own, and this object outlives every call by construction — `stop` is the only place
            // it could be released, and it releases the stream first.
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )

            let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
                guard let info else { return }
                Unmanaged<Stream>.fromOpaque(info).takeUnretainedValue().coalesce()
            }

            guard
                let stream = FSEventStreamCreate(
                    nil,
                    callback,
                    &context,
                    [directory.path] as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                    Self.latency,
                    // `FileEvents` for per-file granularity rather than "something under src/
                    // changed", which is all a directory-level stream reports. `NoDefer` is kept even
                    // though it did not deliver what it promises, because with a zero window it is the
                    // flag that asks for the event now rather than at the end of one.
                    UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
                )
            else {
                throw Refusal(
                    "Starkit cannot watch \(directory.path), so saving a Script will not rebuild it.",
                    detail: "Scripts already built keep working; run Starkit registry by hand."
                )
            }

            FSEventStreamSetDispatchQueue(stream, queue)
            guard FSEventStreamStart(stream) else {
                FSEventStreamInvalidate(stream)
                FSEventStreamRelease(stream)
                throw Refusal(
                    "Starkit cannot watch \(directory.path), so saving a Script will not rebuild it.",
                    detail: "Scripts already built keep working; run Starkit registry by hand."
                )
            }
            self.stream = stream
        }
    }
}
