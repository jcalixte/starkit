import AppKit

/// The menu bar item — the only ambient signal Starkit emits.
///
/// There is no notification, no dock badge, and no window that appears on its own: if something
/// is wrong, this icon is where it shows. That makes the broken state load-bearing rather than
/// decorative, so it is deliberately a different *symbol* and not merely a tint — a red-tinted
/// version of the same glyph is invisible at menu bar size and in a light menu bar.
@MainActor
final class MenuBarStatus {
    /// The things that can be broken on their own, one per component that reports here.
    ///
    /// Kept apart rather than collapsed into a single reason, because they fail independently and
    /// at the same moment: a machine with no `bun` on it can also be a machine where Script Kit
    /// still holds ⌃⌘K, and whichever was written second would otherwise erase the first. Losing
    /// the chord conflict that way is precisely the silence F8 exists to prevent.
    ///
    /// `CaseIterable` so the menu is ordered by declaration and not by whatever a dictionary says.
    enum Concern: CaseIterable {
        /// C3 could not take ⌃⌘K, so nothing can summon the bar.
        case hotKey
        /// C12 or C5 gave way, so a **Script** will fail when it is reached for.
        case scripts
    }

    private let item: NSStatusItem
    private var problems: [Concern: String] = [:]

    init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = NSMenu()
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
        rebuildMenu()
    }

    /// Rebuilt on every state change rather than mutated, so the reason shown can never be a
    /// stale copy of a problem that has since been fixed.
    private func rebuildMenu() {
        let menu = NSMenu()
        for reason in reasons {
            let header = NSMenuItem(title: reason, action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
        }
        if !reasons.isEmpty { menu.addItem(.separator()) }
        menu.addItem(
            withTitle: "Quit Starkit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
    }
}
