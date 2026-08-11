import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var toolchain: Toolchain?
    private var builder: Builder?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
        prepare()
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
            status.set(.broken(reason: error.reason))
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
