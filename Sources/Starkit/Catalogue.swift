import Foundation
import StarkitCore

/// C2 — what Starkit knows about your **Scripts** without building or running one.
///
/// `manifests.json` is a cache and is treated as one: it is written after a build that worked, and
/// read at every other moment. That asymmetry is F2. Describing on demand would be the obvious
/// implementation and it is wrong twice over — it would put a `bun` spawn inside F1's 50 ms, and it
/// would empty the bar exactly when a **Script** stops compiling, which is the moment you most need
/// to look one up.
///
/// The Watcher rewrites it after each save (C6, slice 6). Until then launch is the only moment
/// anything is known, so launch is when it is written.
struct Catalogue {
    let home: URL

    private var file: URL { home.appendingPathComponent("manifests.json") }

    /// What the last successful `describe` wrote, or nothing.
    ///
    /// Absent, unreadable and malformed are one case on purpose: all three mean the cache cannot be
    /// trusted, none of them is worth a **Refusal** of its own, and the next successful build
    /// replaces the file outright. A first launch has no cache and that is not an error either.
    func cached() -> [Manifest] {
        guard
            let data = try? Data(contentsOf: file),
            let manifests = try? JSONDecoder().decode([Manifest].self, from: data)
        else { return [] }
        return manifests
    }

    /// Ask the **Artefact** what it holds, and write it down.
    ///
    /// Only ever called after a build that succeeded, and it writes only when the answer arrives —
    /// so a **Script** that stops compiling leaves the previous list in place rather than replacing
    /// it with nothing.
    @discardableResult
    func refresh(using runner: Runner) throws(Refusal) -> [Manifest] {
        let manifests = try runner.describe()
        do {
            let encoder = JSONEncoder()
            // Written to be read by a person as well as by us: this is the file to look at when the
            // bar lists something unexpected.
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifests).write(to: file, options: .atomic)
        } catch {
            throw Refusal(
                "Starkit could not write the list of your Scripts to \(file.path).",
                detail: "\(error)"
            )
        }
        return manifests
    }
}
