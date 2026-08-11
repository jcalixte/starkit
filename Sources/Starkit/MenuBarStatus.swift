import AppKit

/// The menu bar item — the only ambient signal Starkit emits.
///
/// There is no notification, no dock badge, and no window that appears on its own: if something
/// is wrong, this icon is where it shows. That makes the `.broken` state load-bearing rather than
/// decorative, so it is deliberately a different *symbol* and not merely a tint — a red-tinted
/// version of the same glyph is invisible at menu bar size and in a light menu bar.
@MainActor
final class MenuBarStatus {
    enum State {
        /// Everything Starkit depends on is working.
        case ok
        /// Something is broken and a Script will fail if you reach for it. The reason is shown in
        /// the menu, because an icon can say *that* something is wrong but never *what*.
        case broken(reason: String)
    }

    private let item: NSStatusItem
    private var state: State = .ok

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = NSMenu()
        apply()
    }

    var currentState: State { state }

    func set(_ state: State) {
        self.state = state
        apply()
    }

    private func apply() {
        let (symbol, description) = switch state {
        case .ok: ("square.stack", "Starkit")
        case .broken(let reason): ("exclamationmark.triangle.fill", "Starkit — \(reason)")
        }
        item.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: description
        )
        item.button?.toolTip = description
        rebuildMenu()
    }

    /// Rebuilt on every state change rather than mutated, so the reason shown can never be a
    /// stale copy of a problem that has since been fixed.
    private func rebuildMenu() {
        let menu = NSMenu()
        if case .broken(let reason) = state {
            let header = NSMenuItem(title: reason, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(.separator())
        }
        menu.addItem(
            withTitle: "Quit Starkit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
    }
}
