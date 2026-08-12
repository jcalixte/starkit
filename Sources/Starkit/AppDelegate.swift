import AppKit
import StarkitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var panel: SummonPanel!
    private var toolchain: Toolchain?
    private var builder: Builder?

    /// Held for the life of the process: releasing it stops the stream, and nothing here ever wants
    /// to stop watching.
    private var watcher: Watcher.Stream?

    /// Watches from launch rather than from the first **Summon**: what it has to know — which
    /// application the bar will take the keyboard from — happened before either.
    private let focus = Focus()

    /// The chord and the bar first, then everything they will eventually need.
    ///
    /// This order is a measurement, not a preference: resolving the **Toolchain** costs 510 ms on
    /// this thread (T1.2, `DESIGN.md` §4 F9) and nothing else runs while it does, so registering
    /// after it would leave ⌃⌘K dead for half a second after every login. The panel is built ahead
    /// of it because F1 is the tightest budget in the system.
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
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
        // Before `prepare` because after this line nobody is waiting: the chord is taken and the bar
        // is built. What it buys is in C8.
        ContextGatherer.warm()
        prepare()
    }

    /// Take ⌃⌘K, or go red saying it could not be taken. Registering says nothing about whether the
    /// chord will ever arrive — another application's event tap can eat it upstream and macOS
    /// reports that to no one (T2.1).
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

    /// Resolve the **Toolchain**, then build, then write down what was built — all at launch, even
    /// though nothing needs an **Artefact** yet, because SPEC requires a failure to reach the menu
    /// bar the moment it is known rather than at **Summon** time.
    ///
    /// The cache is read before any of it and replaced only if all of it works (F2).
    private func prepare() {
        let home = Toolchain.home
        // Handed to the bar before anything here can fail, and again if a `describe` improves on it,
        // so the panel's height is settled before the first **Summon** rather than in front of
        // someone.
        let cached = Catalogue(home: home).cached()
        panel.catalogue = cached

        do {
            let toolchain = try Toolchain.resolve(home: home)
            self.toolchain = toolchain
            self.builder = Builder(toolchain: toolchain, home: home)
            report("Toolchain: bun \(toolchain.bun.path), gleam \(toolchain.gleam.path)")

            settle(Self.rebuild(toolchain: toolchain, home: home), listing: cached)
            // Only once the **Toolchain** resolved: every step a save leads to needs `gleam` and
            // `bun`, so watching without them would report the same **Refusal** on every keystroke
            // in Zed. A machine in that state is red already and needs its `PATH` fixed, not a
            // rebuild.
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

    /// What a launch and a save both do: make the **Artefacts** match the source, and write down what
    /// the bar may list.
    ///
    /// One sequence, deliberately. C6 could have known it too, and then a change to the order — the
    /// registry *before* the build, since the build compiles what the registry imports — would have
    /// had to be made in two places, with the second failure being silent.
    ///
    /// `nonisolated` so the watcher's queue can run it without a hop; the main actor calls it directly
    /// at launch, where the chord and the bar are already up and nobody is waiting.
    private nonisolated static func rebuild(
        toolchain: Toolchain,
        home: URL
    ) -> Result<[Manifest], Refusal> {
        do throws(Refusal) {
            // First: a **Script** that has just appeared is not in the registry yet, and the build
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

    /// Apply what `rebuild` decided. The **Refusal** keeps the previous list on screen (F2): a
    /// **Script** that stopped compiling is a red menu bar, not a bar with nothing in it.
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

    /// C6 — after this, saving in Zed is the only step a new **Script** needs (F10, F11).
    ///
    /// The **Toolchain** is captured rather than read back on each event, because it is resolved once
    /// per launch and the callback arrives on a queue that cannot touch this actor's state.
    private func watch(home: URL, using toolchain: Toolchain) {
        let stream = Watcher.Stream { [weak self] in
            let started = CFAbsoluteTimeGetCurrent()
            // Already off the main thread — the stream's own queue — which is where this belongs:
            // `gleam build` and the `bun` spawn both block, and on the main thread that is the whole
            // application frozen, menu bar included.
            //
            // Writing `registry.gleam` is itself a change inside the watched tree, so adding or
            // removing a **Script** costs one extra pass. It terminates because the second pass finds
            // the file already correct and writes nothing: convergence rather than a path filter,
            // since an editor writing a temporary and renaming it produces events for names this
            // code would have to guess at.
            let outcome = Self.rebuild(toolchain: toolchain, home: home)
            let elapsed = (CFAbsoluteTimeGetCurrent() - started) * 1000

            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    report(String(format: "Saved — rebuilt in %.1f ms", elapsed))
                    // The list to fall back to is read here rather than captured: it is whatever the
                    // bar is listing *now*, which a save several edits ago may have changed.
                    self.settle(outcome, listing: self.panel.catalogue)
                }
            }
        }

        do {
            try stream.watch(home.appending(path: "src"))
            watcher = stream
            report("Watching \(home.appending(path: "src").path).")
        } catch {
            // Not `.scripts`: nothing is wrong with the **Scripts**, and overwriting that **Concern**
            // would hide a real compile error behind a watcher problem.
            status.set(error.reason, for: .watcher)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    /// ↩ on `Create "<keyword>"` — C11 writes the file, and nothing here makes it real.
    ///
    /// No build, no registry, no handing anything to the bar: C6 is watching `src/`, so the file
    /// appearing *is* the **Script** appearing. Doing it from here as well would be the second copy of
    /// a sequence T9.2 deliberately has one of — and it would also make the bar's create flow behave
    /// differently from writing the same file in Zed, which SPEC asks to be identical.
    ///
    /// On the main thread on purpose: this writes one small file and asks LaunchServices to open it,
    /// where the equivalent work in `perform` blocks for as long as a cold Electron launch.
    private func scaffold(_ keyword: String) {
        do throws(Refusal) {
            let file = try Scaffolder(home: Toolchain.home).create(keyword)
            report("Created \(file.path) — Zed has it, and C6 will build it.")
        } catch {
            // The bar has already gone by the time this runs, so the menu bar is the only place left
            // to say so.
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    /// ⌥↩ or ⌃O in the bar — open the **Script** where it is written (F17).
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

    /// The second ⌃D in the bar — C11 moves the **Script** to the Trash, and C6 notices it has gone.
    ///
    /// Nothing here regenerates the registry or rebuilds, for the same reason `scaffold` does not: the
    /// file leaving `src/` *is* the **Script** leaving, so deleting from the bar and deleting in Finder
    /// are the same event. The **Script** disappears from the list about 200 ms later because C6 said
    /// so, not because the bar assumed it.
    private func trash(_ manifest: Manifest) {
        do throws(Refusal) {
            let trashed = try Scaffolder(home: Toolchain.home).trash(manifest.keyword)
            report(
                "Deleted \(manifest.keyword) — in the Trash: "
                    + trashed.map(\.lastPathComponent).joined(separator: ", ")
            )
        } catch {
            // The bar has gone by now, so the menu bar carries it. A **Script** that could not be
            // deleted is a **Script** still listed and still working, which is the safe half.
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    /// ↩ in the bar: bring the **Artefact** up to date, run it, and perform what it decided.
    ///
    /// **Must stay off the main thread** (T1.5): a single **Open** blocks until the launch is under
    /// way — 35 ms warm, 4.9 s for three cold Electron applications — and `gleam build` and the
    /// `bun` spawn block too. On the main thread that is the whole application frozen, menu bar
    /// included, for as long as the slowest cold launch takes.
    ///
    /// Everything returning to the main thread is tagged with the run it was started for, so a bar
    /// **Dismissed** in the meantime lets the run finish unheard.
    ///
    /// A run when the **Toolchain** never resolved reports to the bar and stderr but *not* the menu
    /// bar, which is already red with the accurate reason from launch.
    private func perform(_ manifest: Manifest, input: String, started run: Int) {
        guard let toolchain, let builder else {
            let reason = "Cannot run \"\(manifest.keyword)\": the Toolchain never resolved."
            report(reason)
            panel.settled(reason, for: run)
            return
        }

        // Read here, not inside the run: this is the last moment the answer is still about the bar
        // that was just **Dismissed** rather than about whatever the **Script** does next.
        let previous = focus.previous

        // C8 on this thread for the same reason, plus one: `NSWorkspace`'s list is AppKit's own and
        // the main actor is where AppKit is read. Costs 0.006–0.016 ms against F6's 5, because the
        // connection was bought at launch.
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
                    // The same sentence in both places on purpose: F12 asks that it survive the bar
                    // closing, which is the menu bar's job, while the bar is where it is read while
                    // the person is still in front of it.
                    self?.status.set(refusal?.reason, for: .run)
                    self?.panel.settled(refusal?.reason, for: run)
                }
            }
        }
    }
}
