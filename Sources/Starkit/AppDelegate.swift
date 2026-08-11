import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var toolchain: Toolchain?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = MenuBarStatus()
        resolveToolchain()
    }

    /// Resolved once, at launch, before anything reaches for it.
    ///
    /// F15 is specific about the timing: a missing runtime is red *before* it is needed, not at the
    /// **Summon** that first happens to want it. Synchronous on the main thread deliberately — it
    /// is one shell spawn against F9's 3 s budget, and doing it in the background would open a
    /// window during which the menu bar claims everything is fine when it already is not.
    private func resolveToolchain() {
        do {
            let resolved = try Toolchain.resolve()
            toolchain = resolved
            report("Toolchain: bun \(resolved.bun.path), gleam \(resolved.gleam.path)")
        } catch {
            toolchain = nil
            status.set(.broken(reason: error.reason))
            report(error.reason)
        }
    }

    /// Both states also go to stderr, which is where they are visible when the executable is run
    /// from a terminal during development. Under `SMAppService` there is nothing on the other end
    /// and the menu bar is the only channel — which is why C10 carries the same sentence.
    private func report(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
