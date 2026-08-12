import AppKit

/// The menu bar item — the only ambient signal Starkit emits.
///
/// The broken state is a different *symbol*, never merely a tint: a red-tinted version of the same
/// glyph is invisible at menu bar size and in a light menu bar.
@MainActor
final class MenuBarStatus: NSObject, NSMenuDelegate {
    /// Kept apart rather than collapsed into a single reason, because they fail independently and at
    /// the same moment — whichever was written second would otherwise erase the first.
    ///
    /// `CaseIterable` so the menu is ordered by declaration and not by whatever a dictionary says.
    enum Concern: CaseIterable {
        /// C3 could not take ⌃⌘K, so nothing can summon the bar.
        case hotKey
        /// C12 or C5 gave way, so a **Script** will fail when it is reached for.
        case scripts
        /// C6 is not watching, so a **Script** saved in Zed will not become real on its own. Kept
        /// apart from `scripts` because nothing is wrong with the **Scripts**: every one already built
        /// still runs, and collapsing the two would hide a compile error behind a stream that failed
        /// to start.
        case watcher
        /// A **Script** the person ran **Refused**. The transient **Concern**: cleared by the next
        /// run that works, because it is about the last run and not about the machine.
        case run
    }

    private let item: NSStatusItem
    private var problems: [Concern: String] = [:]

    /// One menu for the life of the process, refilled rather than replaced. Replacing it is what the
    /// first version did, and it cannot be done while the menu is on screen — which is exactly when
    /// C9's state has to be read (`menuNeedsUpdate`).
    private let menu = NSMenu()

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.delegate = self
        item.menu = menu
        apply()
    }

    /// One sentence, or `nil` for nothing wrong with this **Concern** any more.
    func set(_ reason: String?, for concern: Concern) {
        problems[concern] = reason
        apply()
    }

    private var reasons: [String] { Concern.allCases.compactMap { problems[$0] } }

    private func apply() {
        let description = reasons.isEmpty ? "Starkit" : "Starkit — " + reasons.joined(separator: " ")
        item.button?.image =
            reasons.isEmpty
            ? Carambola.template(accessibilityDescription: description)
            : NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: description
            )
        item.button?.toolTip = description
    }

    /// The menu is built when it opens and at no other time, which is the only moment its contents
    /// are read. That is not a saving: **Start at Login** is a line about something this process
    /// does not own — System Settings, or another process, can turn it off without telling anyone —
    /// so building it on a state change would show whatever was true at the last **Refusal** (T7.2).
    func menuNeedsUpdate(_ menu: NSMenu) {
        fill()
    }

    /// Filled from scratch rather than mutated, so the reason shown can never be a stale copy of a
    /// problem that has since been fixed.
    private func fill() {
        menu.removeAllItems()
        for reason in reasons {
            let header = NSMenuItem(title: reason, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }
        if !reasons.isEmpty { menu.addItem(.separator()) }

        let login = LoginItem.state
        let toggle = NSMenuItem(
            title: login.menuTitle,
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.state = login.isOn ? .on : .off
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Starkit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
    }

    @objc private func toggleLoginItem() {
        LoginItem.flip()
    }
}
