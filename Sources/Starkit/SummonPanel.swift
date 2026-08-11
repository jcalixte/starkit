import AppKit

/// C1 — the bar itself: one panel, built at launch, shown and hidden forever after.
///
/// Built once because F1's budget is 50 ms from ⌃⌘K and a window is the expensive part of showing
/// one. Constructing it lazily would put that cost on the first **Summon** of a session, which is
/// the one a person waits for having just booted — so it is paid at launch, where nothing is
/// waiting, and every **Summon** after is an `orderFront`.
///
/// The panel takes activation. T0.5 established why and it is not a preference: macOS routes keys
/// to the *active* application's key window, so a panel belonging to an inactive application can be
/// on screen and still receive nothing. What that costs is a focus to hand back, which `hide` does
/// here and C7 will do again before **Paste** (`DESIGN.md` §9).
///
/// The view inside is a field and nothing else. The list, the filtering and ↩ arrive at T2.4 —
/// what this holds is the window they will live in.
@MainActor
final class SummonPanel {
    /// Wide enough for a **Keyword** and the **Input** after it, short enough to read as a bar
    /// rather than a window. This is the header only: T2.4's list attaches beneath it, with the
    /// hairline that separates them, and the panel grows downwards to hold it.
    private static let size = NSSize(width: 680, height: 64)

    /// The periwinkle square the carambola sits on, and the gap after it.
    private static let chip: CGFloat = 30
    private static let margin: CGFloat = 18

    private let panel: KeyablePanel
    private let field: NSTextField

    /// When the **Summon** being measured started, or 0 between them.
    private var summonedAt: CFAbsoluteTime = 0

    init() {
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            // Borderless, via a style mask that names no chrome. T0.5 tried `.titled` with a
            // transparent titlebar first and the field laid out inside `contentLayoutRect` came out
            // with a negative height — a first responder with nowhere to draw is indistinguishable
            // from a broken keyboard.
            //
            // `.nonactivatingPanel` does not conflict with activating deliberately. It stops a
            // *click* on the panel from activating Starkit, which is still what we want: the only
            // thing that should ever bring this application forward is ⌃⌘K.
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        // Not hidden when Starkit stops being active. The spike set this the same way for its own
        // reasons, and the design needs it: at T5.4 a **Script** runs with the bar still up, and
        // an **Open** it performs activates another application. Auto-hiding would take the bar
        // away mid-run, spinner and all. Dismissal stays something asked for — ⌃⌘K or Escape.
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // It should be reachable from whichever space is in front, including over a full-screen
        // application, because "there every time I reach for it" (G2) is not qualified by where you
        // happen to be.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true

        // The wash and the edge are drawn rather than set on the layer. A `CALayer`'s colours are
        // resolved once, so a panel built in one appearance keeps that appearance's cream after the
        // machine switches to the other — and this window is built at launch and never rebuilt,
        // which is exactly the case that goes wrong. Drawing resolves them every time instead.
        let wash = Wash(frame: background.bounds)
        wash.autoresizingMask = [.width, .height]
        background.addSubview(wash)

        let mark = NSView(
            frame: NSRect(
                x: Self.margin,
                y: (Self.size.height - Self.chip) / 2,
                width: Self.chip,
                height: Self.chip
            )
        )
        mark.wantsLayer = true
        mark.layer?.backgroundColor = Palette.accent.cgColor
        mark.layer?.cornerCurve = .continuous
        mark.layer?.cornerRadius = 9
        // Cream on periwinkle rather than the fruit's own yellow on the blur: at 20pt over a
        // material that could be anything, the palette's creams have no contrast to spend. The chip
        // is what gives the glyph a background it can be light against, and it is the same mark as
        // the menu bar's, which is the point of them matching.
        let glyph = NSImageView(image: Carambola.image(box: 20, colour: Palette.fruit))
        glyph.frame = NSRect(x: (Self.chip - 20) / 2, y: (Self.chip - 20) / 2, width: 20, height: 20)
        mark.addSubview(glyph)
        background.addSubview(mark)

        let leading = Self.margin + Self.chip + 14
        field = NSTextField(string: "")
        // The placeholder in the accent rather than the system's grey: it is the one piece of text
        // here that is Starkit talking rather than the person, and colouring it says so without a
        // second element on screen to say it with.
        field.placeholderAttributedString = NSAttributedString(
            string: "Keyword",
            attributes: [
                .font: NSFont.systemFont(ofSize: 21),
                .foregroundColor: Palette.accent.withAlphaComponent(0.75),
            ]
        )
        field.font = .systemFont(ofSize: 21, weight: .regular)
        field.textColor = .labelColor
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        // Sized to one line of its own font, then centred as a whole. An unbezeled `NSTextField`
        // draws its text at the top of its frame rather than in the middle of it, so a frame taller
        // than the text puts the text high — which is what a taller frame centred here would look
        // like, and did.
        let line = (field.font?.ascender ?? 0) - (field.font?.descender ?? 0)
        field.frame = NSRect(
            x: leading,
            y: ((Self.size.height - line) / 2).rounded(),
            width: Self.size.width - leading - Self.margin,
            height: line.rounded(.up)
        )
        field.autoresizingMask = [.width]
        background.addSubview(field)

        panel.contentView = background
        panel.cancel = { [weak self] in self?.hide() }
        warm()

        // Activation is asynchronous — it travels through the window server — so `isKeyWindow` read
        // on the turn of the run loop that shows the panel says nothing about whether it can be
        // typed into. This is the only honest place to time that from, and F1's budget is about
        // being *there*, so both numbers get reported rather than one standing in for the other.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.summonedAt > 0 else { return }
                report("   ready to type after \(self.milliseconds(since: self.summonedAt))")
                self.summonedAt = 0
            }
        }
    }

    /// Show the panel once, invisibly, so the first real **Summon** is not the one that pays for it.
    ///
    /// Building the window at launch was not enough on its own: measured at T2.2, the first
    /// **Summon** of a session cost 25.3 ms to appear against a 7 ms median, and 60.9 ms to become
    /// key against 13 — the window server, the material and the first activation all charge once. A
    /// pass through `orderFront` at launch is where that charge belongs, for the same reason the
    /// window itself is built here rather than lazily.
    ///
    /// Transparent *and* off screen, because either alone would risk a frame of a bar appearing at
    /// launch for no reason a person asked for.
    private func warm() {
        let hidden = panel.alphaValue
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: -Self.size.width * 4, y: -Self.size.height * 4))
        panel.orderFront(nil)
        panel.orderOut(nil)
        panel.alphaValue = hidden
    }

    /// ⌃⌘K when it is up means put it away.
    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        let start = CFAbsoluteTimeGetCurrent()
        summonedAt = start

        place()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        // Set after the field editor exists, because it *is* the field editor's — an `NSTextField`
        // has no caret of its own to colour.
        (panel.fieldEditor(false, for: field) as? NSTextView)?.insertionPointColor = Palette.accent

        report("⌃⌘K — on screen after \(milliseconds(since: start))")
    }

    /// Put the bar away and give the keyboard back to whoever had it.
    ///
    /// `NSApp.hide` rather than only ordering the panel out. Starkit activated itself to be typed
    /// into, and an `.accessory` application left active with no window on screen holds the
    /// keyboard away from the application the person was actually using — they would press a key
    /// and have it go nowhere. Hiding is what returns activation, and it is the same debt C7 pays
    /// before a **Paste**.
    func hide() {
        summonedAt = 0
        field.stringValue = ""
        panel.orderOut(nil)
        NSApp.hide(nil)
    }

    /// Centred, a fifth of the way down, on the screen being looked at.
    ///
    /// Placed at every **Summon** rather than once, because the answer changes: screens come and
    /// go, and the one with the keyboard on it is wherever the last window was focused.
    private func place() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: area.midX - Self.size.width / 2,
                y: area.maxY - area.height / 5 - Self.size.height
            )
        )
    }

    private func milliseconds(since start: CFAbsoluteTime) -> String {
        String(format: "%.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)
    }
}

/// The cream over the blur and the outline around it, both resolved against whichever appearance is
/// current at the moment of drawing.
///
/// The wash goes *over* the material rather than replacing it: `.hudWindow` is what makes the bar
/// sit in front of a desktop instead of on top of it, and a flat fill would spend that for the sake
/// of a colour.
private final class Wash: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Inset by half the stroke, so the outline lands inside the panel instead of being clipped
        // in half by the corner radius it is tracing.
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 15.5,
            yRadius: 15.5
        )
        Palette.wash.setFill()
        outline.fill()
        Palette.edge.setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }
}

/// A borderless panel that can still take the keyboard.
///
/// `NSWindow.canBecomeKey` is false without a titlebar, and `NSPanel` is documented to override
/// that — but T0.5 stopped depending on the documentation and stated it, and one line here keeps
/// the question closed.
private final class KeyablePanel: NSPanel {
    /// What Escape does. Held here because Escape reaches the window rather than the view: the
    /// field editor passes `cancelOperation:` up the responder chain when it has nothing of its
    /// own to cancel.
    var cancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    /// F13 in miniature — the Cocoa action selector, never a keycode. ⌘. arrives here too, for
    /// free, and so will anything else a person has bound to cancelling.
    override func cancelOperation(_ sender: Any?) {
        cancel?()
    }
}
