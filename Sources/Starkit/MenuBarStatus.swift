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
        let description = switch state {
        case .ok: "Starkit"
        case .broken(let reason): "Starkit — \(reason)"
        }
        item.button?.image = switch state {
        case .ok: Self.carambola(accessibilityDescription: description)
        case .broken:
            NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: description
            )
        }
        item.button?.toolTip = description
        rebuildMenu()
    }

    /// The star fruit, drawn rather than loaded.
    ///
    /// The shape is Tabler's `carambola` (MIT), whose outline is one closed path of quadratic
    /// curves. `NSImage` cannot read an SVG unless it comes out of a compiled asset catalog, and
    /// this bundle is assembled by hand in `build.sh` with no `actool` step — so the path is
    /// transcribed here instead. That also keeps it a template image, which is what lets AppKit
    /// tint it for a light or dark menu bar without a second asset.
    ///
    /// `NSImage(size:flipped:drawingHandler:)` rather than `lockFocus`, so the glyph is redrawn at
    /// whatever backing scale the screen it lands on has.
    private static func carambola(accessibilityDescription: String) -> NSImage {
        // 18pt inside a 24pt bar. The outline fills about four fifths of its own box, so this puts
        // the drawn glyph at roughly the height of the system symbols sitting next to it.
        let box: CGFloat = 18
        // Tabler strokes at 2 units in a 24-unit box. Thinned to 1.6, which matches the weight of
        // the menu bar's own glyphs — at 2 the fruit reads as bolder than everything around it.
        let pen = box * 1.6 / 24

        let image = NSImage(size: NSSize(width: box, height: box), flipped: false) { _ in
            NSColor.black.setStroke()
            carambolaPath(in: box, pen: pen).stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    /// Tabler's path data, verbatim in structure: one `move`, then its relative quadratic curves
    /// and two short horizontal joins, closed.
    ///
    /// `NSBezierPath` gained a quadratic curve only in macOS 14, so each is widened to the cubic it
    /// is equal to — control points at two thirds of the way from each end towards the quadratic's
    /// single control point. Exact, not an approximation.
    private static func carambolaPath(in box: CGFloat, pen: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        var cursor = CGPoint(x: 17.286, y: 21.09)
        path.move(to: cursor)

        func curve(_ cx: CGFloat, _ cy: CGFloat, _ ex: CGFloat, _ ey: CGFloat) {
            let control = CGPoint(x: cursor.x + cx, y: cursor.y + cy)
            let end = CGPoint(x: cursor.x + ex, y: cursor.y + ey)
            path.curve(
                to: end,
                controlPoint1: CGPoint(
                    x: cursor.x + 2 / 3 * (control.x - cursor.x),
                    y: cursor.y + 2 / 3 * (control.y - cursor.y)
                ),
                controlPoint2: CGPoint(
                    x: end.x + 2 / 3 * (control.x - end.x),
                    y: end.y + 2 / 3 * (control.y - end.y)
                )
            )
            cursor = end
        }
        func across(_ dx: CGFloat) {
            cursor.x += dx
            path.line(to: cursor)
        }

        curve(-1.69, 0.001, -5.288, -2.615)
        curve(-3.596, 2.617, -5.288, 2.616)
        curve(-2.726, 0, -0.495, -6.8)
        curve(-9.389, -6.775, 2.135, -6.775)
        across(0.076)
        curve(1.785, -5.516, 3.574, -5.516)
        curve(1.785, 0, 3.574, 5.516)
        across(0.076)
        curve(11.525, 0, 2.133, 6.774)
        curve(2.23, 6.802, -0.497, 6.8)
        path.close()

        // SVG counts y downwards, AppKit upwards. Flip, then fit the 24-unit box into `box` with
        // half a pen width spare on each side — a stroke centred on the outline would otherwise
        // clip at the five points.
        var fit = AffineTransform(translationByX: pen / 2, byY: pen / 2)
        var flip = AffineTransform(scaleByX: (box - pen) / 24, byY: -(box - pen) / 24)
        flip.translate(x: 0, y: -24)
        fit.append(flip)
        path.transform(using: fit)

        path.lineWidth = pen
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        return path
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
