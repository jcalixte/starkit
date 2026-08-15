import AppKit
import StarkitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var panel: SummonPanel!
    private var toolchain: Toolchain?
    private var builder: Builder?

    /// Held for the life of the process: releasing it stops the stream.
    private var watcher: Watcher.Stream?

    private let focus = Focus()

    /// The chord and the bar first, then everything they will eventually need: resolving the
    /// **Toolchain** costs 510 ms on this thread and nothing else runs while it does, so registering
    /// after it would leave ⌃⌘K dead for half a second after every login.
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
        allowEditing()
        listen()
        panel = SummonPanel()
        panel.run = { [weak self] manifest, input, run in
            self?.perform(manifest, input: input, started: run)
        }
        panel.create = { [weak self] keyword in
            self?.scaffold(keyword)
        }
        panel.delete = { [weak self] manifest in
            self?.trash(manifest)
        }
        panel.edit = { [weak self] manifest in
            self?.editScript(manifest)
        }
        panel.deletionQuestion = { manifest in
            let files = Scaffolder(home: Toolchain.home).files(of: manifest.keyword)
            guard !files.isEmpty else {
                return "“\(manifest.name)” has no file left to delete."
            }
            let names = files.map(\.lastPathComponent).joined(separator: " and ")
            return "Delete “\(manifest.name)”? ⌃D again moves \(names) to the Trash. Escape keeps it."
        }
        // Before `prepare`, because after this line nobody is waiting: the chord is taken and the
        // bar is built.
        ContextGatherer.warm()
        prepare()
    }

    /// A main menu nobody will ever see, so that ⌘V works in the bar.
    ///
    /// AppKit dispatches ⌘V as a menu key equivalent, not as a key the field handles, so with no main
    /// menu ⌘V, ⌘C, ⌘X, ⌘A and ⌘Z are all dead in the one field Starkit has. An `LSUIElement`
    /// application never draws a menu bar, so this adds nothing to the screen.
    private func allowEditing() {
        let editing = NSMenu()
        editing.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editing.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editing.addItem(.separator())
        editing.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editing.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editing.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editing.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )

        let edit = NSMenuItem()
        edit.submenu = editing
        let main = NSMenu()
        main.addItem(edit)
        NSApp.mainMenu = main
    }

    /// Take ⌃⌘K, or go red saying it could not be taken. Registering says nothing about whether the
    /// chord will ever arrive — another application's event tap can eat it upstream and macOS reports
    /// that to no one.
    private func listen() {
        hotKey = HotKey { [weak self] in
            // Safe to reach the panel even though it is built after the chord is registered: Carbon
            // dispatches on the run loop, which is not turning until this method has returned.
            self?.panel.toggle()
        }
        do {
            try hotKey.register()
            report("⌃⌘K is Starkit's.")
        } catch {
            status.set(error.reason, for: .hotKey)
            report(error.reason)
        }
    }

    private func prepare() {
        let home = Toolchain.home
        // Before the Catalogue is read, because on a first launch there is no home to read one from.
        let patient = setUpHome(home)
        let cached = Catalogue(home: home).cached()
        panel.catalogue = cached

        do {
            let toolchain = try Toolchain.resolve(home: home)
            self.toolchain = toolchain
            self.builder = Builder(toolchain: toolchain, home: home)
            report("Toolchain: bun \(toolchain.bun.path), gleam \(toolchain.gleam.path)")

            if patient {
                // Off this thread, and only when the seeding above changed something: a build behind a
                // seeded or upgraded home may resolve the dependency tree, and blocking the main actor
                // through it would leave the menu bar item present and the bar dead.
                patientBuild(toolchain: toolchain, home: home, listing: cached)
                return
            }

            settle(Self.rebuild(toolchain: toolchain, home: home), listing: cached)
            // Only once the **Toolchain** resolved: every step a save leads to needs `gleam` and
            // `bun`, so watching without them would report the same **Refusal** on every keystroke.
            watch(home: home, using: toolchain)
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
            if !cached.isEmpty {
                report("Listing \(cached.count) Scripts from the last build that worked.")
            }
        }
    }

    /// Whether this bundle is one somebody installed, rather than one somebody just built.
    /// `/Applications` is where both paths put it: `install.sh` dittos it there, and a **Cask** links
    /// it there.
    private static var isInstalled: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path.hasPrefix("/Applications/")
    }

    /// Bring `$STARKIT_HOME` up to what this bundle carries, and say whether the build after it can
    /// be slow.
    ///
    /// Every launch, exactly as `install.sh` does on every run: **Shelf**-owned files are replaced
    /// whenever they differ, and a **Cask** has no install script, so a launch that only seeded
    /// *absent* homes would leave every upgraded `starkit.gleam` unapplied.
    ///
    /// The **Shelf**'s own half being absent is what "empty" means rather than a marker file — a home
    /// someone deleted `src/starkit.gleam` out of needs the same first-launch treatment as one that
    /// never existed.
    private func setUpHome(_ home: URL) -> Bool {
        let vocabulary = home.appending(path: "src/starkit.gleam")
        let wasEmpty = !FileManager.default.fileExists(atPath: vocabulary.path)

        do throws(Refusal) {
            let summary = try Seeder(home: home).seed(from: try Seeder.vendored())
            if summary.vendored > 0 || summary.seeded > 0 {
                report("\(wasEmpty ? "Set up" : "Upgraded") \(home.path): \(summary.line)")
            }

            // True for an upgrade as well as an empty home: a vendored `gleam.toml` resolves the
            // dependency tree just as a first one does.
            let patient = wasEmpty || summary.vendored > 0

            guard wasEmpty else { return patient }

            // Asked for once, on the launch that found nothing: asking on every launch would overrule
            // someone who had just turned Start at Login off from the menu.
            //
            // Only from an installed bundle: `SMAppService` registers whichever bundle the calling
            // executable sits in, keyed by bundle identifier, so a copy in `build/` would take the
            // registration away from the installed one.
            if Self.isInstalled {
                LoginItem.set(true)
            } else {
                report("Start at Login: not asked for, because this is not an installed copy.")
            }
            return patient
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
            return false
        }
    }

    private func patientBuild(toolchain: Toolchain, home: URL, listing cached: [Manifest]) {
        status.set("Building the Scripts…", for: .scripts)
        report("Building the Scripts — a seeded or upgraded home resolves dependencies, so this is slow.")

        Task.detached {
            let outcome = Self.rebuild(toolchain: toolchain, home: home)
            await MainActor.run {
                self.settle(outcome, listing: cached)
                // Only once the Scripts are real: watching before this would report the same Refusal
                // for every file the first build writes.
                self.watch(home: home, using: toolchain)
            }
        }
    }

    /// What a launch and a save both do: make the **Artefacts** match the source, and write down what
    /// the bar may list.
    ///
    /// `nonisolated` so the watcher's queue can run it without a hop.
    private nonisolated static func rebuild(
        toolchain: Toolchain,
        home: URL
    ) -> Result<[Manifest], Refusal> {
        do throws(Refusal) {
            // The registry first: a **Script** that has just appeared is not in it yet, and the build
            // compiles what the registry imports.
            if try Watcher.regenerate(home: home) {
                report("registry.gleam rewritten.")
            }

            let builder = Builder(toolchain: toolchain, home: home)
            try builder.build()
            builder.remember()

            let runner = Runner(toolchain: toolchain, home: home)
            return .success(try Catalogue(home: home).refresh(using: runner))
        } catch {
            return .failure(error)
        }
    }

    private func settle(_ outcome: Result<[Manifest], Refusal>, listing previous: [Manifest]) {
        switch outcome {
        case .success(let scripts):
            status.set(nil, for: .scripts)
            panel.catalogue = scripts
            report("\(scripts.count) Scripts: \(scripts.map(\.keyword).joined(separator: ", "))")
        case .failure(let refusal):
            status.set(refusal.reason, for: .scripts)
            report(refusal.reason)
            if let detail = refusal.detail { report(detail) }
            if !previous.isEmpty {
                report("Listing \(previous.count) Scripts from the last build that worked.")
            }
        }
    }

    private func watch(home: URL, using toolchain: Toolchain) {
        let stream = Watcher.Stream { [weak self] in
            let started = CFAbsoluteTimeGetCurrent()
            // Already off the main thread — the stream's own queue — because `gleam build` and the
            // `bun` spawn both block.
            //
            // Writing `registry.gleam` is itself a change inside the watched tree, so adding or removing
            // a **Script** costs one extra pass. It terminates because the second pass finds the file
            // already correct and writes nothing.
            let outcome = Self.rebuild(toolchain: toolchain, home: home)
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000

            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    report(String(format: "Saved — rebuilt in %.1f ms", elapsed))
                    // Read here rather than captured: it is whatever the bar is listing *now*.
                    self.settle(outcome, listing: self.panel.catalogue)
                }
            }
        }

        do {
            try stream.watch(home.appending(path: "src"))
            watcher = stream
            report("Watching \(home.appending(path: "src").path).")
        } catch {
            // Not `.scripts`: overwriting that **Concern** would hide a real compile error behind a
            // watcher problem.
            status.set(error.reason, for: .watcher)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    /// ↩ on `Create "<keyword>"` — C11 writes the file, and nothing here makes it real: C6 is
    /// watching `src/`, so the file appearing *is* the **Script** appearing.
    private func scaffold(_ keyword: String) {
        do throws(Refusal) {
            let file = try Scaffolder(home: Toolchain.home).create(keyword)
            report("Created \(file.path) — Zed has it, and C6 will build it.")
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    private func editScript(_ manifest: Manifest) {
        do throws(Refusal) {
            let file = try Scaffolder(home: Toolchain.home).edit(manifest.keyword)
            report("Editing \(file.path).")
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    private func trash(_ manifest: Manifest) {
        do throws(Refusal) {
            let trashed = try Scaffolder(home: Toolchain.home).trash(manifest.keyword)
            report(
                "Deleted \(manifest.keyword) — in the Trash: "
                    + trashed.map(\.lastPathComponent).joined(separator: ", ")
            )
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    /// ↩ in the bar: bring the **Artefact** up to date, run it, and perform what it decided.
    ///
    /// Must stay off the main thread: a single **Open** blocks until the launch is under way — up to
    /// several seconds for a cold Electron application — and `gleam build` and the `bun` spawn block
    /// too.
    ///
    /// Everything returning to the main thread is tagged with the run it was started for, so a bar
    /// **Dismissed** in the meantime lets the run finish unheard.
    private func perform(_ manifest: Manifest, input: String, started run: Int) {
        guard let toolchain, let builder else {
            let reason = "Cannot run \"\(manifest.keyword)\": the Toolchain never resolved."
            report(reason)
            panel.settled(reason, for: run)
            return
        }

        // Read here, not inside the run: this is the last moment the answer is still about the bar
        // that was just **Dismissed**.
        let previous = focus.previous

        // On this thread for the same reason, plus one: `NSWorkspace`'s list is AppKit's own and the
        // main actor is where AppKit is read.
        let payload: Payload
        do throws(Refusal) {
            payload = try ContextGatherer()
                .payload(input: input, keyword: manifest.keyword, needs: manifest.needs)
        } catch {
            report(error.reason)
            if let detail = error.detail { report(detail) }
            status.set(error.reason, for: .run)
            panel.settled(error.reason, for: run)
            return
        }

        DispatchQueue.global().async { [weak self] in
            let start = CFAbsoluteTimeGetCurrent()
            let refusal: Refusal?
            do throws(Refusal) {
                try builder.ensureCurrent(manifest.keyword)
                let effects = try Runner(toolchain: toolchain, home: Toolchain.home)
                    .run(keyword: manifest.keyword, payload: payload)
                try Effector(
                    handingFocusBackTo: previous,
                    notifying: { message in
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated { self?.panel.notify(message, for: run) }
                        }
                    }
                ).perform(effects)
                refusal = nil
                report(
                    "↩ \(manifest.keyword) — \(effects.count) Effects in "
                        + String(format: "%.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)
                )
            } catch {
                report(error.reason)
                if let detail = error.detail { report(detail) }
                refusal = error
            }

            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.status.set(refusal?.reason, for: .run)
                    self?.panel.settled(refusal?.reason, for: run)
                }
            }
        }
    }
}
