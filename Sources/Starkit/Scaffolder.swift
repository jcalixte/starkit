import AppKit
import StarkitCore

/// C11 — the bar's two edits to `src/scripts/`: write a **Script**, or take one away.
///
/// It writes one file and opens an editor. It does *not* regenerate the registry, build, or tell the
/// bar anything: C6 is watching `src/`, so a **Script** appearing there is already a **Script**
/// Starkit lists. That is the whole reason F11's "0 registry edits" is true, and it is also why a
/// **Script** written directly in Zed — never going near the bar — registers identically. The bar is a
/// shortcut to a file, not a second way in.
struct Scaffolder {
    let home: URL

    /// Where a **Keyword** lives, before it exists.
    private func file(for keyword: String) -> URL {
        Watcher.scripts(in: home).appending(path: "\(keyword).gleam")
    }

    /// Write the template if there is nothing there, then open whatever is there now.
    ///
    /// **Never overwrites.** A file can exist while its **Keyword** matches nothing in the bar — a
    /// **Script** that has never compiled is absent from `manifests.json` and therefore absent from
    /// the list — so "nothing matched" is not the same question as "nothing is there". Opening the
    /// existing file is also the more useful answer: it is almost certainly the one that would not
    /// compile.
    func create(_ keyword: String) throws(Refusal) -> URL {
        let destination = file(for: keyword)

        if !FileManager.default.fileExists(atPath: destination.path) {
            do {
                // `.withoutOverwriting` and **not** `.atomic`. The two cannot be combined — Foundation
                // traps on sight with "withoutOverwriting is not supported with atomic", which is what
                // crashed the first ↩ on this row — and of the two, refusing to overwrite is the one
                // worth keeping: clobbering a **Script** someone wrote is the only outcome here that
                // loses work, while a half-written *new* file announces itself by not compiling within
                // 200 ms. It also keeps the guarantee at the filesystem rather than in the check above,
                // which cannot see a file created between asking and writing.
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
    /// The same `open` as `create`, because "the bar scaffolds, the editor is where all typing happens"
    /// (F11) is the same sentence whether the file was written a second ago or last year. **Refuses**
    /// rather than creating when there is nothing there: a **Keyword** listed with no file behind it
    /// means the list is describing a **Script** that has gone, and quietly writing a template over
    /// that would answer a different question than the one asked.
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
    /// **Its test counts as part of it.** The seed establishes `test/<keyword>_test.gleam` as where a
    /// **Script**'s suite lives, and `gleam build` typechecks `test/` — so deleting the source and
    /// leaving the suite behind breaks the whole project within 200 ms, which is how this was found
    /// (T9.4). A suite named something else still breaks it, and that surfaces as the menu bar going
    /// red with Gleam naming the missing module, which is the honest failure this cannot prevent
    /// without reading every import.
    func files(of keyword: String) -> [URL] {
        [file(for: keyword), home.appending(path: "test/\(keyword)_test.gleam")]
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Move a **Script** to the Trash, and return where it went.
    ///
    /// **The Trash, never `unlink`.** This is the only thing in Starkit that destroys something a
    /// person wrote, and the difference between the two is whether a mistake is a mistake or a loss:
    /// `~/.starkit` is not a repository and a **Script** may have existed only there. `trashItem` also
    /// puts the undo where someone already knows to look for it, which no message in a bar can do.
    ///
    /// Deletes the source and nothing else. The **Artefact** under `build/` and the entry in
    /// `built.json` are left where they are, because C5 only ever asks about them *for a **Keyword***
    /// and there is no longer one to ask about — and because a stale artefact costs a few kilobytes
    /// while a hand-written cleanup path costs a way to delete the wrong file.
    func trash(_ keyword: String) throws(Refusal) -> [URL] {
        // Named rather than shrugged at: a **Keyword** in the bar with no file behind it means the
        // list is describing a **Script** that has already gone, and saying so is more use than
        // reporting a **Script** deleted twice.
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

    /// Zed by bundle identifier, then whatever the machine opens `.gleam` with.
    ///
    /// Asked for by identifier rather than by name, because C7 learned at T4.3 that a name is the
    /// machine's language and an identifier is not. The fallback is not a courtesy: a **Script** that
    /// has been written and cannot be opened is still written, and C6 has already built it — so this
    /// **Refuses** nothing and reports instead.
    private func open(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        if let zed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "dev.zed.Zed") {
            NSWorkspace.shared.open([url], withApplicationAt: zed, configuration: configuration)
            return
        }
        report("Zed is not installed, so \(url.lastPathComponent) opened in whatever is.")
        NSWorkspace.shared.open(url)
    }
}
