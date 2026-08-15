import Foundation
import StarkitCore

struct Watcher {
    /// Where the **Keywords** live. The **Artefacts** Gleam writes go under `build/`, so a build
    /// cannot make this directory change and re-trigger the stream.
    static func scripts(in home: URL) -> URL { home.appending(path: "src/scripts") }

    static func registry(in home: URL) -> URL { home.appending(path: "src/registry.gleam") }

    /// Rewrite `registry.gleam` from whatever is in `src/scripts/`, and report whether the file
    /// actually changed.
    ///
    /// Writes only on a difference: the file is one of C5's shared modules, so an identical rewrite
    /// would move its mtime, invalidate every **Artefact**, and cost a full rebuild on every save of
    /// anything.
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
extension Watcher {
    /// The whole of `src/` and not just `src/scripts/`, because `starkit.gleam`, `entry.gleam` and
    /// `text.gleam` are vendored *into* the watched tree by an install, and C5 treats those three as
    /// shared modules.
    final class Stream {
        /// FSEvents' own latency window is not usable here: with it set to 100 ms, the first save
        /// after a pause arrived up to 509 ms late, while later saves in the same burst arrived in 80.
        /// `NoDefer` is documented to report the first event of a quiet period immediately and does
        /// not, so the window is asked for 0 and the coalescing is done below.
        private static let latency = 0.0

        /// An editor save is several filesystem events: Zed writes a sibling temporary and renames it
        /// over the target, which measured as two rebuild passes at zero latency. 50 ms is far longer
        /// than the gap between those two events and far shorter than the budget.
        private static let debounce = 0.05

        private var stream: FSEventStreamRef?
        private let queue = DispatchQueue(label: "dev.apoena.starkit.watcher")

        /// Which burst is current. Only ever touched on `queue`, so a burst of events cannot race the
        /// count that discards it.
        private var burst = 0

        /// Called on `queue`, never the main thread: everything it leads to spawns a process.
        private let changed: () -> Void

        init(changed: @escaping () -> Void) {
            self.changed = changed
        }

        /// Let the last event of a burst win.
        ///
        /// A rebuild runs *on* `queue`, so events arriving while one is under way are not lost: they
        /// wait, and start another burst behind it.
        private func coalesce() {
            burst += 1
            let mine = burst
            queue.asyncAfter(deadline: .now() + Self.debounce) { [self] in
                guard mine == burst else { return }
                changed()
            }
        }

        func watch(_ directory: URL) throws(Refusal) {
            // Passed as a retained pointer rather than captured: the C callback carries no context of
            // its own, and `stop` releases the stream before this object could go.
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
                    // `FileEvents` for per-file granularity rather than "something under src/ changed".
                    // `NoDefer` is kept even though it did not deliver what it promises, because with a
                    // zero window it is the flag that asks for the event now rather than at the end of one.
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
