import AppKit
import ApplicationServices
import Carbon.HIToolbox
import StarkitCore

/// C7 — do to the machine what a **Script** decided, in the order it decided it.
///
/// The only component that acts, so every permission the **Shelf** was granted is exercised from
/// here and nowhere else. An **Effect** this cannot perform is a **Refusal**, never a silent skip:
/// claiming to have done something is the one failure a person cannot see.
struct Effector {
    /// Where a **Paste** hands the keyboard back (`Focus`). Nothing on the terminal path, which
    /// never activates anything, so the application in front is already the paste's target.
    private let previous: NSRunningApplication?

    /// A closure rather than a panel: the bar and the **Effector** run on different threads at
    /// opposite ends of the same run, and the only thing they need to agree on is a sentence. It
    /// also keeps the terminal path, which has no bar, from needing a branch here.
    private let notify: (String) -> Void

    init(
        handingFocusBackTo previous: NSRunningApplication? = nil,
        notifying notify: @escaping (String) -> Void = { report($0) }
    ) {
        self.previous = previous
        self.notify = notify
    }

    /// Stops at the first **Effect** it cannot perform, leaving the ones before it done: everything
    /// after a failed **Effect** was decided on the assumption that it happened.
    func perform(_ effects: [Effect]) throws(Refusal) {
        for effect in effects {
            switch effect {
            case .open(let app): try open(app)
            case .kill(let app): try kill(app)
            case .paste(let text): try paste(text)
            case .notify(let message): notify(message)
            }
        }
    }

    /// Bring an application to the front, launching it if it is not running.
    ///
    /// Which application ends up frontmost after several **Opens** is not decided here: `NSWorkspace`
    /// activates an application when its launch *finishes*, so a cold Slack can arrive after a warm
    /// terminal asked for later (measured at T1.5, left alone).
    ///
    /// `fullPath(forApplication:)` is deprecated and kept deliberately. The replacement Apple names
    /// in the warning, `urlForApplication(withBundleIdentifier:)`, answers a different question —
    /// **Open** carries the name a person reads in the Finder, and this is LaunchServices' own
    /// case-insensitive answer to it, wherever the application is installed. Enumerating likely
    /// directories instead is the mistake DESIGN.md §4 F15 records rejecting for `PATH`.
    private func open(_ app: String) throws(Refusal) {
        guard let path = NSWorkspace.shared.fullPath(forApplication: app) else {
            throw Refusal(
                "There is no application called \"\(app)\" on this machine.",
                detail: "Open takes the name you see in the Finder, not a path or a bundle id."
            )
        }
        guard NSWorkspace.shared.open(URL(fileURLWithPath: path)) else {
            throw Refusal("Starkit could not open \(app).", detail: "It is at \(path).")
        }
    }

    /// End an application without asking it, and without letting it ask you.
    ///
    /// `forceTerminate`, never `terminate()`: no save dialog and no chance for the application to
    /// refuse. Needs no Accessibility grant (`DESIGN.md` §4, F7), which is why the guard below has
    /// to be Starkit's own.
    ///
    /// **Nothing running by that name is done, not refused** — one that quit between the gather and
    /// here has satisfied the **Kill**, and from here "already gone" and "never existed" are the
    /// same absence. The cost is that a misspelt name is quiet where **Open** would be loud.
    ///
    /// Matched case-insensitively, as LaunchServices resolves an **Open** and as `clean.gleam`
    /// compares its keep list. Every instance answering to the name is killed.
    ///
    /// Matched **twice**, the second way found rather than designed: `localizedName` is the name in
    /// the machine's language, so on a French system Calculator runs as Calculatrice and
    /// `Kill("Calculator")` quietly matched nothing — while **Open** resolved it fine. Comparing
    /// bundle URLs as well closes that seam. The name match stays because it needs nothing from
    /// disk, and a **Kill** from a **Context** is already spelled as C8 spelled it.
    private func kill(_ app: String) throws(Refusal) {
        let bundle = NSWorkspace.shared.fullPath(forApplication: app)
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
        let targets = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName?.caseInsensitiveCompare(app) == .orderedSame
                || (bundle != nil && $0.bundleURL?.standardizedFileURL == bundle)
        }

        // The third lock, and the only one that holds for every **Script**: `clean.gleam` and C8 both
        // guard names arriving from a **Context**, but any **Script** can write the word itself.
        // Starkit ending here would stop the run partway down a list it is still performing.
        //
        // Both names Starkit goes by: the application's when it is the bundle in the menu bar, and
        // the process's on the terminal path, where the binary has no bundle. Neither is hard-coded
        // — a guard spelling "Starkit" stops being true the day the product is renamed.
        let names = [NSRunningApplication.current.localizedName, ProcessInfo.processInfo.processName]
        guard !names.contains(where: { $0?.caseInsensitiveCompare(app) == .orderedSame }) else {
            throw Refusal(
                "A Script cannot Kill Starkit.",
                detail: "Starkit is what performs the Effects; the run would stop halfway down its "
                    + "own list."
            )
        }

        guard !targets.isEmpty else {
            report("   Kill — nothing called \"\(app)\" is running.")
            return
        }

        for target in targets {
            guard target.forceTerminate() else {
                throw Refusal(
                    "Starkit could not kill \(app).",
                    detail: "It is process \(target.processIdentifier) and it is still running."
                )
            }
        }
        report("   Kill — \(app)\(targets.count > 1 ? " (\(targets.count) of them)" : "")")
    }

    /// Put the text on the clipboard, give the keyboard back, then press ⌘V for the person.
    ///
    /// The middle step is load-bearing: the **Shelf** had to activate to be typed into (T0.5), so a
    /// keystroke synthesised while it still holds activation lands in the bar. C1 also hands focus
    /// back on **Dismissal** — the same debt paid by whichever gets there first.
    ///
    /// The text stays on the clipboard afterwards by design (T6), so ⌘V repeats the paste by hand.
    /// It replaces whatever was there, including the **Seed** it was derived from (`DESIGN.md` §9).
    private func paste(_ text: String) throws(Refusal) {
        let start = CFAbsoluteTimeGetCurrent()
        guard AXIsProcessTrusted() else {
            // Asked for at the moment it is needed rather than at launch: a permission dialog on
            // login for something nobody has asked for yet gets an application denied on principle.
            // The grant reaches a process already running (measured at T0.5), so the fix from here
            // is granting it and pressing ↩ again — no relaunch.
            let ask = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(ask as CFDictionary)
            throw Refusal(
                "Starkit needs Accessibility before it can paste.",
                detail: "System Settings → Privacy & Security → Accessibility → Starkit. "
                    + "The text is on the clipboard; ⌘V pastes it by hand in the meantime."
            )
        }

        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)

        handFocusBack()

        // `.privateState`, **not** `.combinedSessionState`: a source built from the combined state
        // carries the modifiers physically held when it is built, and ⌃⌘K may still be down when a
        // **Script** finishes — posting ⌃⌘V, which means something else in half the applications on
        // this machine. A private state makes the flags below the only ones the event has.
        let source = CGEventSource(stateID: .privateState)
        guard
            let down = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let up = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            throw Refusal(
                "Starkit could not synthesise ⌘V.",
                detail: "The text is on the clipboard; ⌘V pastes it by hand."
            )
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        report(
            "   Paste — \(text.count) characters into "
                + "\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "whatever is in front")"
                + String(format: " in %.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)
        )
    }

    /// Wait for the application the bar took the keyboard from to have it back. Usually nothing to
    /// do: C1 hides on **Dismissal** and the **Script** then spends a build and a `bun` spawn.
    ///
    /// The deadline is for the notification that never comes — pasting into the wrong window is bad,
    /// hanging a run on a notification is worse.
    ///
    /// **This blocks, and must never be called on the main thread**: the run loop the notification
    /// arrives on has to keep turning. AppDelegate performs every **Effect** off the main thread
    /// (T1.5), and the terminal path never took activation, so it never reaches the wait at all.
    private func handFocusBack() {
        guard let previous, !previous.isActive else { return }

        let arrived = DispatchSemaphore(value: 0)
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                app.processIdentifier == previous.processIdentifier
            else { return }
            arrived.signal()
        }
        defer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }

        previous.activate()
        if arrived.wait(timeout: .now() + 0.3) == .timedOut {
            report("   \(previous.localizedName ?? "It") did not come back in 300 ms — pasting anyway.")
        }
    }
}

/// Who the keyboard belongs to when it is not the bar's (`DESIGN.md` §9).
///
/// Must be sampled as it happens, never read at **Paste** time: by then the frontmost application is
/// Starkit. Pinning it when the **Shelf** becomes active is also what keeps a **Script** that
/// **Opens** and then **Pastes** from pasting into the application it just launched.
@MainActor
final class Focus {
    /// The application the bar took the keyboard from, and where a **Paste** goes.
    private(set) var previous: NSRunningApplication?

    /// The last application that was not us to come to the front.
    private var latest: NSRunningApplication?

    init() {
        let mine = ProcessInfo.processInfo.processIdentifier
        if let current = NSWorkspace.shared.frontmostApplication, current.processIdentifier != mine {
            latest = current
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                app.processIdentifier != mine
            else { return }
            MainActor.assumeIsolated { self?.latest = app }
        }

        // Starkit becoming active *is* the moment the bar appeared — **Summon** is the only thing
        // that activates an `.accessory` application with one window — so this needs nothing from C1.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.previous = self.latest
            }
        }
    }
}
