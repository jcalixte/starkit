import Foundation
import StarkitCore

struct Seeder {
    let home: URL

    struct Summary {
        var vendored = 0
        var seeded = 0
        var kept = 0

        var isFirstTime: Bool { seeded > 0 && kept == 0 }

        var line: String {
            "\(vendored) vendored, \(seeded) seeded, \(kept) of yours left alone"
        }
    }

    /// The seed content inside the running bundle.
    ///
    /// `Bundle.main` rather than a path relative to the executable: `install.sh` invokes the copy in
    /// `/Applications` for exactly this reason, and a **Cask** has nothing else to invoke. Running the
    /// bare binary out of `.build/` has no resources and **Refuses** here.
    static func vendored() throws(Refusal) -> URL {
        guard let resources = Bundle.main.resourceURL else {
            throw Refusal("Starkit is not running from a bundle, so it carries no seed content.")
        }
        let seed = resources.appending(path: "seed")
        guard FileManager.default.fileExists(atPath: seed.path) else {
            throw Refusal(
                "This bundle carries no seed content at \(seed.path).",
                detail: "build.sh copies seed/ into Contents/Resources. A bundle assembled without "
                    + "it cannot set up a home."
            )
        }
        return seed
    }

    /// Apply the rule to every file under `source`, and say what happened to each.
    ///
    /// `report` rather than `print`: stdout carries **Effects** and nothing else.
    func seed(from source: URL, verbose: Bool = true) throws(Refusal) -> Summary {
        var summary = Summary()
        let manager = FileManager.default

        // Sorted so two runs on the same content print the same lines in the same order.
        for relative in try Self.contents(of: source).sorted() {
            let from = source.appending(path: relative)
            let to = home.appending(path: relative)
            let exists = manager.fileExists(atPath: to.path)

            switch Seeding.verdict(for: relative, destinationExists: exists) {
            case .skip:
                continue

            case .keep:
                summary.kept += 1

            case .seed:
                try Self.copy(from, to: to)
                if verbose { report("+ \(relative) seeded") }
                summary.seeded += 1

            case .vendor:
                // Compared before writing, so an identical file keeps its mtime. No longer
                // load-bearing — the **Stale** rule compares content now (ADR 0002) — but kept so an
                // install does not touch what it did not change.
                if exists, let old = try? Data(contentsOf: to), let new = try? Data(contentsOf: from),
                    old == new
                {
                    continue
                }
                try Self.copy(from, to: to)
                if verbose { report("→ \(relative) vendored") }
                summary.vendored += 1
            }
        }

        return summary
    }

    /// Every file under `source`, as paths relative to it, with no leading `./`. Directories are not
    /// listed: one is created when the file inside it is written.
    private static func contents(of source: URL) throws(Refusal) -> [String] {
        guard
            let walker = FileManager.default.enumerator(
                at: source,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        else {
            throw Refusal("Starkit could not read the seed content at \(source.path).")
        }

        var found: [String] = []
        let prefix = source.standardizedFileURL.path + "/"
        for case let url as URL in walker {
            guard
                let regular = try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                regular
            else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(prefix) else { continue }
            found.append(String(path.dropFirst(prefix.count)))
        }
        return found
    }

    private static func copy(_ from: URL, to: URL) throws(Refusal) {
        let manager = FileManager.default
        do {
            try manager.createDirectory(
                at: to.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Removed first: `copyItem` refuses onto an existing file, and this is the vendoring path
            // where replacing is the whole point.
            if manager.fileExists(atPath: to.path) { try manager.removeItem(at: to) }
            try manager.copyItem(at: from, to: to)
        } catch {
            throw Refusal("Starkit could not write \(to.path).", detail: "\(error)")
        }
    }
}
