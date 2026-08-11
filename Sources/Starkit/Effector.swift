import AppKit
import ApplicationServices
import Carbon.HIToolbox
import StarkitCore

/// C7 — do to the machine what a **Script** decided, in the order it decided it.
///
/// The only component that acts, which is what the closed **Effect** vocabulary buys: a **Script**
/// returns a decision and can touch nothing itself, so every permission the **Shelf** was granted
/// is exercised from here and nowhere else. All four words of the **Vocabulary** are performed here
/// as of T4.3, and an **Effect** this cannot perform is a **Refusal**, never a silent skip.
/// Claiming to have done something is the one failure a person cannot see.
struct Effector {
    /// The application the bar took the keyboard from, which is where a **Paste** hands it back
    /// (`Focus`).
    ///
    /// Nothing when nothing took it. That is the terminal path — `Starkit run youtube <url>` never
    /// activates anything, so the application in front is already the one the paste should land in,
    /// and there is no focus to restore before it.
    private let previous: NSRunningApplication?

    /// Where a **Notify** is shown.
    ///
    /// A closure rather than a panel, for the reason C1 holds a closure and not a **Runner**: the
    /// bar and the **Effector** run on different threads at opposite ends of the same run, and the
    /// only thing they need to agree on is a sentence. It also keeps the terminal path honest —
    /// `Starkit run youtube <url>` has no bar, so a **Notify** there is a line like every other, and
    /// no branch here has to know which of the two it is in.
    private let notify: (String) -> Void

    init(
        handingFocusBackTo previous: NSRunningApplication? = nil,
        notifying notify: @escaping (String) -> Void = { report($0) }
    ) {
        self.previous = previous
        self.notify = notify
    }

    /// Stops at the first **Effect** it cannot perform, leaving the ones before it done.
    ///
    /// The **Effects** after a failed one were decided on the assumption that it happened, so
    /// carrying on would be performing a decision nobody made.
    func perform(_ effects: [Effect]) throws(Refusal) {
        for effect in effects {
            switch effect {
            case .open(let app): try open(app)
            case .kill(let app): try kill(app)
            case .paste(let text): try paste(text)
            // In the order the **Script** decided it, like everything else here. A **Script** that
            // **Opens** and then explains itself says so after the launch, not before it.
            case .notify(let message): notify(message)
            }
        }
    }

    /// Bring an application to the front, launching it if it is not running.
    ///
    /// `NSWorkspace.open` rather than `openApplication(at:configuration:)`, which is the same call
    /// with a completion handler and a queue to think about. Nothing here needs either: it returns
    /// what it did, and each **Open** is finished before the next one starts.
    ///
    /// Which application ends up frontmost after several **Opens** is not something this decides.
    /// `NSWorkspace` activates an application when its launch finishes rather than when it is
    /// asked, so a cold Slack can arrive after a warm terminal asked for later. Measured at T1.5
    /// and left alone: the **Effects** were all performed, in order, and the front is not worth
    /// serialising launches for.
    ///
    /// `fullPath(forApplication:)` is deprecated, and the replacement Apple names in the warning —
    /// `urlForApplication(withBundleIdentifier:)` — answers a different question. **Open** carries
    /// the name a person reads in the Finder (CONTEXT.md), and this is LaunchServices' own answer
    /// to it: it finds an application wherever it is installed, `/System/Applications` and
    /// `~/Applications` included, and it is case-insensitive. Enumerating the directories we think
    /// applications live in would be the mistake DESIGN.md §4 F15 records rejecting for `PATH` — a
    /// list that is right until someone keeps an app somewhere else, and whose failure reads as "no
    /// such application" when there plainly is one. When macOS removes it, the build breaks loudly,
    /// which is the failure worth having.
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
    /// `forceTerminate` is `SIGKILL` by another name: no save dialog, no "are you sure", no chance
    /// for the application to refuse. That is the **Effect** as `CONTEXT.md` defines it and as T7
    /// weighs it — an empty screen immediately, paid for with whatever was unsaved. The gentler call
    /// is `terminate()`, which is a request, and a request is exactly what Clean exists not to make.
    ///
    /// It needs no permission and no Accessibility (`DESIGN.md` §4, F7): one process ending another
    /// it can see is ordinary, which is why the guarantee below has to be Starkit's own.
    ///
    /// **Nothing running by that name is done, not refused.** A **Kill** says an application should
    /// not be running, and one that quit on its own between the gather and here has satisfied it —
    /// refusing would abort the rest of the list over a race in the machine, and Clean's whole list
    /// is aimed at a **Context** sampled milliseconds earlier. The cost is that a **Script** with a
    /// misspelt name is quiet where **Open** would be loud, and it is unavoidable: from here,
    /// "already gone" and "never existed" are the same absence. It is said out loud in the log
    /// instead.
    ///
    /// Matched without case, like every other name in this system — LaunchServices resolves an
    /// **Open** that way, and `clean.gleam` compares its keep list that way. Loose matching kills
    /// more rather than less, which is the wrong direction for this **Effect**, and it is safe only
    /// because no two applications differ by case alone. Every instance answering to the name is
    /// killed: two copies of the same application are the same answer to "that should not be
    /// running".
    ///
    /// Matched **twice**, and the second way was not designed but found: `localizedName` is the name
    /// in the machine's language, so on a French system Calculator is running under the name
    /// Calculatrice and `Kill("Calculator")` quietly matched nothing at all. **Open** never had that
    /// problem — LaunchServices resolves either spelling — so the same string could launch an
    /// application and then fail to close it, which is a seam in the **Vocabulary** rather than a
    /// quirk of one **Effect**. Asking LaunchServices the same question **Open** asks and comparing
    /// bundles closes it. The name match stays because it is the one that needs nothing from disk,
    /// and because a **Kill** arriving from a **Context** is already spelled exactly as C8 spelled
    /// it.
    private func kill(_ app: String) throws(Refusal) {
        let bundle = NSWorkspace.shared.fullPath(forApplication: app)
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
        let targets = NSWorkspace.shared.runningApplications.filter {
            $0.localizedName?.caseInsensitiveCompare(app) == .orderedSame
                || (bundle != nil && $0.bundleURL?.standardizedFileURL == bundle)
        }

        // The third lock, and the only one that holds for every **Script** rather than for Clean.
        // `clean.gleam` keeps Starkit off its own list and C8 never gathers it, but both of those
        // are about a name arriving from a **Context**, and any **Script** can write the word
        // itself. Starkit ending here would end the run partway down a list it is still performing,
        // so every **Effect** after it becomes a decision nobody carried out. Loud, so the person
        // who wrote it finds out; a silent skip would leave them believing it worked.
        //
        // By name rather than by process, and by both of the names Starkit goes by: the application's
        // when it is the bundle in the menu bar, and the process's on the terminal path, where the
        // binary has no bundle and the Starkit being aimed at is the *other* one holding ⌃⌘K.
        // Neither name is written down here — a guard that hard-codes "Starkit" is a guard that stops
        // being true the day the product is renamed.
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

    /// Put the text on the clipboard, give the keyboard back, and press ⌘V for the person.
    ///
    /// Three steps in that order, and the middle one is why this **Effect** is not just a clipboard
    /// write: the **Shelf** had to activate to be typed into (T0.5, `DESIGN.md` §9), so a keystroke
    /// synthesised while it still holds activation lands in the bar. C1 hands focus back on
    /// **Dismissal** and this hands it back again — not belt and braces, but the same debt paid by
    /// whichever of the two gets there first, since a **Script** takes as long as it takes and the
    /// hand-back is asynchronous either way.
    ///
    /// The text stays on the clipboard afterwards, by design and not by omission (T6): ⌘V again
    /// repeats the paste by hand, which is what makes one run answer "and again over there".
    ///
    /// It replaces whatever was there, including the **Seed** it was very likely derived from. That
    /// ambiguity in "restore the clipboard" was settled at T5.1 in favour of the pasted text
    /// (`DESIGN.md` §9): the **Seed** is a URL you still have, and the note is the thing you just
    /// made.
    private func paste(_ text: String) throws(Refusal) {
        let start = CFAbsoluteTimeGetCurrent()
        guard AXIsProcessTrusted() else {
            // Asked for at the moment it is needed rather than at launch. Most sessions never
            // paste, and a permission dialog on login for something nobody has asked for yet is
            // the behaviour that gets an application denied on principle. The grant reaches a
            // process already running — measured at T0.5, where the very next ⌘V went through with
            // no relaunch — so the fix from here is granting it and pressing ↩ again.
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

        // `.privateState`, not `.combinedSessionState`. A source built from the combined state
        // carries the modifiers physically held at the moment it is built, and ⌃⌘K may still be
        // down when a **Script** finishes — which would post ⌃⌘V, a chord that means something
        // else in half the applications on this machine. `DESIGN.md` §9 named this task as the
        // trigger; a private state is the whole fix, because the flags below are then the only
        // ones the event has.
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

    /// Wait for the application the bar took the keyboard from to have it back.
    ///
    /// Nothing to do in the common case, which is the one worth designing for: C1 hides on
    /// **Dismissal** and a **Script** then spends a build, a `bun` spawn and possibly a fetch, so
    /// by the time a **Paste** arrives the person is usually back where they were. Asking is what
    /// makes that an observation rather than an assumption — the whole 200 ms of F7 is here, and it
    /// is spent only when the hand-back has not finished.
    ///
    /// Observing rather than polling, because polling the frontmost application from here would not
    /// make the answer arrive any sooner. The deadline is for the notification that never comes:
    /// pasting into the wrong window is bad, and hanging a run on a notification is worse.
    ///
    /// This blocks, and it is called from C4's thread rather than the main one — the run loop the
    /// notification arrives on has to keep turning. AppDelegate performs every **Effect** off the
    /// main thread (T1.5), and the one path that does not have a thread to spare — a run from a
    /// terminal — never took activation and so never reaches the wait at all.
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

/// Who the keyboard belongs to when it is not the bar's.
///
/// C7's half of the activation the bar takes (`DESIGN.md` §9). It is one component's problem in two
/// places: C1 must activate to be typed into, so **Paste** has to know what to hand back to, and by
/// the time it fires the answer cannot be looked up — the frontmost application is Starkit. So it is
/// sampled as it happens rather than read late, which is the mistake the obvious implementation
/// makes.
///
/// Pinned when the **Shelf** becomes active, not read at **Paste** time. The **Effects** of one run
/// are performed in order and an **Open** among them activates something; without the pin a
/// **Script** that **Opens** and then **Pastes** would paste into the application it just launched,
/// which is not what the **Vocabulary** promises — "whatever was frontmost before the **Shelf**
/// appeared". No **Script** does both today, and this is where that sentence stays true when one
/// does.
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

        // Starkit becoming active *is* the moment the bar appeared, which is why this needs nothing
        // from C1: **Summon** is the only thing that activates an `.accessory` application with one
        // window, and taking the answer here keeps the two components joined by the fact rather than
        // by a call.
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
