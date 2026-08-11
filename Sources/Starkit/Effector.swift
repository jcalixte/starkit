import AppKit
import ApplicationServices
import Carbon.HIToolbox
import StarkitCore

/// C7 — do to the machine what a **Script** decided, in the order it decided it.
///
/// The only component that acts, which is what the closed **Effect** vocabulary buys: a **Script**
/// returns a decision and can touch nothing itself, so every permission the **Shelf** was granted
/// is exercised from here and nowhere else. **Open** and **Paste** are what it does so far — **Kill**
/// arrives at T4.3 and **Notify** at T5.4 — and until then an **Effect** this cannot perform is a
/// **Refusal**, never a silent skip. Claiming to have done something is the one failure a person
/// cannot see.
struct Effector {
    /// The application the bar took the keyboard from, which is where a **Paste** hands it back
    /// (`Focus`).
    ///
    /// Nothing when nothing took it. That is the terminal path — `Starkit run youtube <url>` never
    /// activates anything, so the application in front is already the one the paste should land in,
    /// and there is no focus to restore before it.
    private let previous: NSRunningApplication?

    init(handingFocusBackTo previous: NSRunningApplication? = nil) {
        self.previous = previous
    }

    /// Stops at the first **Effect** it cannot perform, leaving the ones before it done.
    ///
    /// The **Effects** after a failed one were decided on the assumption that it happened, so
    /// carrying on would be performing a decision nobody made.
    func perform(_ effects: [Effect]) throws(Refusal) {
        for effect in effects {
            switch effect {
            case .open(let app): try open(app)
            case .paste(let text): try paste(text)
            case .kill, .notify:
                throw Refusal("Starkit cannot perform \(effect) yet.")
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
