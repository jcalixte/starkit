import AppKit
import StarkitCore

/// C11 — turn a **Keyword** nothing answers to into a file, and get out of the way.
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
