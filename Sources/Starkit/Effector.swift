import AppKit
import ApplicationServices
import Carbon.HIToolbox
import StarkitCore

struct Effector {
    private let previous: NSRunningApplication?

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
            case .browse(let url): try browse(url)
            case .kill(let app): try kill(app)
            case .copy(let text): copy(text)
            case .paste(let text): try paste(text)
            case .notify(let message): notify(message)
            }
        }
    }

    /// Where AppKit is read, from wherever this was called.
    ///
    /// **Effects** are performed off the main thread — an **Open** blocks until a launch is under way
    /// — but `NSWorkspace` and `NSRunningApplication` are AppKit's, and C8 gathers its **Context** on
    /// the main actor for exactly that reason. This is the same rule, applied on the way out.
    ///
    /// Inline when this already *is* the main thread: the terminal path performs its **Effects**
    /// there, and a hop would be the thread waiting on itself.
    ///
    /// Not `MainActor.assumeIsolated`, whose result must be `Sendable`: an `NSRunningApplication` is
    /// not, and reading the list is most of what this exists for.
    private func onMain<T>(_ read: () -> T) -> T {
        if Thread.isMainThread { return read() }
        return DispatchQueue.main.sync(execute: read)
    }

    /// Bring an application to the front, launching it if it is not running.
    ///
    /// `fullPath(forApplication:)` is deprecated and kept deliberately: the replacement Apple names in
    /// the warning, `urlForApplication(withBundleIdentifier:)`, answers a different question —
    /// **Open** carries the name a person reads in the Finder, and this is LaunchServices' own
    /// case-insensitive answer to it, wherever the application is installed.
    private func open(_ app: String) throws(Refusal) {
        guard let path = onMain({ NSWorkspace.shared.fullPath(forApplication: app) }) else {
            throw Refusal(
                "There is no application called \"\(app)\" on this machine.",
                detail: "Open takes the name you see in the Finder, not a path or a bundle id."
            )
        }
        guard onMain({ NSWorkspace.shared.open(URL(fileURLWithPath: path)) }) else {
            throw Refusal("Starkit could not open \(app).", detail: "It is at \(path).")
        }
    }

    /// Hand a URL to LaunchServices, which gives it to whatever registered the scheme.
    ///
    /// `URL(string:)` accepts almost anything, including a bare `Slack`, which would then open in a
    /// browser as a relative path and look like an **Open** that went wrong. Requiring a scheme makes
    /// that a **Refusal** instead.
    private func browse(_ url: String) throws(Refusal) {
        guard let target = URL(string: url), target.scheme != nil else {
            throw Refusal(
                "\"\(url)\" is not a URL Starkit can open.",
                detail: "Browse takes a whole URL, scheme and all: https://example.com, or a "
                    + "scheme an application registered, like obsidian://. An application by name "
                    + "is an Open."
            )
        }
        guard onMain({ NSWorkspace.shared.open(target) }) else {
            throw Refusal(
                "Starkit could not open \(url).",
                detail: "No application on this machine answers to "
                    + "\(target.scheme.map { "\($0)://" } ?? "that scheme")."
            )
        }
        report("   Browse — \(url)")
    }

    /// End an application without asking it, and without letting it ask you.
    ///
    /// `forceTerminate`, never `terminate()`: no save dialog and no chance for the application to
    /// refuse, and it needs no Accessibility grant.
    ///
    /// Nothing running by that name is done, not refused — one that quit between the gather and here
    /// has satisfied the **Kill**.
    ///
    /// Matched twice: `localizedName` is the name in the machine's language, so on a French system
    /// Calculator runs as Calculatrice and `Kill("Calculator")` matched nothing. Comparing bundle URLs
    /// as well closes that seam; the name match stays because it needs nothing from disk.
    private func kill(_ app: String) throws(Refusal) {
        let targets = onMain { () -> [NSRunningApplication] in
            let bundle = NSWorkspace.shared.fullPath(forApplication: app)
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
            return NSWorkspace.shared.runningApplications.filter {
                $0.localizedName?.caseInsensitiveCompare(app) == .orderedSame
                    || (bundle != nil && $0.bundleURL?.standardizedFileURL == bundle)
            }
        }

        // The third lock, and the only one that holds for every **Script**: `clean.gleam` and C8 both
        // guard names arriving from a **Context**, but any **Script** can write the word itself.
        //
        // Both names Starkit goes by: the application's when it is the bundle in the menu bar, and the
        // process's on the terminal path, where the binary has no bundle. Neither is hard-coded — a
        // guard spelling "Starkit" stops being true the day the product is renamed.
        let names = onMain {
            [NSRunningApplication.current.localizedName, ProcessInfo.processInfo.processName]
        }
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
            guard onMain({ target.forceTerminate() }) else {
                throw Refusal(
                    "Starkit could not kill \(app).",
                    detail: "It is process \(target.processIdentifier) and it is still running."
                )
            }
        }
        report("   Kill — \(app)\(targets.count > 1 ? " (\(targets.count) of them)" : "")")
    }

    /// Put the text on the clipboard and stop. It replaces whatever was there, including the **Seed**
    /// the text may have been derived from.
    private func copy(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        report("   Copy — \(text.count) characters to the clipboard")
    }

    /// Put the text on the clipboard, give the keyboard back, then press ⌘V for the person.
    ///
    /// The middle step is load-bearing: the **Shelf** had to activate to be typed into, so a keystroke
    /// synthesised while it still holds activation lands in the bar.
    ///
    /// The clipboard is written *before* the Accessibility check, so that the sentence the **Refusal**
    /// ends on — press ⌘V yourself — is true when it is read.
    private func paste(_ text: String) throws(Refusal) {
        let start = CFAbsoluteTimeGetCurrent()

        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)

        guard AXIsProcessTrusted() else {
            // Asked for at the moment it is needed rather than at launch. The grant reaches a process
            // already running, so the fix from here is granting it and pressing ↩ again — no relaunch.
            let ask = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(ask as CFDictionary)
            throw Refusal(
                "Starkit needs Accessibility before it can paste.",
                detail: "System Settings → Privacy & Security → Accessibility → Starkit. "
                    + "The text is on the clipboard; ⌘V pastes it by hand in the meantime."
            )
        }

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

        let into = onMain { NSWorkspace.shared.frontmostApplication?.localizedName }
        report(
            "   Paste — \(text.count) characters into \(into ?? "whatever is in front")"
                + String(format: " in %.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)
        )
    }

    /// Wait for the application the bar took the keyboard from to have it back.
    ///
    /// The deadline is for the notification that never comes — pasting into the wrong window is bad,
    /// hanging a run on a notification is worse.
    ///
    /// This blocks, and must never be called on the main thread: the run loop the notification arrives
    /// on has to keep turning.
    private func handFocusBack() {
        guard let previous, !onMain({ previous.isActive }) else { return }

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

        onMain { _ = previous.activate() }
        if arrived.wait(timeout: .now() + 0.3) == .timedOut {
            let name = onMain { previous.localizedName }
            report("   \(name ?? "It") did not come back in 300 ms — pasting anyway.")
        }
    }
}

/// Who the keyboard belongs to when it is not the bar's.
///
/// Must be sampled as it happens, never read at **Paste** time: by then the frontmost application is
/// Starkit. Pinning it when the **Shelf** becomes active also keeps a **Script** that **Opens** and
/// then **Pastes** from pasting into the application it just launched.
@MainActor
final class Focus {
    private(set) var previous: NSRunningApplication?

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
