import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var toolchain: Toolchain?
    private var builder: Builder?

    /// The chord first, then everything it will eventually need.
    ///
    /// Ordered against a measurement rather than by taste: resolving the **Toolchain** costs 510 ms
    /// on this thread (T1.2, `DESIGN.md` §4 F9), and nothing else runs while it does. Registering
    /// after it would leave ⌃⌘K dead for half a second after every login — the one moment F9 exists
    /// to protect. The reverse costs nothing, because a chord pressed before the build finishes
    /// finds a **Refusal** waiting for it, which is the answer it should get anyway.
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
        listen()
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

    /// What ⌃⌘K does, until T2.2 gives it a panel to show.
    private func summon() {
        report("⌃⌘K")
    }

    /// Resolve the **Toolchain**, then build, before anything reaches for either.
    ///
    /// SPEC is explicit that a **Toolchain** or build failure is reported in the menu bar the
    /// moment it is known and not at **Summon** time. Without the Watcher — slice 6 — launch is
    /// the only moment anything is known, so the build happens here even though nothing needs an
    /// **Artefact** yet.
    ///
    /// Both steps share one **Refusal** path because from the outside they are the same failure —
    /// Starkit cannot run your **Scripts**, and here is which part gave way.
    private func prepare() {
        do {
            let toolchain = try Toolchain.resolve()
            self.toolchain = toolchain
            report("Toolchain: bun \(toolchain.bun.path), gleam \(toolchain.gleam.path)")

            let builder = Builder(toolchain: toolchain, home: Toolchain.home)
            self.builder = builder
            try builder.build()
            builder.remember()
            report("Scripts compile.")
        } catch {
            status.set(error.reason, for: .scripts)
            report(error.reason)
            if let detail = error.detail { report(detail) }
        }
    }

    /// Everything also goes to stderr, which is where it is visible when the executable is run from
    /// a terminal during development. Under `SMAppService` there is nothing on the other end and
    /// the menu bar is the only channel — which is why C10 carries the same sentence, and why the
    /// `detail` does not go there: a Gleam error is many lines and a menu item is one.
    private func report(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
