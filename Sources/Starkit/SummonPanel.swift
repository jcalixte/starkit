import AppKit
import StarkitCore

/// C1 — the bar itself: one panel, built at launch, **Summoned** and **Dismissed** forever after.
///
/// Built once because F1's budget is 50 ms from ⌃⌘K and a window is the expensive part of showing
/// one; every **Summon** after is an `orderFront`.
///
/// The panel takes activation, which T0.5 established is not a preference: macOS routes keys to the
/// *active* application's key window, so a panel belonging to an inactive application can be on
/// screen and still receive nothing. The cost is a focus to hand back — `dismiss` does it here and
/// C7 does it again before **Paste** (`DESIGN.md` §9).
@MainActor
final class SummonPanel: NSObject, NSTextFieldDelegate {
    private static let width: CGFloat = 680

    /// The mark and the field — also the whole panel when nothing matches, which is the shape every
    /// other shape is measured from.
    private static let header: CGFloat = 64

    /// One matched **Manifest**.
    private static let row: CGFloat = 40

    /// Below the last row, so it is not clipped in half by the corner it sits in.
    private static let footer: CGFloat = 8

    /// Not a scrolling list — the way past the eighth match is to type. Also where the selection
    /// stops: see `move`.
    private static let mostRows = 8

    /// The periwinkle square the carambola sits on, and the gap after it.
    private static let chip: CGFloat = 30
    private static let margin: CGFloat = 18

    /// Where the typed text starts — and where a row's name starts, so the column you read is the
    /// column you are typing into.
    private static let leading: CGFloat = margin + chip + 14

    /// The gap between the **Keyword** chip and the **Input** typed after it.
    private static let gap: CGFloat = 10

    private let panel: KeyablePanel
    private let field: NSTextField
    /// The **Keyword** once it has been chosen, shown only in the **Input** stage.
    private let keywordChip = KeywordChip()
    /// Starkit's own glyph at the head of the bar, and the spinner it becomes while a run is in
    /// flight.
    private let mark = Mark(box: SummonPanel.chip)
    /// The mark and the field, kept together so the panel growing downwards moves neither.
    private let head: NSView
    private let list: ListView
    /// What the last run had to say, in the space the list would otherwise be using.
    private let messages = MessageView(
        width: SummonPanel.width,
        leading: SummonPanel.leading,
        margin: SummonPanel.margin,
        chip: SummonPanel.chip
    )

    /// What ↩ does with the **Manifest** it selected and the **Input** typed after the **Keyword**.
    ///
    /// A callback rather than a **Runner** held here: giving the panel a **Toolchain** would put the
    /// whole spine behind the one component whose job is to be on screen in 50 ms.
    ///
    /// The third argument is the run being started. Whoever performs it hands it back to `notify`
    /// and `settled`, which is how a run the person walked away from is stopped from speaking into
    /// the bar that came after it.
    var run: ((Manifest, String, Int) -> Void)?

    /// What ↩ does with the offer to write a **Script** that does not exist yet (F11). The bar goes
    /// away afterwards: all typing happens in the editor, and C6 makes the file real without being
    /// asked.
    var create: ((String) -> Void)?

    /// What the *second* ⌃D does to the selected **Script** (F16). The bar stays open, because the
    /// list going one row shorter a moment later is the only confirmation worth showing: it is C6
    /// reporting the file is really gone rather than Starkit promising it.
    var delete: ((Manifest) -> Void)?

    /// ⌥↩ or ⌃O on a **Script** — open it where it is written (F17). The bar goes away, because the
    /// editor is about to take the keyboard and F11 already decided that is where typing happens.
    var edit: ((Manifest) -> Void)?

    /// The sentence the first ⌃D puts on screen, which has to name the files that would actually move
    /// — a **Script**'s test is part of it (C11), and a confirm that said otherwise would be the kind
    /// of surprise the Trash exists to survive rather than to excuse. Supplied from outside because C1
    /// does not read the filesystem.
    var deletionQuestion: ((Manifest) -> String)?

    /// Every **Script** Starkit knows about, which is not the same as every **Script** it can run
    /// (F2). Narrowed on assignment so the panel is already the right height before the first
    /// **Summon** rather than resizing while someone is looking at it.
    var catalogue: [Manifest] = [] {
        didSet { narrow() }
    }

    /// The **Keyword** stage lists **Scripts** and narrows as you type. The **Input** stage has one
    /// **Script** chosen and asks the question it declared — no list and no narrowing, because what
    /// is being typed is an answer. A **Script** that `Decides` never reaches the second stage.
    private enum Stage {
        case keyword
        case input(Manifest)
    }

    private var stage = Stage.keyword

    /// What was typed in the **Keyword** stage, held while the **Input** stage is up so Escape can
    /// put it back.
    private var typed = ""

    /// What the **Keyword** typed so far selects, in the order it will be listed.
    private var matches: [Manifest] = []

    /// The rows as they are on screen. Either the **Scripts** that matched, or — when none did and
    /// what was typed could *be* a **Keyword** — the single offer to write one (F11).
    ///
    /// A case rather than a **Manifest** carrying a flag: a **Manifest** describes a **Script** that
    /// exists, and handing a made-up one to `run` is exactly the bug this shape cannot express.
    fileprivate enum Choice {
        case script(Manifest)
        case create(String)
    }

    private var choices: [Choice] = []

    /// Which row ↩ acts on, or **nothing at all**.
    ///
    /// Optional because of one line of SPEC: `Create "<keyword>"` is never the default selection, so
    /// ↩ on a typo must do nothing. With a plain `Int` the offer would sit under the cursor the moment
    /// a **Keyword** stopped matching, and the fastest way to write a file would be to misspell one.
    private var selected: Int?

    /// The **Keyword** that one more ⌃D would move to the Trash, or `nil` when nothing is armed.
    ///
    /// The **Keyword** and not the index, so that arming survives nothing: any narrowing, any move of
    /// the selection and any new **Catalogue** from C6 clears it, and the second press has to find the
    /// same **Script** still under the cursor. Deleting the wrong file is the only mistake in this
    /// design that cannot be taken back by pressing something else, so the state is written to be lost
    /// easily rather than held onto.
    private var armed: String?

    /// How many runs the bar has started. The current one is the only one allowed to speak —
    /// without this, a **Script** hung against its 5 s deadline could **Notify** into a bar
    /// **Summoned** afterwards for something else entirely.
    private var runs = 0

    /// Whether a run is in flight, which is the spinner and the locked field.
    private var working = false

    /// Whether the run in flight has already put something on screen, so a run that said its piece
    /// leaves the bar up rather than **Dismissing** it out from under the sentence.
    private var spoke = false

    /// What is on screen instead of the list. The two never share the bar — see `under`.
    private var message: String?

    /// When the **Summon** being measured started, or 0 between them.
    private var summonedAt: CFAbsoluteTime = 0

    /// What is watching for the click that **Dismisses** the bar, or nothing while it is down.
    private var clicksElsewhere: Any?

    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.header),
            // Borderless via a mask that names no chrome. T0.5 tried `.titled` with a transparent
            // titlebar and the field inside `contentLayoutRect` came out with a negative height.
            //
            // `.nonactivatingPanel` does not conflict with activating deliberately: it stops a
            // *click* on the panel from activating Starkit, so only ⌃⌘K ever brings it forward.
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        // Must stay false: a **Script** runs with the bar still up, and both an **Open** it performs
        // and the hand-back before a **Paste** activate another application. Auto-hiding would take
        // the bar away mid-run, spinner and all.
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // Reachable from whichever space is in front, including over a full-screen application (G2).
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

        // Drawn rather than set on the layer: a `CALayer`'s colours are resolved once, so a panel
        // built in one appearance keeps that appearance's cream after the machine switches — and
        // this window is built at launch and never rebuilt. Drawing resolves them every time.
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
        background.addSubview(head)

        list = ListView(
            frame: NSRect(x: 0, y: 0, width: Self.width, height: 0),
            rows: Self.mostRows,
            height: Self.row,
            leading: Self.leading,
            margin: Self.margin
        )
        background.addSubview(list)

        // Placed once and never again — the panel grows to hold the sentence rather than the view
        // moving, which is what keeps this out of `layOut` and off F3's budget.
        messages.setFrameOrigin(NSPoint(x: 0, y: Self.footer))
        messages.isHidden = true
        background.addSubview(messages)

        panel.contentView = background
        super.init()

        field.delegate = self
        // Escape is one stage back before it is a **Dismissal** — the only key in the bar whose
        // meaning depends on which stage is up.
        panel.cancel = { [weak self] in
            guard let self else { return }
            if case .input = self.stage { self.stopAsking() } else { self.dismiss() }
        }
        placeField()
        layOut()
        warm()

        // Activation travels through the window server, so `isKeyWindow` read on the turn of the run
        // loop that shows the panel says nothing about whether it can be typed into. This is the
        // only honest place to time that from.
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

    /// Put the panel on screen once, invisibly, so the first real **Summon** is not what pays for it.
    ///
    /// Building the window at launch was not enough on its own: measured at T2.2, the first
    /// **Summon** of a session cost 25.3 ms to appear against a 7 ms median and 60.9 ms to become
    /// key against 13 — the window server, the material and the first activation each charge once.
    ///
    /// Transparent *and* off screen: either alone risks a frame of a bar appearing at launch.
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
    /// `NSApp.hide`, not just ordering the panel out: an `.accessory` application left active with
    /// no window on screen holds the keyboard away from the application the person was actually
    /// using. Guarded on `isActive` because C7 may already have handed focus back before a
    /// **Paste**, and hiding an inactive application is a message about nothing.
    ///
    /// The field is emptied *after* the panel is off screen — clearing it narrows back to the whole
    /// **Catalogue**, and doing that first would be a bar collapsing on its way out.
    func dismiss() {
        summonedAt = 0
        stopWatchingForClicksElsewhere()
        panel.orderOut(nil)
        if NSApp.isActive { NSApp.hide(nil) }
        // The run itself carries on and its **Effects** are still performed — a `bun` already
        // spawned is not something a keystroke can unspawn — but it loses the bar to speak into.
        stopWorking()
        // Dropped before the stage is left, so a **Dismissal** mid-question does not restore the
        // **Keyword** into a field about to be emptied anyway.
        typed = ""
        stopAsking()
        field.stringValue = ""
        message = nil
        narrow()
    }

    /// Watch for the click that means the bar is not what is being reached for.
    ///
    /// A **global** monitor sees only what is on its way to *another* application, so a click on the
    /// bar itself never arrives here — "outside" is decided by the window server rather than by
    /// hit-testing a frame, which also puts the menu bar item inside.
    ///
    /// Not `hidesOnDeactivate`: an **Open** a **Script** performs is the same lost focus as a click
    /// and must not put the bar away. A mouse-down answers the *person*, so no "is a run in flight"
    /// flag is needed to tell the two apart.
    ///
    /// Installed only while the bar is up — a permanent monitor would put Starkit in the path of
    /// every click on the machine for the ~99% of the time it has nothing on screen (G4).
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

    /// ↩ — run what is selected, and stay on screen to see what happens.
    ///
    /// The bar deliberately does not leave first: a bar that hid through four seconds of a cold
    /// Electron **Open** (T1.5) is indistinguishable from a hang, and F14 asks for the spinner. The
    /// cost is the hand-back hiding used to do for free, which C7 now performs before every
    /// **Paste**.
    ///
    /// The **Keyword** run is the **Manifest**'s, not what was typed: `wo` selects Work and Work is
    /// what runs.
    private func accept() {
        // A second ↩ while the first is still running would start a run the bar cannot show — there
        // is one spinner and one message. The field is locked for the same reason.
        guard !working else { return }

        switch stage {
        case .keyword:
            guard let selected, choices.indices.contains(selected) else { return }
            switch choices[selected] {
            case .create(let keyword):
                // Away first: what happens next is a file opening in Zed, and a bar left on screen
                // would be holding the keyboard away from it.
                dismiss()
                create?(keyword)

            case .script(let manifest):
                let input = Keyword.split(field.stringValue).input
                // A question already answered is not asked: typing the **Input** on the same line as
                // the **Keyword** skips the stage entirely.
                if let question = manifest.asks, input.isEmpty {
                    ask(manifest, question: question)
                    return
                }
                run?(manifest, input, began())
            }

        case .input(let manifest):
            // Whole and verbatim: the field holds the **Input** alone here, so splitting it again
            // would read the first word of an answer as a **Keyword**.
            run?(manifest, field.stringValue, began())
        }
    }

    /// The bar, working: the mark becomes a spinner and the field stops taking keys. Escape still
    /// arrives, because it reaches the window rather than the field.
    ///
    /// - Returns: the run started, which is what may speak into this bar until it is **Dismissed**.
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

    /// C7 performing a **Notify**, arrived on the main thread. Dropped rather than shown if the bar
    /// it was meant for has gone: a bar that came back on its own to deliver a sentence would be the
    /// window SPEC says never appears.
    func notify(_ message: String, for run: Int) {
        guard run == runs, working else {
            report("   Notify — \(message) — dropped, the bar it was for has gone.")
            return
        }
        report("   Notify — \(message)")
        say(message, inStarkitsVoice: false)
    }

    /// The run is over: stop the spinner, and either say what went wrong or get out of the way.
    ///
    /// A **Refusal** lands here as well as in the menu bar — two places, one for each question:
    /// what happened, and what is still wrong. Nothing said and nothing wrong **Dismisses** the bar.
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

        // Back to a field that can be typed into, so ↩ from here is the whole repair. The caret is
        // coloured after the editor exists again — locking the field is what took it away.
        panel.makeFirstResponder(field)
        (panel.fieldEditor(false, for: field) as? NSTextView)?.insertionPointColor = Palette.accent
    }

    /// Put a sentence where the list was, and grow the bar to hold it.
    ///
    /// - Parameter inStarkitsVoice: a **Refusal** rather than a **Notify**. Marked rather than
    ///   worded, because who is talking is the one thing a person cannot work out from the words.
    private func say(_ sentence: String, inStarkitsVoice: Bool) {
        spoke = true
        message = sentence
        messages.show(sentence, inStarkitsVoice: inStarkitsVoice)
        fit()
    }

    /// The spinner off and the field back, whether the run ended or was walked away from.
    private func stopWorking() {
        guard working else { return }
        working = false
        mark.working(false)
        field.isEditable = true
    }

    /// Put the **Script**'s question up, **Seeded** from the clipboard.
    ///
    /// The **Seed** arrives selected, which makes accepting it one keystroke and replacing it none
    /// (`CONTEXT.md`). An empty clipboard **Seeds** with nothing and the stage arrives anyway.
    private func ask(_ manifest: Manifest, question: String) {
        typed = field.stringValue
        stage = .input(manifest)

        let seed = NSPasteboard.general.string(forType: .string) ?? ""
        keywordChip.show(manifest.keyword)
        field.placeholderAttributedString = Self.placeholder(question)
        field.stringValue = seed
        field.currentEditor()?.selectAll(nil)
        placeField()

        // Nothing matches in this stage, which takes the list away and shrinks the panel back to the
        // head. A message from an earlier run goes with it.
        //
        // `choices` has to be emptied and not just `matches`: the panel's height comes from the rows
        // it would show, so leaving them here would keep the list's height under a question with no
        // list in it — and with C6 running, the **Catalogue** now changes while the bar is open.
        message = nil
        matches = []
        choices = []
        selected = nil
        armed = nil
        list.present([], selected: nil)
        fit()

        report("   \(manifest.keyword) asks for \(question) — Seeded with \(seed.count) characters")
    }

    /// Back to the **Keyword** stage, with what was typed still in the field. Escape's first
    /// meaning, and also what a **Dismissal** does on its way out, so the bar is never **Summoned**
    /// back into the middle of a question. The caret goes to the end rather than selecting, so the
    /// **Keyword** does not vanish on the next keystroke.
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

    /// Move the selection one row.
    ///
    /// Bounded by what is *shown*, never by what matched: a selection travelling past `mostRows`
    /// would let ↩ run a **Script** whose name is not on screen. Stops at the ends rather than
    /// wrapping.
    private func move(by step: Int) {
        let shown = min(choices.count, Self.mostRows)
        guard shown > 0 else { return }

        guard let selected else {
            // Only reachable when the one row is an offer to write a **Script**. ↓ takes it, ↑ leaves
            // it alone: the offer is below the field, and arriving on it by pressing *up* would be the
            // accident this is written to prevent.
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

    /// Open the selected **Script** in the editor.
    ///
    /// Nothing on the offer to *create* one: ↩ there already writes the file and opens it, and a second
    /// key doing three quarters of the same thing is a **Keyword** away from being a mistake.
    private func editSelected() {
        guard !working, let selected, choices.indices.contains(selected),
            case .script(let manifest) = choices[selected]
        else { return }
        dismiss()
        edit?(manifest)
    }

    /// ⌃D once arms the selected **Script**, ⌃D again moves it to the Trash (F16).
    ///
    /// Two presses rather than one because this is the only thing the bar does that destroys a file
    /// somebody wrote, and one keystroke away from that is the same distance as a typo. The second
    /// press has to land on the **same** **Script**: `armed` holds a **Keyword**, so a selection that
    /// moved or a list that narrowed in between disarms rather than retargets.
    ///
    /// - Returns: whether the bar took the key. `false` in the **Input** stage only, where the field
    ///   holds an answer and forward-delete belongs to the text.
    private func armOrDelete() -> Bool {
        guard case .keyword = stage else { return false }

        // Taken but ignored while a run is in flight, and on the offer to *create* a **Script** —
        // there is no file behind either, and letting the key through would edit the field instead,
        // which is a different thing happening for the same press.
        guard !working, let selected, choices.indices.contains(selected),
            case .script(let manifest) = choices[selected]
        else { return true }

        if armed == manifest.keyword {
            armed = nil
            // Away before the file moves, like the create row: what is left on screen would be a
            // question about a **Script** that no longer exists, and C6 is about to say so anyway.
            dismiss()
            delete?(manifest)
        } else {
            armed = manifest.keyword
            // In the list's place rather than beside the row, because the list and a message are
            // exclusive by design (`under`) and this is the one question in the bar whose answer
            // cannot be taken back. Escape is offered because it is what a person reaches for, and it
            // works without being handled here: the field editor sends `cancelOperation:` up to the
            // window, which **Dismisses** — and a bar that has gone has deleted nothing.
            say(
                deletionQuestion?(manifest)
                    ?? "Delete “\(manifest.name)”? ⌃D again moves it to the Trash. Escape keeps it.",
                inStarkitsVoice: true
            )
        }
        return true
    }

    /// Narrow the list to what has been typed, and grow or shrink the panel to hold the result (F3).
    /// Puts any message away — narrowing is choosing a different **Script**.
    private func narrow() {
        message = nil
        // Anything that can move a **Script** out from under the cursor disarms: a keystroke in the
        // field, and a new **Catalogue** arriving from C6 while the bar is open.
        armed = nil
        let keyword = Keyword.split(field.stringValue).keyword
        matches = Keyword.matches(keyword, in: catalogue)

        if matches.isEmpty {
            // Offered only for something that could be a Gleam module name, and never for an empty
            // field — nothing typed lists everything, and `Create ""` is not a thing to offer.
            choices = Scaffold.isValid(keyword) ? [.create(keyword)] : []
            // Nothing selected: reaching the offer is a deliberate ↓, so ↩ on a typo does nothing.
            selected = nil
        } else {
            choices = matches.map(Choice.script)
            selected = 0
        }

        show()
        fit()
    }

    /// Put the confirm away and leave the **Script** alone.
    ///
    /// Called by anything that could have moved a different **Script** under the cursor, so that the
    /// second ⌃D can only ever land on the one the question named.
    private func disarm() {
        guard armed != nil else { return }
        armed = nil
        message = nil
        fit()
    }

    /// Everything the list draws, from the state that decides it.
    private func show() {
        list.present(Array(choices.prefix(Self.mostRows)), selected: selected)
    }

    /// Grow the panel downwards, keeping its top edge where it was: the field must not move while
    /// someone is typing into it. An `NSWindow` frame is measured from its bottom-left, so the
    /// origin moves to compensate for the height.
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

    /// How much bar there is below the head: a message, or the rows, or neither — never both, which
    /// would offer ↩ two meanings at once.
    private func under() -> CGFloat {
        if message != nil { return messages.frame.height + Self.footer }
        let shown = min(choices.count, Self.mostRows)
        return shown == 0 ? 0 : CGFloat(shown) * Self.row + Self.footer
    }

    /// The head at the top, whatever the bar is showing under it filling what is left.
    ///
    /// Explicit rather than by `autoresizingMask`: both views would have to be flexible in the same
    /// direction, and autoresizing splits a delta between everything flexible instead of giving it
    /// to the one that asked.
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

    /// Where the field starts, which is after the **Keyword** chip when there is one. The chip takes
    /// the column the typed text was in, so the **Keyword** does not move when it stops being
    /// editable.
    private func placeField() {
        var x = Self.leading
        if case .input = stage {
            keywordChip.setFrameOrigin(
                NSPoint(x: x, y: (Self.header - keywordChip.frame.height) / 2)
            )
            x += keywordChip.frame.width + Self.gap
        }
        centre(field, x: x, width: Self.width - x - Self.margin, in: Self.header)
    }

    /// The one piece of text in the bar that is Starkit talking rather than the person. In the
    /// accent rather than the system's grey, which is what says whose voice it is.
    private static func placeholder(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 21),
                .foregroundColor: Palette.placeholder,
            ]
        )
    }

    /// Centred, a fifth of the way down, on the screen being looked at. Placed at every **Summon**
    /// because the answer changes as screens come and go. The *top* edge is what sits a fifth of
    /// the way down, so the bar lands in the same place whether it lists five **Scripts** or none.
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
    func controlTextDidChange(_ notification: Notification) {
        // Nothing narrows in the **Input** stage: there is no **Keyword** in the field to match.
        guard case .keyword = stage else { return }
        let start = CFAbsoluteTimeGetCurrent()
        narrow()
        report("   \(matches.count) of \(catalogue.count) Scripts in \(milliseconds(since: start))")
    }

    /// F13 inside the field: the selector Cocoa names for the key, never the key itself. ⌃N and ⌃P
    /// are `moveDown:` and `moveUp:` in macOS's own key bindings, so they arrive here for free, as
    /// does anything else a person has bound to moving.
    ///
    /// Escape is not handled here on purpose: the field editor passes `cancelOperation:` up the
    /// responder chain on its own, and the window is where it lands.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        // Taken even when nothing matched. There is nothing to run or move onto, and the
        // alternative is the field editor beeping at a person who can already see the list is
        // empty.
        case #selector(NSResponder.insertNewline(_:)): accept()
        case #selector(NSResponder.moveUp(_:)): move(by: -1)
        case #selector(NSResponder.moveDown(_:)): move(by: 1)
        // ⌃D — and the forward-delete key, which Cocoa gives the same name. Taking it means neither
        // deletes a character in this field any more, which is the price F16 was given for staying on
        // the home row; the **Input** stage hands it back, because there the field holds an answer
        // rather than a **Keyword** and forward-delete is the text's again.
        case #selector(NSResponder.deleteForward(_:)): return armOrDelete()
        // ⌥↩ *and* ⌃O, both of which macOS binds to this one selector — the same free pair T2.5 got
        // when ⌃N and ⌃P turned out to be `moveDown:` and `moveUp:`. The cheapest key in the bar to
        // take: "insert a newline ignoring the field editor" has nothing to do in a field that holds
        // one line.
        case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)): editSelected()
        // Everything else is the field editor's, including the arrows that move along the line.
        default: return false
        }
        return true
    }
}

/// Starkit's mark at the head of the bar, and the spinner it turns into while a run is in flight —
/// the same square in the same place rather than a second element appearing beside it.
///
/// Cream on periwinkle rather than the fruit's own yellow on the blur: at 20pt over a material that
/// could be anything, the palette's creams have no contrast to spend. The chip gives the glyph a
/// background it can be light against.
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
        // Leaves no animation turning while the bar is idle (G4).
        spinner.isDisplayedWhenStopped = false
        addSubview(spinner)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    func working(_ working: Bool) {
        glyph.isHidden = working
        if working { spinner.startAnimation(nil) } else { spinner.stopAnimation(nil) }
    }
}

/// What the last run had to say, in the space the list would otherwise be using.
///
/// One sentence only — `detail` never reaches here, because a Gleam diagnostic or a stack trace is
/// many lines and belongs on stderr, where C4 already puts it. A **Refusal** carries C10's symbol in
/// the mark's column and a **Notify** carries nothing, which is the whole of whose-voice-is-this.
private final class MessageView: NSView {
    /// Above and below the sentence, inside the bar.
    private static let padding: CGFloat = 14

    private let sentence = NSTextField(labelWithString: "")
    private let symbol = NSImageView()
    private let leading: CGFloat
    private let margin: CGFloat
    /// The mark's column at the head of the bar, which is the column a **Refusal**'s symbol sits in.
    private let chip: CGFloat

    init(width: CGFloat, leading: CGFloat, margin: CGFloat, chip: CGFloat) {
        self.leading = leading
        self.margin = margin
        self.chip = chip
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 0))

        sentence.font = .systemFont(ofSize: 15)
        sentence.textColor = .labelColor
        // Wrapped rather than truncated, unlike every other label in the bar: this is the only text
        // here a person has to read all of.
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    /// Flipped, like the list it stands in for, so the hairline is drawn at the edge nearest the
    /// field in both.
    override var isFlipped: Bool { true }

    func show(_ text: String, inStarkitsVoice: Bool) {
        sentence.stringValue = text
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

    /// The hairline between the field and what is under it — the same line `ListView` draws, because
    /// it is the same edge seen from whichever of the two is on screen.
    override func draw(_ dirtyRect: NSRect) {
        let hairline = NSBezierPath()
        hairline.move(to: NSPoint(x: 0, y: 0.5))
        hairline.line(to: NSPoint(x: bounds.width, y: 0.5))
        hairline.lineWidth = 1
        Palette.edge.setStroke()
        hairline.stroke()
    }
}

/// The **Keyword**, once it has been chosen. Sizes itself to the word — a fixed width would either
/// clip `personal` or leave a gap after `work`, and the field starts where the chip ends.
private final class KeywordChip: NSView {
    private static let height: CGFloat = 28
    /// Either side of the word, inside the band.
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

/// The rows under the field, one per matched **Manifest**.
///
/// Flipped, so a row's y is its distance from the field rather than from the bottom of a panel whose
/// height changes with every keystroke. The rows are built once and reused: F3's budget is a single
/// frame, and only which **Manifest** a row carries changes per keystroke.
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

    func present(_ choices: [SummonPanel.Choice], selected: Int?) {
        for (index, row) in rows.enumerated() {
            row.isHidden = index >= choices.count
            guard index < choices.count else { continue }
            row.show(choices[index], selected: index == selected)
        }
    }

    /// Move the band, leaving what the rows say alone — a different event from the list narrowing.
    func select(_ selected: Int?) {
        for (index, row) in rows.enumerated() { row.select(index == selected) }
    }

    /// The hairline between the field and the first row. Nothing is drawn when nothing matched,
    /// because there is no height to draw it in.
    override func draw(_ dirtyRect: NSRect) {
        let hairline = NSBezierPath()
        hairline.move(to: NSPoint(x: 0, y: 0.5))
        hairline.line(to: NSPoint(x: bounds.width, y: 0.5))
        hairline.lineWidth = 1
        Palette.edge.setStroke()
        hairline.stroke()
    }
}

/// One matched **Manifest**: the name it is known by, and the **Keywords** that reach it. The name
/// lines up under the typed text rather than under the mark, so the column you read is the column
/// you are typing into.
private final class RowView: NSView {
    private let name = NSTextField(labelWithString: "")
    private let keyword = NSTextField(labelWithString: "")
    private var selected = false

    /// How much of the row the **Keywords** may take before the name starts being truncated for
    /// them.
    private static let keywordWidth: CGFloat = 180

    /// Between one **Keyword** and the next. A dot rather than a comma or a space: the column is a
    /// list of things any one of which reaches the **Script**, and a space alone would read as one
    /// **Keyword** with a space in it, which is the one thing a **Keyword** cannot be.
    private static let between = " · "

    init(frame: NSRect, leading: CGFloat, margin: CGFloat) {
        super.init(frame: frame)

        // `labelColor` for the name, not the palette — see `Palette`. The **Keyword** is the one
        // exception, and `Palette.aside` says why.
        name.font = .systemFont(ofSize: 15)
        name.textColor = .labelColor
        keyword.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        keyword.textColor = Palette.aside
        keyword.alignment = .right
        name.lineBreakMode = .byTruncatingTail
        // From the *head*, unlike the name: the canonical **Keyword** is last in the column, and it
        // is the one that must survive a row too narrow for all of them — it is the **Script**'s
        // module name, so it is the only one guaranteed to be there.
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
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Starkit builds its views in code.") }

    /// Both kinds of row are the same two columns: what it is called, and the **Keywords** that
    /// reach it. The offer says what pressing ↩ would *do* on the left, because unlike every other
    /// row it is not naming something that already exists.
    ///
    /// The further **Keywords** come *before* the canonical one in a column that is right-aligned,
    /// so the canonical **Keyword** ends at the same x on every row whether a **Script** has others
    /// or not — a row that gained `yt` must not push `youtube` out of the column its neighbours
    /// keep.
    func show(_ choice: SummonPanel.Choice, selected: Bool) {
        switch choice {
        case .script(let manifest):
            name.stringValue = manifest.name
            name.textColor = .labelColor
            keyword.stringValue = (manifest.otherKeywords + [manifest.keyword])
                .joined(separator: Self.between)
        case .create(let typed):
            name.stringValue = "Create “\(typed)”"
            // Dimmed to the same colour the **Keyword** column uses: this row is a way out of the bar
            // rather than one of the things in it.
            name.textColor = Palette.aside
            keyword.stringValue = "new Script"
        }
        select(selected)
    }

    /// Redrawn only when the answer changed: a selection moving one row is told to every row.
    func select(_ selected: Bool) {
        guard self.selected != selected else { return }
        self.selected = selected
        needsDisplay = true
    }

    /// The band behind the selected row, inset far enough to read as a row inside the bar rather
    /// than as a second bar.
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
/// An unbezeled `NSTextField` draws its text at the *top* of its frame, so a frame taller than the
/// text puts the text high. Every label in the bar is unbezeled, so all of them go through here.
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
/// current at the moment of drawing.
///
/// Both fills go *over* the material rather than replacing it: `.hudWindow` is what makes the bar
/// sit in front of a desktop instead of on top of it, and a flat fill would spend that for a colour.
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

/// A borderless panel that can still take the keyboard. `NSWindow.canBecomeKey` is false without a
/// titlebar, and stating the override here keeps the question closed rather than depending on
/// `NSPanel`'s documented behaviour.
private final class KeyablePanel: NSPanel {
    /// What Escape does. Held on the window rather than the view because the field editor passes
    /// `cancelOperation:` up the responder chain when it has nothing of its own to cancel.
    var cancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    /// The Cocoa action selector, never a keycode — so ⌘. and anything else bound to cancelling
    /// arrives here for free.
    override func cancelOperation(_ sender: Any?) {
        cancel?()
    }
}
