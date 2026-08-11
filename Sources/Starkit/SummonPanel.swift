import AppKit
import StarkitCore

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
/// What it holds is a field and the **Manifests** that match what has been typed into it. Deciding
/// *which* those are is C2's rule and lives in `Keyword`; running one is not C1's business at all,
/// which is what `run` hands out.
@MainActor
final class SummonPanel: NSObject, NSTextFieldDelegate {
    /// Wide enough for a **Keyword** and the **Input** after it, short enough to read as a bar
    /// rather than a window.
    private static let width: CGFloat = 680

    /// The mark and the field. Also the whole panel when nothing matches, which is the shape a
    /// person sees least often and the one every other shape is measured from.
    private static let header: CGFloat = 64

    /// One matched **Manifest**. Smaller than the header on purpose: the field is what you are
    /// doing and the list is what you are choosing from, and they should not read as equals.
    private static let row: CGFloat = 40

    /// Below the last row, so it is not clipped in half by the corner it sits in.
    private static let footer: CGFloat = 8

    /// How many rows the panel will grow to hold.
    ///
    /// Not a scrolling list. Starkit is for a handful of **Scripts** (five in MVP), so the cap
    /// exists to bound the window rather than to page through it — the way past the eighth match is
    /// to type, which is what the field is for. It matters again at T2.5, where a selection that
    /// can move has to be able to move onto a row that is not shown.
    private static let mostRows = 8

    /// The periwinkle square the carambola sits on, and the gap after it.
    private static let chip: CGFloat = 30
    private static let margin: CGFloat = 18

    /// Where the typed text starts — and where a row's name starts, so the column you read is the
    /// column you are typing into.
    private static let leading: CGFloat = margin + chip + 14

    private let panel: KeyablePanel
    private let field: NSTextField
    /// The mark and the field, kept together so the panel growing downwards moves neither.
    private let head: NSView
    private let list: ListView

    /// What ↩ does with the **Manifest** it selected and the **Input** typed after the **Keyword**.
    ///
    /// A callback rather than a **Runner** held here: C1 is the bar — show, hide, narrow, keys — and
    /// building an **Artefact** and performing **Effects** is C5, C4 and C7's work in that order.
    /// Giving the panel a **Toolchain** would put the whole spine behind the one component whose job
    /// is to be on screen in 50 ms.
    var run: ((Manifest, String) -> Void)?

    /// Every **Script** Starkit knows about, which is not the same as every **Script** it can run
    /// (F2). Assigned by the delegate at launch — from the cache first, then from `describe` — and
    /// narrowed immediately either way, so the panel is already the right height before the first
    /// **Summon** rather than resizing while someone is looking at it.
    var catalogue: [Manifest] = [] {
        didSet { narrow() }
    }

    /// What the **Keyword** typed so far selects, in the order it will be listed.
    private var matches: [Manifest] = []

    /// Which of them ↩ runs. Always the first for now; T2.5 is what lets it move.
    private var selected = 0

    /// When the **Summon** being measured started, or 0 between them.
    private var summonedAt: CFAbsoluteTime = 0

    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.header),
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

        let background = NSVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.header)
        )
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

        head = NSView(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.header))

        let mark = NSView(
            frame: NSRect(
                x: Self.margin,
                y: (Self.header - Self.chip) / 2,
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
        head.addSubview(mark)

        field = NSTextField(string: "")
        // The placeholder in the accent rather than the system's grey: it is the one piece of text
        // here that is Starkit talking rather than the person, and colouring it says so without a
        // second element on screen to say it with. Taken towards the background it sits on, because
        // periwinkle at full strength on cream is a colour rather than a word.
        field.placeholderAttributedString = NSAttributedString(
            string: "Keyword",
            attributes: [
                .font: NSFont.systemFont(ofSize: 21),
                .foregroundColor: Palette.placeholder,
            ]
        )
        field.font = .systemFont(ofSize: 21, weight: .regular)
        field.textColor = .labelColor
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        centre(
            field,
            x: Self.leading,
            width: Self.width - Self.leading - Self.margin,
            in: Self.header
        )
        head.addSubview(field)
        background.addSubview(head)

        list = ListView(
            frame: NSRect(x: 0, y: 0, width: Self.width, height: 0),
            rows: Self.mostRows,
            height: Self.row,
            leading: Self.leading,
            margin: Self.margin
        )
        background.addSubview(list)

        panel.contentView = background
        super.init()

        // Everything typed reaches C1 through the field: `controlTextDidChange` narrows, and
        // `doCommandBy` is where ↩ arrives as a selector rather than as a key (F13).
        field.delegate = self
        panel.cancel = { [weak self] in self?.hide() }
        layOut()
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
        panel.setFrameOrigin(NSPoint(x: -Self.width * 4, y: -Self.header * 4))
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

        // Narrowed before it is placed, because placing depends on how tall it is. Nothing has been
        // typed at this point, so this is the whole **Catalogue** — a bar that lists what you have
        // rather than an empty box you must already know the answer to fill.
        narrow()
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
    /// Emptied *after* it is off screen, in that order: clearing the field narrows the list back to
    /// the whole **Catalogue** and shrinks the panel, and doing that first would show a bar
    /// collapsing on its way out.
    func hide() {
        summonedAt = 0
        panel.orderOut(nil)
        NSApp.hide(nil)
        field.stringValue = ""
        narrow()
    }

    /// ↩ — run what is selected, and get out of the way first.
    ///
    /// The bar leaves before the run starts. That is what makes ↩ read as finished: T1.5 measured a
    /// single **Open** blocking for up to 4.9 s on a cold Electron application, and a bar still on
    /// screen for four seconds after ↩ is a hang, whichever thread it is waiting on. Hiding is also
    /// what hands the keyboard back (T2.2), which is what **Paste** needs to have already happened
    /// when it fires at T5.3. T5.4 is what changes this order, because a spinner is a reason to
    /// stay.
    ///
    /// The **Keyword** run is the **Manifest**'s and not what was typed: `wo` selects Work and Work
    /// is what runs.
    private func accept() {
        guard matches.indices.contains(selected) else { return }
        let manifest = matches[selected]
        // Read before hiding, which clears the field.
        let input = Keyword.split(field.stringValue).input
        hide()
        run?(manifest, input)
    }

    /// Narrow the list to what has been typed, and grow or shrink the panel to hold the result (F3).
    private func narrow() {
        matches = Keyword.matches(Keyword.split(field.stringValue).keyword, in: catalogue)
        selected = 0
        list.present(Array(matches.prefix(Self.mostRows)), selected: selected)
        fit()
    }

    /// Grow the panel downwards to hold the rows, keeping its top edge where it was.
    ///
    /// The field must not move while someone is typing into it, so the height changes at the bottom
    /// and the origin moves to compensate — an `NSWindow` frame is measured from its bottom-left,
    /// which is the corner that has to give.
    private func fit() {
        let shown = min(matches.count, Self.mostRows)
        let height = Self.header + (shown == 0 ? 0 : CGFloat(shown) * Self.row + Self.footer)
        guard height != panel.frame.height else { return }

        var frame = panel.frame
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        panel.setFrame(frame, display: panel.isVisible)
        layOut()
    }

    /// The head at the top, the list under it, filling whatever is left.
    ///
    /// Explicit rather than by `autoresizingMask`, because both would have to be flexible in the
    /// same direction — the head keeping its distance from the top and the list absorbing the
    /// change — and autoresizing splits a delta between everything flexible instead of giving it to
    /// the one that asked. Two frames set from one number is less code than the masks that would
    /// have to be right.
    private func layOut() {
        guard let content = panel.contentView else { return }
        head.frame = NSRect(
            x: 0,
            y: content.bounds.height - Self.header,
            width: content.bounds.width,
            height: Self.header
        )
        list.frame = NSRect(
            x: 0,
            y: 0,
            width: content.bounds.width,
            height: content.bounds.height - Self.header
        )
    }

    /// Centred, a fifth of the way down, on the screen being looked at.
    ///
    /// Placed at every **Summon** rather than once, because the answer changes: screens come and
    /// go, and the one with the keyboard on it is wherever the last window was focused.
    ///
    /// The *top* is what is a fifth of the way down, not the panel — the bar should be in the same
    /// place whether it came up listing five **Scripts** or none.
    private func place() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: area.midX - Self.width / 2,
                y: area.maxY - area.height / 5 - panel.frame.height
            )
        )
    }

    private func milliseconds(since start: CFAbsoluteTime) -> String {
        String(format: "%.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000)
    }
}

extension SummonPanel {
    /// The only place F3 is on the clock — one keystroke to a narrowed list, budget one frame.
    /// Narrowing also happens at launch and on hide, and neither is anybody waiting.
    func controlTextDidChange(_ notification: Notification) {
        let start = CFAbsoluteTimeGetCurrent()
        narrow()
        report("   \(matches.count) of \(catalogue.count) Scripts in \(milliseconds(since: start))")
    }

    /// F13 inside the field: the selector Cocoa names for the key, never the key itself.
    ///
    /// ↩ is the one this task needs. ↑/↓ and ⌃N/⌃P arrive at T2.5 through this same door, which is
    /// the point of using it for ↩ now — a keycode here would be code written to be deleted.
    /// Escape is not handled here on purpose: the field editor passes `cancelOperation:` up the
    /// responder chain on its own, and the window is where it lands.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        accept()
        // Taken even when nothing matched. There is nothing to run, and the alternative is the
        // field editor beeping at a person who can already see the list is empty.
        return true
    }
}

/// The rows under the field, one per matched **Manifest**.
///
/// Flipped, so a row's y is its distance from the field rather than from the bottom of a panel
/// whose height changes with every keystroke.
///
/// The rows are built once and reused, which is the panel's own reasoning (T2.2) one level down:
/// F3's budget is a single frame, and a view constructed while someone is typing is a view built at
/// the worst moment. What changes per keystroke is which rows carry a **Manifest**.
private final class ListView: NSView {
    private let rows: [RowView]

    init(frame: NSRect, rows count: Int, height: CGFloat, leading: CGFloat, margin: CGFloat) {
        rows = (0..<count).map { index in
            RowView(
                frame: NSRect(x: 0, y: CGFloat(index) * height, width: frame.width, height: height),
                leading: leading,
                margin: margin
            )
        }
        super.init(frame: frame)
        for row in rows {
            row.isHidden = true
            addSubview(row)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    override var isFlipped: Bool { true }

    func present(_ manifests: [Manifest], selected: Int) {
        for (index, row) in rows.enumerated() {
            row.isHidden = index >= manifests.count
            guard index < manifests.count else { continue }
            row.show(manifests[index], selected: index == selected)
        }
    }

    /// The hairline between the field and the first row.
    ///
    /// The panel's own edge colour, because it is the same line seen from the inside — and drawn
    /// rather than set on a layer for the reason `Wash` is. Nothing is drawn when nothing matched,
    /// because there is no height to draw it in: that shape is the header alone.
    override func draw(_ dirtyRect: NSRect) {
        let hairline = NSBezierPath()
        hairline.move(to: NSPoint(x: 0, y: 0.5))
        hairline.line(to: NSPoint(x: bounds.width, y: 0.5))
        hairline.lineWidth = 1
        Palette.edge.setStroke()
        hairline.stroke()
    }
}

/// One matched **Manifest**: the name it is known by, and the **Keyword** that reaches it.
///
/// The name lines up under the typed text rather than under the mark, so the column you read is the
/// column you are typing into. The **Keyword** sits at the far end, monospaced, because it answers
/// a different question — not "what is this" but "what do I type" — and it is the only text in the
/// bar that is a thing to be typed rather than a thing to be read.
private final class RowView: NSView {
    private let name = NSTextField(labelWithString: "")
    private let keyword = NSTextField(labelWithString: "")
    private var selected = false

    /// How much of the row the **Keyword** may take before the name starts being truncated for it.
    private static let keywordWidth: CGFloat = 180

    init(frame: NSRect, leading: CGFloat, margin: CGFloat) {
        super.init(frame: frame)

        // `labelColor` and `secondaryLabelColor`, not the palette. Palette is explicit that it does
        // not replace the system's text colours: those already answer light and dark correctly, and
        // a periwinkle name would be a legibility bug on whichever appearance was not being looked
        // at while choosing it. The palette's job here is the band behind the selected row.
        name.font = .systemFont(ofSize: 15)
        name.textColor = .labelColor
        keyword.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        keyword.textColor = .secondaryLabelColor
        keyword.alignment = .right
        for label in [name, keyword] {
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }

        let room = frame.width - leading - margin - Self.keywordWidth - 12
        centre(name, x: leading, width: room, in: frame.height)
        centre(
            keyword,
            x: frame.width - margin - Self.keywordWidth,
            width: Self.keywordWidth,
            in: frame.height
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    func show(_ manifest: Manifest, selected: Bool) {
        name.stringValue = manifest.name
        keyword.stringValue = manifest.keyword
        if self.selected != selected {
            self.selected = selected
            needsDisplay = true
        }
    }

    /// The band behind the selected row — the accent, resolved per appearance, inset far enough to
    /// read as a row inside the bar rather than as a second bar.
    override func draw(_ dirtyRect: NSRect) {
        guard selected else { return }
        let band = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 10, dy: 3),
            xRadius: 8,
            yRadius: 8
        )
        Palette.selection.setFill()
        band.fill()
    }
}

/// Give a label a frame exactly one line of its own font tall, and centre that frame.
///
/// An unbezeled `NSTextField` draws its text at the top of its frame rather than in the middle of
/// it, so a frame taller than the text puts the text high — which is what a taller frame centred
/// here would look like, and did at T2.2 before the header field was sized this way. Every label in
/// the bar is unbezeled, so all of them go through here.
private func centre(_ field: NSTextField, x: CGFloat, width: CGFloat, in height: CGFloat) {
    let line = (field.font?.ascender ?? 0) - (field.font?.descender ?? 0)
    field.frame = NSRect(
        x: x,
        y: ((height - line) / 2).rounded(),
        width: width,
        height: line.rounded(.up)
    )
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
