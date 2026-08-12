import AppKit
import StarkitCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: MenuBarStatus!
    private var hotKey: HotKey!
    private var panel: SummonPanel!
    private var toolchain: Toolchain?
    private var builder: Builder?

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
        let catalogue = Catalogue(home: Toolchain.home)
        // Handed to the bar before anything here can fail, and again if a `describe` improves on it,
        // so the panel's height is settled before the first **Summon** rather than in front of
        // someone.
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
            if !scripts.isEmpty {
                report("Listing \(scripts.count) Scripts from the last build that worked.")
            }
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
