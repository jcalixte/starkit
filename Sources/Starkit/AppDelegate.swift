import AppKit
import StarkitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var panel: SummonPanel!
    private var toolchain: Toolchain?
    private var builder: Builder?

    /// Watching from launch rather than from the first **Summon**, because what it has to know
    /// happened before either: which application the bar will be taking the keyboard from.
    private let focus = Focus()

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
        panel.run = { [weak self] manifest, input, run in
            self?.perform(manifest, input: input, started: run)
        }
        // Before `prepare` only because everything here is ordered by who is waiting, and after this
        // line nobody is: the chord is taken and the bar is built. What it buys is in C8.
        ContextGatherer.warm()
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
    /// the slowest cold launch takes. Since T5.4 the bar is on screen throughout, which makes that
    /// requirement visible rather than merely true: a spinner that stops turning is a frozen
    /// application in one glance.
    ///
    /// Everything that comes back to the main thread does so through the run this was started for,
    /// which is C1's licence to speak: a **Notify** as C7 performs it, and the outcome once the last
    /// **Effect** is done. A bar **Dismissed** in the meantime takes that licence back, and the run
    /// finishes unheard rather than following the person around.
    ///
    /// A run when the **Toolchain** never resolved says so in the bar and on stderr, and not in the
    /// menu bar: the menu bar is already red with the accurate reason from launch, and a second,
    /// vaguer sentence beside it would be noise where that one already is. The bar still has to be
    /// told, because it is holding a spinner for a run that is not going to happen.
    private func perform(_ manifest: Manifest, input: String, started run: Int) {
        guard let toolchain, let builder else {
            let reason = "Cannot run \"\(manifest.keyword)\": the Toolchain never resolved."
            report(reason)
            panel.settled(reason, for: run)
            return
        }

        // Read here rather than inside the run: this is the main actor, and it is also the last
        // moment the answer is still about the bar that was just **Dismissed** rather than about
        // whatever the **Script** does next.
        let previous = focus.previous

        // C8 on this thread and for the same reason: `NSWorkspace`'s list is AppKit's own, the main
        // actor is where AppKit is read, and both answers should describe the machine as ↩ was
        // pressed rather than as a build left it several hundred milliseconds later. It costs
        // 0.006–0.016 ms against F6's 5 — the connection it would otherwise have paid for was
        // bought at launch — and a **Script** that declares nothing pays none of it.
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
                        // Shown as it is performed rather than collected and shown at the end,
                        // because the order **Effects** are performed in is the **Script**'s
                        // decision and a sentence explaining a launch belongs after the launch.
                        DispatchQueue.main.async {
                            MainActor.assumeIsolated { self?.panel.notify(message, for: run) }
                        }
                    }
                ).perform(effects)
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
                    // The same sentence twice, answering two questions. F12 asks that it survive
                    // the bar closing, which is the menu bar's line above; the bar is where it is
                    // read while the person is still standing in front of it.
                    self?.panel.settled(refusal?.reason, for: run)
                }
            }
        }
    }
}
