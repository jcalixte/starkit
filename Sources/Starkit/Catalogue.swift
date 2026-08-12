import Foundation
import StarkitCore

/// C2 — what Starkit knows about your **Scripts** without building or running one.
///
/// `manifests.json` is written only after a build that worked and read at every other moment.
/// Describing on demand instead would put a `bun` spawn inside F1's 50 ms *and* empty the bar
/// exactly when a **Script** stops compiling.
struct Catalogue {
    let home: URL

    private var file: URL { home.appendingPathComponent("manifests.json") }

    /// Absent, unreadable and malformed are one case on purpose: all three mean the cache cannot be
    /// trusted, and the next successful build replaces the file outright.
    func cached() -> [Manifest] {
        guard
            let data = try? Data(contentsOf: file),
            let manifests = try? JSONDecoder().decode([Manifest].self, from: data)
        else { return [] }
        return manifests
    }

    /// Cache first, **Artefact** only if the cache has never heard of the **Keyword** — the same
    /// order the bar reads them in, so a terminal run reproduces what ↩ does, stale cache and all.
    /// Writes nothing: this `describe` answers one question, it does not stand in for a build.
    func manifest(for keyword: String, using runner: Runner) throws(Refusal) -> Manifest? {
        if let known = cached().first(where: { $0.keyword == keyword }) { return known }
        return try runner.describe().first { $0.keyword == keyword }
    }

    /// Call only after a build that succeeded. Writes only once the answer arrives, so a **Script**
    /// that stops compiling leaves the previous list in place rather than replacing it with nothing.
    @discardableResult
    func refresh(using runner: Runner) throws(Refusal) -> [Manifest] {
        let manifests = try runner.describe()
        do {
            let encoder = JSONEncoder()
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
