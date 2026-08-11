import AppKit
import StarkitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var panel: SummonPanel!
    private var toolchain: Toolchain?
    private var builder: Builder?
    /// The catalogue as the bar will read it at T2.4 — cached at launch, replaced by a `describe`
    /// when there was one to be had.
    private var scripts: [Manifest] = []

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
        prepare()
    }

    /// Take ⌃⌘K, or go red saying it could not be taken.
    ///
    /// Registering says nothing about whether the chord will ever arrive: another application's
    /// event tap can eat it upstream and macOS reports that to no one (T2.1). What "⌃⌘K is
    /// Starkit's" claims is only what was asked for and granted, which is the whole of what is
    /// knowable here — the rest is visible in the one place it can be, the bar not coming up.
    private func listen() {
        hotKey = HotKey { [weak self] in self?.summon() }
        do {
            try hotKey.register()
            report("⌃⌘K is Starkit's.")
        } catch {
            status.set(error.reason, for: .hotKey)
            report(error.reason)
        }
    }

    /// Safe to reach the panel from here even though it is built after the chord is registered:
    /// Carbon dispatches on the run loop, which is not turning until this method has returned.
    private func summon() {
        panel.toggle()
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
        scripts = catalogue.cached()

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

}
