import AppKit
import StarkitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var panel: SummonPanel!
    private var toolchain: Toolchain?
    private var builder: Builder?

    /// The chord and the bar first, then everything they will eventually need.
    ///
    /// Ordered against a measurement rather than by taste: resolving the **Toolchain** costs 510 ms
    /// on this thread (T1.2, `DESIGN.md` §4 F9), and nothing else runs while it does. Registering
    /// after it would leave ⌃⌘K dead for half a second after every login — the one moment F9 exists
    /// to protect. The panel is built ahead of it for the same reason and one more: F1 is the
    /// tightest budget in the system, and building the window is what a lazy first **Summon** would
    /// have made it pay for.
    ///
    /// A chord pressed before the build finishes costs nothing either, because it finds a
    /// **Refusal** waiting for it, which is the answer it should get anyway.
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
        listen()
        panel = SummonPanel()
        panel.run = { [weak self] manifest, input in self?.perform(manifest, input: input) }
        prepare()
    }

    /// Take ⌃⌘K, or go red saying it could not be taken.
    ///
    /// Registering says nothing about whether the chord will ever arrive: another application's
    /// event tap can eat it upstream and macOS reports that to no one (T2.1). What "⌃⌘K is
    /// Starkit's" claims is only what was asked for and granted, which is the whole of what is
    /// knowable here — the rest is visible in the one place it can be, the bar not coming up.
    private func listen() {
        hotKey = HotKey { [weak self] in
            // Safe to reach the panel from here even though it is built after the chord is
            // registered: Carbon dispatches on the run loop, which is not turning until
            // `applicationDidFinishLaunching` has returned.
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

    /// Resolve the **Toolchain**, then build, then write down what was built — before anything
    /// reaches for any of it.
    ///
    /// SPEC is explicit that a **Toolchain** or build failure is reported in the menu bar the
    /// moment it is known and not at **Summon** time. Without the Watcher — slice 6 — launch is
    /// the only moment anything is known, so all three happen here even though nothing needs an
    /// **Artefact** yet.
    ///
    /// The cache is read before any of it and replaced only if all of it works, which is F2: the
    /// bar lists your **Scripts** on a machine where they no longer compile, because the list was
    /// never the thing that broke.
    ///
    /// The three steps share one **Refusal** path because from the outside they are the same
    /// failure — Starkit cannot run your **Scripts**, and here is which part gave way.
    private func prepare() {
        let catalogue = Catalogue(home: Toolchain.home)
        // Handed to the bar before anything here can fail, and again if a `describe` improves on it.
        // The panel narrows on both, so its height is settled before the first **Summon** rather
        // than in front of someone.
        var scripts = catalogue.cached()
        panel.catalogue = scripts

        do {
            let toolchain = try Toolchain.resolve()
            self.toolchain = toolchain
            report("Toolchain: bun \(toolchain.bun.path), gleam \(toolchain.gleam.path)")

            let builder = Builder(toolchain: toolchain, home: Toolchain.home)
            self.builder = builder
            try builder.build()
            builder.remember()
            report("Scripts compile.")

            let runner = Runner(toolchain: toolchain, home: Toolchain.home)
            scripts = try catalogue.refresh(using: runner)
            panel.catalogue = scripts
            report("\(scripts.count) Scripts: \(scripts.map(\.keyword).joined(separator: ", "))")
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
            // F2 out loud: whatever gave way, the bar still lists what the last successful build
            // reported, so a Script can be looked up on a machine where it cannot be run.
            if !scripts.isEmpty {
                report("Listing \(scripts.count) Scripts from the last build that worked.")
            }
        }
    }

    /// ↩ in the bar: bring the **Artefact** up to date, run it, and perform what it decided.
    ///
    /// Off the main thread, which T1.5 made a requirement rather than a preference: a single
    /// **Open** blocks until the launch is under way — 35 ms warm, 4.9 s for three cold Electron
    /// applications — and `gleam build` and the `bun` spawn are both blocking calls of their own.
    /// On the main thread that is the whole application frozen, menu bar included, for as long as
    /// the slowest cold launch takes.
    ///
    /// Nothing here touches the panel, which C1 has already **Dismissed** before handing over,
    /// so the only thing that comes back to the main thread is the sentence C10 shows.
    ///
    /// A run when the **Toolchain** never resolved says so on stderr and no more: the menu bar is
    /// already red with the reason from launch, and a second, vaguer sentence beside it would be
    /// noise where the accurate one already is.
    private func perform(_ manifest: Manifest, input: String) {
        guard let toolchain, let builder else {
            report("Cannot run \"\(manifest.keyword)\": the Toolchain never resolved.")
            return
        }

        DispatchQueue.global().async { [weak self] in
            let start = CFAbsoluteTimeGetCurrent()
            let refusal: Refusal?
            do throws(Refusal) {
                try builder.ensureCurrent(manifest.keyword)
                let effects = try Runner(toolchain: toolchain, home: Toolchain.home)
                    .run(keyword: manifest.keyword, input: input)
                try Effector().perform(effects)
                // The one line a run that worked writes. Every other component reports what it did,
                // and without this a **Script** running and ↩ doing nothing at all look identical
                // from outside — which is the difference this task had to verify. It is also the
                // whole ↩ path on one clock, which is what T8.1 will want a `--bench` number for.
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
                    // Cleared by a run that worked, because this **Concern** is about the last one
                    // and not about the machine.
                    self?.status.set(refusal?.reason, for: .run)
                }
            }
        }
    }
}
