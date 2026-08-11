import AppKit
import ApplicationServices
import Carbon.HIToolbox

// Throwaway. T0.5 in tasks/plan.md, pulled ahead of everything else it would sit under because it
// is the one thing that could invalidate a design decision rather than merely need more work: the
// Paste Effect is load-bearing for Youtube and Link, 2 of 5 Scripts.
//
// What it has to prove, from a bundle signed the way Starkit is signed:
//   - a panel can hold the keyboard while another application stays frontmost
//   - after the panel hides, that application gets the keystroke — not us
//   - a synthesised ⌘V actually lands, and inside the 200 ms of DESIGN.md §4, F7
//
// The first run answered the last two and refuted the first, which is why there are now two summon
// modes to compare. A `.nonactivatingPanel` in an application that is not active never becomes key
// — macOS routes keys to the active application's key window, so an unactivated panel gets nothing
// to type into. The panel therefore has to activate us, and Paste has to hand activation back. That
// hand-back is what the activating mode measures, and it is the mode the Shelf will ship.
//
// It proves nothing about the Shelf's own Accessibility grant: this bundle has its own identifier
// and therefore its own grant. That is on purpose — T5.5 still gets to watch a first grant happen.
//
// Delete `Sources/PasteSpike/`, the target in `Package.swift`, and `scripts/spike-paste.sh` at
// Checkpoint A. Findings belong in `docs/`, not in this file's history.

private let logPath = "/tmp/starkit-paste-spike.log"

/// Both to stderr and to a file: the app is launched with `open`, so stderr goes nowhere a person
/// can see, and the interesting moments happen while the panel is hidden and TextEdit is frontmost.
private func note(_ message: String) {
    let stamp = DateFormatter()
    stamp.dateFormat = "HH:mm:ss.SSS"
    let line = "\(stamp.string(from: Date())) \(message)\n"

    FileHandle.standardError.write(Data(line.utf8))

    let url = URL(fileURLWithPath: logPath)
    if !FileManager.default.fileExists(atPath: logPath) {
        FileManager.default.createFile(atPath: logPath, contents: nil)
    }
    guard let handle = try? FileHandle(forWritingTo: url) else { return }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: Data(line.utf8))
    try? handle.close()
}

private func millis(since start: CFAbsoluteTime) -> String {
    String(format: "%.1f", (CFAbsoluteTimeGetCurrent() - start) * 1000)
}

/// A borderless panel that can still take the keyboard.
///
/// `NSWindow.canBecomeKey` is false without a titlebar, and `NSPanel` is documented to override
/// that — but the whole point of a spike is to stop depending on documentation, and one line here
/// removes the question entirely.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class Spike: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private var item: NSStatusItem!
    private var panel: NSPanel!
    private var field: NSTextField!

    /// The application to paste into: the last one to be frontmost that was not us.
    ///
    /// Sampled continuously rather than read at summon time. Reading it late is what the obvious
    /// implementation does and it is wrong — by then the panel may already have activated us, and
    /// the answer would be "PasteSpike".
    private var previous: NSRunningApplication?

    /// Set when ↩ is pressed, so every later measurement is against the same origin.
    private var pressedReturnAt: CFAbsoluteTime = 0
    private var activationObserver: NSObjectProtocol?
    /// Non-nil only while waiting for focus to come back; doubles as the "not finished yet" flag,
    /// since the notification and the deadline race and either may arrive first.
    private var pendingDeadline: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        note("── spike launched, pid \(getpid()), accessibility trusted = \(AXIsProcessTrusted())")
        if !AXIsProcessTrusted() {
            // No relaunch needed, unlike the event tap in cmd-tab: the first run granted the
            // permission mid-life and the very next ⌘V went through. Asked for here, then used
            // when it arrives.
            note("   asking for Accessibility — the grant applies to this process as it lands")
            let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(prompt as CFDictionary)
        }

        watchFrontmostApplication()
        buildStatusItem()
        buildPanel()
    }

    private func watchFrontmostApplication() {
        let mine = ProcessInfo.processInfo.processIdentifier
        if let current = NSWorkspace.shared.frontmostApplication, current.processIdentifier != mine {
            previous = current
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
            MainActor.assumeIsolated { self?.previous = app }
        }
    }

    private func buildStatusItem() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // A title, not the carambola: two menu bar items that look alike during a spike is a way
        // to test the wrong app for twenty minutes.
        item.button?.title = "⌘V"

        let menu = NSMenu()
        // Two modes, one difference: whether the panel activates us before taking the keyboard.
        // Kept side by side so the cost of handing activation back is a comparison rather than an
        // assertion.
        menu.addItem(
            withTitle: "Summon — activating (the shippable one)",
            action: #selector(summonActivating),
            keyEquivalent: ""
        ).target = self
        menu.addItem(
            withTitle: "Summon — non-activating (cannot be typed into)",
            action: #selector(summonNonActivating),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        item.menu = menu
    }

    private func buildPanel() {
        let size = NSSize(width: 460, height: 56)
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size),
            // `.nonactivatingPanel` in both modes. It does not stop us activating deliberately —
            // it stops a *click on the panel* from activating us, which is still what we want.
            //
            // Borderless: the first attempt was `.titled` with a transparent titlebar, and laying
            // the field out inside `contentLayoutRect` — which excludes the titlebar — gave it a
            // negative height. A first responder with nowhere to draw looks exactly like a broken
            // keyboard. A launcher has no use for a titlebar anyway.
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        // Deliberately not plain ASCII: a synthesised ⌘V carries whatever is on the clipboard, so
        // if this arrives intact then multi-byte text is not a separate problem to solve later.
        field = NSTextField(string: "starkit paste spike ✓ — é 🍈")
        field.font = .systemFont(ofSize: 18)
        field.isBezeled = false
        field.drawsBackground = false
        // The delegate's command hook, not `target`/`action`. An NSTextField sends its action when
        // editing *ends* as well as on ↩, and the first run pasted twice without anyone pressing
        // anything: the field editor was torn down the instant it was created, because the panel
        // was not key. F13 wants these selectors anyway (DESIGN.md §4).
        field.delegate = self

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        field.frame = NSRect(x: 16, y: 14, width: size.width - 32, height: 28)
        field.autoresizingMask = [.width]
        content.addSubview(field)
        panel.contentView = content
        panel.center()
    }

    @objc private func summonActivating() { summon(activating: true) }
    @objc private func summonNonActivating() { summon(activating: false) }

    private func summon(activating: Bool) {
        note(
            "summon (\(activating ? "activating" : "non-activating")): previous = \(name(previous)),"
                + " frontmost = \(name(NSWorkspace.shared.frontmostApplication))"
        )
        if activating {
            NSApp.activate()
        }
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        field.selectText(nil)
        report("immediately after showing")

        // Activation is asynchronous — it goes through the window server, so reading `isKeyWindow`
        // on the same turn of the run loop says nothing. This is the reading that counts.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            MainActor.assumeIsolated { self?.report("50 ms later — the settled state") }
        }
    }

    private func report(_ when: String) {
        note(
            "  \(when): panel key = \(panel.isKeyWindow), we are active = \(NSApp.isActive),"
                + " frontmost = \(name(NSWorkspace.shared.frontmostApplication)),"
                + " editing = \(panel.firstResponder is NSTextView)"
        )
    }

    func control(
        _ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            pasteIntoPreviousApp()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            note("Escape — hiding, no paste")
            panel.orderOut(nil)
            previous?.activate()
            return true
        default:
            // Logged rather than silently passed on, so a run where ↩ appears to do nothing says
            // whether the keystroke reached the field at all. Without this the two explanations —
            // nobody pressed it, or the delegate hook is not wired — look identical in the log.
            note("key command \(commandSelector) reached the field, not handled here")
            return false
        }
    }

    /// Only to prove that typed characters arrive. F13's real key handling is T2.5, not this.
    func controlTextDidChange(_ notification: Notification) {
        note("typing arrives: \(field.stringValue.count) chars")
    }

    private func pasteIntoPreviousApp() {
        pressedReturnAt = CFAbsoluteTimeGetCurrent()
        let text = field.stringValue
        guard let target = previous else {
            note("↩ with no previous application recorded — nothing to paste into")
            return
        }

        panel.orderOut(nil)

        let board = NSPasteboard.general
        let before = board.changeCount
        board.clearContents()
        board.setString(text, forType: .string)
        note("↩ into \(name(target)): clipboard \(before) → \(board.changeCount), \(text.count) chars")

        // The fork worth measuring. Non-activating mode never took activation away, so there is
        // nothing to wait for; activating mode has to get it back before the keystroke, and the
        // wait is the only part of Paste that can plausibly spend the 200 ms.
        if target.isActive {
            note("  \(name(target)) never lost activation — posting ⌘V straight away")
            postCommandV()
            return
        }

        note("  activating \(name(target)) and waiting for it")
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                app.processIdentifier == target.processIdentifier
            else { return }
            MainActor.assumeIsolated { self?.pasteNow(because: "activation notification") }
        }

        // Observing rather than polling, because polling would block the run loop the notification
        // has to arrive on. The deadline is the fallback for the case where it never fires at all.
        let deadline = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.pasteNow(because: "300 ms deadline, no notification") }
        }
        pendingDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: deadline)

        target.activate()
    }

    private func pasteNow(because reason: String) {
        guard let deadline = pendingDeadline else { return }
        deadline.cancel()
        pendingDeadline = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        note("  focus back after \(millis(since: pressedReturnAt)) ms — \(reason)")
        postCommandV()
    }

    private func postCommandV() {
        guard AXIsProcessTrusted() else {
            note("  not trusted: ⌘V would be swallowed. Grant Accessibility in System Settings.")
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let up = CGEvent(
                keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            note("  CGEvent refused to build the keystroke")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        note(
            "  ⌘V posted \(millis(since: pressedReturnAt)) ms after ↩ "
                + "(F7 allows 200 ms) into \(name(NSWorkspace.shared.frontmostApplication))"
        )
    }

    private func name(_ app: NSRunningApplication?) -> String {
        app?.localizedName ?? "none"
    }
}

let application = NSApplication.shared
let spike = MainActor.assumeIsolated { Spike() }
application.delegate = spike
application.setActivationPolicy(.accessory)
application.run()
