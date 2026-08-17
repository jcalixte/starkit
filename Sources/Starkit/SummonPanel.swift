import AppKit
import StarkitCore

@MainActor
final class SummonPanel: NSObject, NSTextFieldDelegate {
    private static let width: CGFloat = 680

    private static let header: CGFloat = 64

    private static let row: CGFloat = 40

    private static let footer: CGFloat = 8

    private static let mostRows = 8

    private static let chip: CGFloat = 30
    private static let margin: CGFloat = 18

    private static let leading: CGFloat = margin + chip + 14

    private static let gap: CGFloat = 10

    private static let homeWidth: CGFloat = 200

    private let panel: KeyablePanel
    private let field: NSTextField
    private let keywordChip = KeywordChip()
    private let homeTag = NSTextField(labelWithString: "")
    private let mark = Mark(box: SummonPanel.chip)
    private let head: NSView
    private let list: ListView
    private let messages = MessageView(
        width: SummonPanel.width,
        leading: SummonPanel.leading,
        margin: SummonPanel.margin,
        chip: SummonPanel.chip
    )

    var run: ((_ manifest: Manifest, _ input: String, _ run: Int) -> Void)?

    var create: ((_ keyword: String) -> Void)?

    var delete: ((Manifest) -> Void)?

    var edit: ((Manifest) -> Void)?

    var deletionQuestion: ((Manifest) -> String)?

    var catalogue: [Manifest] = [] {
        didSet { narrow() }
    }

    private enum Stage {
        case keyword
        case input(Manifest)
    }

    private var stage = Stage.keyword

    private var typed = ""

    private var matches: [Manifest] = []

    fileprivate enum Choice {
        case script(Manifest)
        case create(String)
    }

    private var choices: [Choice] = []

    private var selected: Int?

    private var armed: String?

    private var runs = 0

    private var working = false

    private var spoke = false

    private var message: String?

    private var summonedAt: CFAbsoluteTime = 0

    private var clicksElsewhere: Any?

    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.header),
            // `.titled` with a transparent titlebar gives the field a negative height inside
            // `contentLayoutRect`. `.nonactivatingPanel` stops a *click* on the panel from activating
            // Starkit, so only ⌃⌘K brings it forward.
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        // Must stay false: a **Script** runs with the bar still up, and both an **Open** it performs
        // and the hand-back before a **Paste** activate another application.
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
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

        // Drawn rather than set on the layer: a `CALayer`'s colours are resolved once, and this
        // window is built at launch and never rebuilt.
        let wash = Wash(frame: background.bounds)
        wash.autoresizingMask = [.width, .height]
        background.addSubview(wash)

        head = NSView(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.header))

        mark.setFrameOrigin(NSPoint(x: Self.margin, y: (Self.header - Self.chip) / 2))
        head.addSubview(mark)

        field = NSTextField(string: "")
        field.placeholderAttributedString = Self.placeholder("Keyword")
        field.font = .systemFont(ofSize: 21, weight: .regular)
        field.textColor = .labelColor
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        head.addSubview(field)

        keywordChip.isHidden = true
        head.addSubview(keywordChip)

        homeTag.isHidden = Toolchain.overriddenHome == nil
        if let elsewhere = Toolchain.overriddenHome {
            homeTag.stringValue = (elsewhere.path as NSString).abbreviatingWithTildeInPath
            homeTag.toolTip = elsewhere.path
            homeTag.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            homeTag.textColor = Palette.aside
            homeTag.alignment = .right
            homeTag.lineBreakMode = .byTruncatingHead
            centre(
                homeTag,
                x: Self.width - Self.margin - Self.homeWidth,
                width: Self.homeWidth,
                in: Self.header
            )
            head.addSubview(homeTag)
        }
        background.addSubview(head)

        list = ListView(
            frame: NSRect(x: 0, y: 0, width: Self.width, height: 0),
            rows: Self.mostRows,
            height: Self.row,
            leading: Self.leading,
            margin: Self.margin
        )
        background.addSubview(list)

        messages.setFrameOrigin(NSPoint(x: 0, y: Self.footer))
        messages.isHidden = true
        background.addSubview(messages)

        panel.contentView = background
        super.init()

        field.delegate = self
        panel.cancel = { [weak self] in
            guard let self else { return }
            if case .input = self.stage { self.stopAsking() } else { self.dismiss() }
        }
        placeField()
        layOut()
        warm()

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

        // An **Open** a **Script** performs deactivates Starkit exactly like a person leaving, so a
        // run in flight is not a **Dismissal** — nor is a bar still holding a message, since
        // `NSWorkspace` activates an application when its *launch* finishes, which can land long after
        // the run that asked for it settled.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.panel.isVisible, !self.working, self.message == nil else {
                    return
                }
                self.dismiss()
            }
        }
    }

    /// Put the panel on screen once, invisibly: the window server, the material and the first
    /// activation each charge once, and the first **Summon** of a session should not pay for them.
    ///
    /// Transparent *and* off screen: either alone risks a frame of a bar appearing at launch.
    private func warm() {
        let alpha = panel.alphaValue
        panel.alphaValue = 0
        panel.setFrameOrigin(NSPoint(x: -Self.width * 4, y: -Self.header * 4))
        panel.orderFront(nil)
        panel.orderOut(nil)
        panel.alphaValue = alpha
    }

    func toggle() {
        if panel.isVisible { dismiss() } else { summon() }
    }

    func summon() {
        let start = CFAbsoluteTimeGetCurrent()
        summonedAt = start

        // Narrowed before it is placed, because placing depends on how tall it is.
        narrow()
        place()
        watchForClicksElsewhere()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        // Must come after the field editor exists: the caret is the editor's, not the field's.
        (panel.fieldEditor(false, for: field) as? NSTextView)?.insertionPointColor = Palette.accent

        report("⌃⌘K — on screen after \(milliseconds(since: start))")
    }

    /// Put the bar away and give the keyboard back to whoever had it.
    ///
    /// `NSApp.hide`, not just ordering the panel out: an `.accessory` application left active with no
    /// window on screen holds the keyboard away from the application the person was actually using.
    ///
    /// The field is emptied *after* the panel is off screen — clearing it narrows back to the whole
    /// **Catalogue**.
    func dismiss() {
        summonedAt = 0
        stopWatchingForClicksElsewhere()
        panel.orderOut(nil)
        if NSApp.isActive { NSApp.hide(nil) }
        stopWorking()
        // Dropped before the stage is left, so `stopAsking` does not restore it into a field about to
        // be emptied.
        typed = ""
        stopAsking()
        field.stringValue = ""
        message = nil
        narrow()
    }

    /// Watch for the click that means the bar is not what is being reached for.
    ///
    /// A **global** monitor sees only what is on its way to *another* application, so a click on the
    /// bar itself never arrives here. Installed only while the bar is up, to keep Starkit out of the
    /// path of every click on the machine.
    private func watchForClicksElsewhere() {
        guard clicksElsewhere == nil else { return }
        clicksElsewhere = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in
            // Delivered on the main run loop, which is the only thread this class exists on.
            MainActor.assumeIsolated { [weak self] in self?.dismiss() }
        }
    }

    private func stopWatchingForClicksElsewhere() {
        guard let clicksElsewhere else { return }
        NSEvent.removeMonitor(clicksElsewhere)
        self.clicksElsewhere = nil
    }

    private func accept() {
        guard !working else { return }

        switch stage {
        case .keyword:
            guard let selected, choices.indices.contains(selected) else { return }
            switch choices[selected] {
            case .create(let keyword):
                // Away first: what happens next is a file opening in the editor.
                dismiss()
                create?(keyword)

            case .script(let manifest):
                let input = Keyword.split(field.stringValue).input
                if let question = manifest.asks, input.isEmpty {
                    ask(manifest, question: question)
                    return
                }
                run?(manifest, input, began())
            }

        case .input(let manifest):
            run?(manifest, field.stringValue, began())
        }
    }

    /// The bar, working: the mark becomes a spinner and the field stops taking keys.
    ///
    /// - Returns: the run started, which is the only one that may speak into this bar.
    private func began() -> Int {
        runs += 1
        working = true
        spoke = false
        message = nil
        mark.working(true)
        field.isEditable = false
        fit()
        return runs
    }

    func notify(_ message: String, for run: Int) {
        guard run == runs, working else {
            report("   Notify — \(message) — dropped, the bar it was for has gone.")
            return
        }
        report("   Notify — \(message)")
        say(message, inStarkitsVoice: false)
    }

    func settled(_ refusal: String?, for run: Int) {
        guard run == runs, working else {
            if let refusal { report("   \(refusal) — the bar it was for has gone.") }
            return
        }
        stopWorking()

        if let refusal {
            say(refusal, inStarkitsVoice: true)
        } else if !spoke {
            dismiss()
            return
        }

        // The caret is coloured after the editor exists again — locking the field took it away.
        panel.makeFirstResponder(field)
        (panel.fieldEditor(false, for: field) as? NSTextView)?.insertionPointColor = Palette.accent
    }

    /// Put a sentence where the list was, and grow the bar to hold it.
    ///
    /// - Parameter inStarkitsVoice: a **Refusal** rather than a **Notify**.
    private func say(_ sentence: String, inStarkitsVoice: Bool) {
        spoke = true
        message = sentence
        messages.show(sentence, inStarkitsVoice: inStarkitsVoice)
        fit()
    }

    private func stopWorking() {
        guard working else { return }
        working = false
        mark.working(false)
        field.isEditable = true
    }

    private func ask(_ manifest: Manifest, question: String) {
        typed = field.stringValue
        stage = .input(manifest)

        let seed = NSPasteboard.general.string(forType: .string) ?? ""
        keywordChip.show(manifest.keyword)
        field.placeholderAttributedString = Self.placeholder(question)
        field.stringValue = seed
        field.currentEditor()?.selectAll(nil)
        placeField()

        // `choices` has to be emptied and not just `matches`: the panel's height comes from the rows
        // it would show.
        message = nil
        matches = []
        choices = []
        selected = nil
        armed = nil
        list.present([], selected: nil)
        fit()

        report("   \(manifest.keyword) asks for \(question) — Seeded with \(seed.count) characters")
    }

    /// Back to the **Keyword** stage, with what was typed still in the field. The caret goes to the
    /// end rather than selecting, so the **Keyword** does not vanish on the next keystroke.
    private func stopAsking() {
        guard case .input = stage else { return }
        stage = .keyword
        keywordChip.isHidden = true
        field.placeholderAttributedString = Self.placeholder("Keyword")
        field.stringValue = typed
        typed = ""
        field.currentEditor()?.moveToEndOfDocument(nil)
        placeField()
        narrow()
    }

    /// Move the selection one row, bounded by what is *shown* rather than by what matched: a
    /// selection past `mostRows` would let ↩ run a **Script** whose name is not on screen.
    private func move(by step: Int) {
        let shown = min(choices.count, Self.mostRows)
        guard shown > 0 else { return }

        guard let selected else {
            // ↓ enters the list at the top; ↑ leaves it alone, because arriving on a row by pressing
            // *up* is an accident.
            guard step > 0 else { return }
            self.selected = 0
            list.select(0)
            return
        }

        let next = min(max(selected + step, 0), shown - 1)
        guard next != selected else { return }
        // Before the selection moves: a confirm naming one **Script** must not survive onto another.
        disarm()
        self.selected = next
        list.select(next)
    }

    /// Into the editor, whether or not the file is there to open yet.
    ///
    /// The offer to write a **Script** is reachable without a selection; a **Script** is not, because
    /// with an empty field nothing is selected and the first row is whatever sorts first.
    private func openOrCreate() {
        guard !working else { return }
        switch selected.flatMap({ choices.indices.contains($0) ? choices[$0] : nil }) ?? offer {
        case .script(let manifest):
            dismiss()
            edit?(manifest)

        case .create(let keyword):
            dismiss()
            create?(keyword)

        case nil:
            break
        }
    }

    private var offer: Choice? {
        guard case .create = choices.first else { return nil }
        return choices.first
    }

    /// ⌃D once arms the selected **Script**, ⌃D again moves it to the Trash. `armed` holds a
    /// **Keyword**, so a selection that moved or a list that narrowed in between disarms rather than
    /// retargets.
    ///
    /// - Returns: whether the bar took the key. `false` in the **Input** stage only, where the field
    ///   holds an answer and forward-delete belongs to the text.
    private func armOrDelete() -> Bool {
        guard case .keyword = stage else { return false }

        // Ignored while a run is in flight and on the offer to *create* a **Script** — there is no
        // file behind either, and letting the key through would edit the field instead.
        guard !working, let selected, choices.indices.contains(selected),
            case .script(let manifest) = choices[selected]
        else { return true }

        if armed == manifest.keyword {
            armed = nil
            // Away before the file moves: what is left on screen would be a question about a
            // **Script** that no longer exists.
            dismiss()
            delete?(manifest)
        } else {
            armed = manifest.keyword
            say(
                deletionQuestion?(manifest)
                    ?? "Delete “\(manifest.name)”? ⌃D again moves it to the Trash. Escape keeps it.",
                inStarkitsVoice: true
            )
        }
        return true
    }

    private func narrow() {
        message = nil
        // A new **Catalogue** from C6 can move a **Script** out from under the cursor, so narrowing
        // disarms.
        armed = nil
        let keyword = Keyword.split(field.stringValue).keyword
        matches = Keyword.matches(keyword, in: catalogue)

        if matches.isEmpty {
            choices = Scaffold.isValid(keyword) ? [.create(keyword)] : []
            // Nothing selected: reaching the offer is a deliberate ↓, so ↩ on a typo does nothing.
            selected = nil
        } else {
            choices = matches.map(Choice.script)
            // Nothing typed lists the whole **Catalogue** and selects nothing: the first row is
            // whatever sorts first, which is `clean` — the one **Script** whose **Effects** cannot be
            // taken back.
            selected = keyword.isEmpty ? nil : 0
        }

        show()
        fit()
    }

    private func disarm() {
        guard armed != nil else { return }
        armed = nil
        message = nil
        fit()
    }

    private func show() {
        list.present(Array(choices.prefix(Self.mostRows)), selected: selected)
    }

    /// Grow the panel downwards, keeping its top edge where it was. An `NSWindow` frame is measured
    /// from its bottom-left, so the origin moves to compensate for the height.
    private func fit() {
        let height = Self.header + under()
        list.isHidden = message != nil
        messages.isHidden = message == nil
        guard height != panel.frame.height else { return }

        var frame = panel.frame
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        panel.setFrame(frame, display: panel.isVisible)
        layOut()
    }

    private func under() -> CGFloat {
        if message != nil { return messages.frame.height + Self.footer }
        let shown = min(choices.count, Self.mostRows)
        return shown == 0 ? 0 : CGFloat(shown) * Self.row + Self.footer
    }

    /// The head at the top, whatever the bar is showing under it filling what is left. Explicit
    /// rather than by `autoresizingMask`, which splits a delta between everything flexible instead of
    /// giving it to the one that asked.
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

    private func placeField() {
        var x = Self.leading
        if case .input = stage {
            keywordChip.setFrameOrigin(
                NSPoint(x: x, y: (Self.header - keywordChip.frame.height) / 2)
            )
            x += keywordChip.frame.width + Self.gap
        }
        let right = homeTag.isHidden ? Self.margin : Self.margin + Self.homeWidth + Self.gap
        centre(field, x: x, width: Self.width - x - right, in: Self.header)
    }

    private static func placeholder(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 21),
                .foregroundColor: Palette.placeholder,
            ]
        )
    }

    /// Centred, a fifth of the way down, on the screen being looked at. The *top* edge is what sits
    /// a fifth of the way down, so the bar lands in the same place whether it lists five **Scripts**
    /// or none.
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
    func controlTextDidChange(_ notification: Notification) {
        guard case .keyword = stage else { return }
        let start = CFAbsoluteTimeGetCurrent()
        narrow()
        report("   \(matches.count) of \(catalogue.count) Scripts in \(milliseconds(since: start))")
    }

    /// The selector Cocoa names for the key, never the key itself — ⌃N and ⌃P are `moveDown:` and
    /// `moveUp:` in macOS's own key bindings, so they arrive here for free.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): accept()
        case #selector(NSResponder.moveUp(_:)): move(by: -1)
        case #selector(NSResponder.moveDown(_:)): move(by: 1)
        // ⌃D — and the forward-delete key, which Cocoa gives the same name. Taking it means neither
        // deletes a character in this field any more; the **Input** stage hands it back.
        case #selector(NSResponder.deleteForward(_:)): return armOrDelete()
        // ⌥↩ *and* ⌃O, both of which macOS binds to this one selector.
        case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)): openOrCreate()
        default: return false
        }
        return true
    }
}

private final class Mark: NSView {
    private let glyph: NSImageView
    private let spinner = NSProgressIndicator()

    init(box: CGFloat) {
        let fruit: CGFloat = 20
        glyph = NSImageView(image: Carambola.image(box: fruit, colour: Palette.fruit))
        glyph.frame = NSRect(x: (box - fruit) / 2, y: (box - fruit) / 2, width: fruit, height: fruit)

        super.init(frame: NSRect(x: 0, y: 0, width: box, height: box))
        wantsLayer = true
        layer?.backgroundColor = Palette.accent.cgColor
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = 9
        addSubview(glyph)

        let wheel: CGFloat = 16
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.frame = NSRect(x: (box - wheel) / 2, y: (box - wheel) / 2, width: wheel, height: wheel)
        // Forced light in both appearances: what it sits on is the periwinkle chip, not the window.
        spinner.appearance = NSAppearance(named: .darkAqua)
        spinner.isDisplayedWhenStopped = false
        addSubview(spinner)

        // Decoration. The fruit says nothing, and the spinner says what the field being locked
        // already says — read out, the pair is two interruptions for no information.
        setAccessibilityElement(false)
        glyph.setAccessibilityElement(false)
        spinner.setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    func working(_ working: Bool) {
        glyph.isHidden = working
        if working { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }
}

private final class MessageView: NSView {
    private static let padding: CGFloat = 14

    private let sentence = NSTextField(labelWithString: "")
    private let symbol = NSImageView()
    private let leading: CGFloat
    private let margin: CGFloat
    private let chip: CGFloat

    init(width: CGFloat, leading: CGFloat, margin: CGFloat, chip: CGFloat) {
        self.leading = leading
        self.margin = margin
        self.chip = chip
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))

        sentence.font = .systemFont(ofSize: 15)
        sentence.textColor = .labelColor
        sentence.usesSingleLineMode = false
        sentence.lineBreakMode = .byWordWrapping
        sentence.maximumNumberOfLines = 0
        addSubview(sentence)

        symbol.image = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: "Starkit refused"
        )
        symbol.contentTintColor = Palette.aside
        addSubview(symbol)

        // One element rather than a label beside a symbol: what is read out should be the sentence
        // and who is saying it, in that order, and not two announcements that arrive apart.
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    override var isFlipped: Bool { true }

    func show(_ text: String, inStarkitsVoice: Bool) {
        sentence.stringValue = text
        // Whose voice it is, said rather than drawn: the warning symbol is the only thing that tells
        // a **Refusal** from a **Notify** on screen, and a symbol reads as nothing.
        setAccessibilityLabel(inStarkitsVoice ? "Starkit refused. \(text)" : text)
        let room = frame.width - leading - margin
        // The cell is asked how tall it needs to be *at this width* — a label's intrinsic size is a
        // single line unless something tells it what width it has.
        let space = NSRect(x: 0, y: 0, width: room, height: .greatestFiniteMagnitude)
        let height = (sentence.cell?.cellSize(forBounds: space).height ?? Self.padding).rounded(.up)
        sentence.frame = NSRect(x: leading, y: Self.padding, width: room, height: height)
        setFrameSize(NSSize(width: frame.width, height: (height + Self.padding * 2).rounded(.up)))

        symbol.isHidden = !inStarkitsVoice
        // Centred on the *first line* rather than on the block, so a sentence that wraps to two
        // lines still starts where the symbol says it does.
        let glyph: CGFloat = 16
        let line = (sentence.font?.ascender ?? glyph) - (sentence.font?.descender ?? 0)
        symbol.frame = NSRect(
            x: margin + (chip - glyph) / 2,
            y: Self.padding + ((line - glyph) / 2).rounded(),
            width: glyph,
            height: glyph
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let hairline = NSBezierPath()
        hairline.move(to: NSPoint(x: 0, y: 0.5))
        hairline.line(to: NSPoint(x: bounds.width, y: 0.5))
        hairline.lineWidth = 1
        Palette.edge.setStroke()
        hairline.stroke()
    }
}

private final class KeywordChip: NSView {
    private static let height: CGFloat = 28
    private static let padding: CGFloat = 10

    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: Self.height))
        label.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        label.textColor = .labelColor
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    func show(_ keyword: String) {
        label.stringValue = keyword
        label.sizeToFit()
        centre(label, x: Self.padding, width: label.frame.width, in: Self.height)
        setFrameSize(NSSize(width: label.frame.width + Self.padding * 2, height: Self.height))
        isHidden = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        Palette.selection.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
    }
}

/// The rows under the field, one per matched **Manifest**. Flipped, so a row's y is its distance
/// from the field rather than from the bottom of a panel whose height changes with every keystroke.
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
        setAccessibilityRole(.list)
        setAccessibilityLabel("Scripts")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    override var isFlipped: Bool { true }

    func present(_ choices: [SummonPanel.Choice], selected: Int?) {
        for (index, row) in rows.enumerated() {
            row.isHidden = index >= choices.count
            guard index < choices.count else { continue }
            row.show(choices[index], selected: index == selected)
        }
    }

    func select(_ selected: Int?) {
        for (index, row) in rows.enumerated() { row.select(index == selected) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let hairline = NSBezierPath()
        hairline.move(to: NSPoint(x: 0, y: 0.5))
        hairline.line(to: NSPoint(x: bounds.width, y: 0.5))
        hairline.lineWidth = 1
        Palette.edge.setStroke()
        hairline.stroke()
    }
}

private final class RowView: NSView {
    private let name = NSTextField(labelWithString: "")
    private let keyword = NSTextField(labelWithString: "")
    private var selected = false

    private static let keywordWidth: CGFloat = 180

    private static let between = " · "

    init(frame: NSRect, leading: CGFloat, margin: CGFloat) {
        super.init(frame: frame)

        // `labelColor` for the name, not the palette — see `Palette`.
        name.font = .systemFont(ofSize: 15)
        name.textColor = .labelColor
        keyword.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        keyword.textColor = Palette.aside
        keyword.alignment = .right
        name.lineBreakMode = .byTruncatingTail
        // From the *head*, unlike the name: the canonical **Keyword** is last in the column and is
        // the one that must survive a row too narrow for all of them.
        keyword.lineBreakMode = .byTruncatingHead
        for label in [name, keyword] { addSubview(label) }

        let room = frame.width - leading - margin - Self.keywordWidth - 12
        centre(name, x: leading, width: room, in: frame.height)
        centre(
            keyword,
            x: frame.width - margin - Self.keywordWidth,
            width: Self.keywordWidth,
            in: frame.height
        )

        // The row and not its two labels: a row read out as "Youtube" and then "yt, youtube" is two
        // things where there is one, and the selection is a property of the row.
        setAccessibilityElement(true)
        setAccessibilityRole(.row)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    func show(_ choice: SummonPanel.Choice, selected: Bool) {
        switch choice {
        case .script(let manifest):
            name.stringValue = manifest.name
            name.textColor = .labelColor
            keyword.stringValue = (manifest.otherKeywords + [manifest.keyword])
                .joined(separator: Self.between)
        case .create(let typed):
            name.stringValue = "Create “\(typed)”"
            name.textColor = Palette.aside
            keyword.stringValue = "⌥↩ new Script"
        }
        setAccessibilityLabel("\(name.stringValue), \(keyword.stringValue)")
        select(selected)
    }

    func select(_ selected: Bool) {
        setAccessibilitySelected(selected)
        guard self.selected != selected else { return }
        self.selected = selected
        needsDisplay = true
    }

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

/// Give a label a frame exactly one line of its own font tall, and centre that frame. An unbezeled
/// `NSTextField` draws its text at the *top* of its frame, so a taller frame puts the text high.
private func centre(_ field: NSTextField, x: CGFloat, width: CGFloat, in height: CGFloat) {
    let line = (field.font?.ascender ?? 0) - (field.font?.descender ?? 0)
    field.frame = NSRect(
        x: x,
        y: ((height - line) / 2).rounded(),
        width: width,
        height: line.rounded(.up)
    )
}

/// The cream over the blur and the outline around it, resolved against whichever appearance is
/// current at the moment of drawing. Both fills go *over* the material rather than replacing it:
/// `.hudWindow` is what makes the bar sit in front of a desktop instead of on top of it.
private final class Wash: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Inset by half the stroke, so the outline lands inside the panel instead of being clipped
        // in half by the corner radius it is tracing.
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 15.5,
            yRadius: 15.5
        )
        // Backing first, then the cream over it: the first decides how dark the bar is.
        Palette.backing.setFill()
        outline.fill()
        Palette.wash.setFill()
        outline.fill()
        Palette.edge.setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }
}

/// A borderless panel that can still take the keyboard: `NSWindow.canBecomeKey` is false without a
/// titlebar.
private final class KeyablePanel: NSPanel {
    /// What Escape does. Held on the window because the field editor passes `cancelOperation:` up
    /// the responder chain when it has nothing of its own to cancel.
    var cancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        cancel?()
    }
}
