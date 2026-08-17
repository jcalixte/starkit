import AppKit
import StarkitCore

struct Scaffolder {
    let home: URL

    private func file(for keyword: String) -> URL {
        Watcher.scripts(in: home).appending(path: "\(keyword).gleam")
    }

    /// Write the template if there is nothing there, then open whatever is there now.
    ///
    /// Never overwrites. A file can exist while its **Keyword** matches nothing in the bar — a
    /// **Script** that has never compiled is absent from `manifests.json` — so "nothing matched" is
    /// not the same question as "nothing is there".
    func create(_ keyword: String) throws(Refusal) -> URL {
        let destination = file(for: keyword)

        if !FileManager.default.fileExists(atPath: destination.path) {
            do {
                // `.withoutOverwriting` and not `.atomic`: the two cannot be combined, Foundation traps
                // on sight with "withoutOverwriting is not supported with atomic". Of the two, refusing
                // to overwrite is the one worth keeping — clobbering a **Script** someone wrote is the
                // only outcome here that loses work — and it puts the guarantee at the filesystem rather
                // than in the check above, which cannot see a file created between asking and writing.
                try Data(Scaffold.source(for: keyword).utf8)
                    .write(to: destination, options: .withoutOverwriting)
            } catch {
                throw Refusal(
                    "Starkit could not write \(destination.path).",
                    detail: "\(error)"
                )
            }
        }

        open(destination)
        return destination
    }

    /// Open a **Script** that already exists, and say where it went.
    ///
    /// **Refuses** rather than creating when there is nothing there: a **Keyword** listed with no file
    /// behind it means the list is describing a **Script** that has gone.
    func edit(_ keyword: String) throws(Refusal) -> URL {
        let source = file(for: keyword)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw Refusal(
                "There is no Script at \(source.path).",
                detail: "Nothing was opened."
            )
        }
        open(source)
        return source
    }

    /// Everything on disk that *is* this **Script**, in the order it would be deleted, and only what
    /// exists.
    ///
    /// Its test counts as part of it: the seed establishes `test/<keyword>_test.gleam` as where a
    /// **Script**'s suite lives, and `gleam build` typechecks `test/`, so deleting the source and
    /// leaving the suite behind breaks the whole project.
    func files(of keyword: String) -> [URL] {
        [file(for: keyword), home.appending(path: "test/\(keyword)_test.gleam")]
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Move a **Script** to the Trash, and return where it went.
    ///
    /// The Trash, never `unlink`: `~/.starkit` is not a repository and a **Script** may have existed
    /// only there, so the difference between the two is whether a mistake is a mistake or a loss.
    ///
    /// Deletes the source and nothing else. The **Artefact** under `build/` and the entry in
    /// `built.json` are left where they are, because C5 only ever asks about them *for a **Keyword***
    /// and there is no longer one to ask about.
    func trash(_ keyword: String) throws(Refusal) -> [URL] {
        guard FileManager.default.fileExists(atPath: file(for: keyword).path) else {
            throw Refusal(
                "There is no Script at \(file(for: keyword).path).",
                detail: "Nothing was deleted."
            )
        }

        var trashed: [URL] = []
        for source in files(of: keyword) {
            var moved: NSURL?
            do {
                try FileManager.default.trashItem(at: source, resultingItemURL: &moved)
            } catch {
                throw Refusal(
                    "Starkit could not move \(source.lastPathComponent) to the Trash.",
                    // What already moved is named, because the next build will fail on whatever is
                    // left and the reason has to be readable from here rather than deduced.
                    detail: trashed.isEmpty
                        ? "\(error)"
                        : "\(error)\nAlready in the Trash: "
                            + trashed.map(\.lastPathComponent).joined(separator: ", ")
                )
            }
            trashed.append(moved as URL? ?? source)
        }
        return trashed
    }

    /// The `editor` in `starkit.toml`, then Zed by bundle identifier, then whatever the machine opens
    /// `.gleam` with.
    ///
    /// Zed by identifier rather than by name, because a name is the machine's language and an
    /// identifier is not. The line in `starkit.toml` is a name, because that is what a person knows
    /// their editor by and what **Open** already takes.
    private func open(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()

        if let named = Toolchain.editor(in: home) {
            if let editor = NSWorkspace.shared.fullPath(forApplication: named) {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: URL(fileURLWithPath: editor),
                    configuration: configuration
                )
                return
            }
            // Not a **Refusal**: the file still has to open, and the fallbacks below are exactly what
            // would have happened without the line.
            report("starkit.toml asks for \(named), which is not an application on this machine.")
        }

        if let zed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.zed.Zed") {
            NSWorkspace.shared.open([url], withApplicationAt: zed, configuration: configuration)
            return
        }
        report("Zed is not installed, so \(url.lastPathComponent) opened in whatever is.")
        NSWorkspace.shared.open(url)
    }
}
