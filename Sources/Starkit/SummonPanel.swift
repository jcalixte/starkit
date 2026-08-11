import AppKit
import StarkitCore

/// C1 — the bar itself: one panel, built at launch, **Summoned** and **Dismissed** forever after.
///
/// Built once because F1's budget is 50 ms from ⌃⌘K and a window is the expensive part of showing
/// one. Constructing it lazily would put that cost on the first **Summon** of a session, which is
/// the one a person waits for having just booted — so it is paid at launch, where nothing is
/// waiting, and every **Summon** after is an `orderFront`.
///
/// The panel takes activation. T0.5 established why and it is not a preference: macOS routes keys
/// to the *active* application's key window, so a panel belonging to an inactive application can be
/// on screen and still receive nothing. What that costs is a focus to hand back, which `dismiss`
/// does here and C7 will do again before **Paste** (`DESIGN.md` §9).
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
    /// to type, which is what the field is for. It is also where the selection stops, for the same
    /// reason: see `move`.
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
    /// A callback rather than a **Runner** held here: C1 is the bar — **Summon**, **Dismiss**,
    /// narrow, keys — and building an **Artefact** and performing **Effects** is C5, C4 and C7's
    /// work in that order.
    /// Giving the panel a **Toolchain** would put the whole spine behind the one component whose job
    /// is to be on screen in 50 ms.
    ///
    /// The third argument is the run being started. Whoever performs it hands it back to `notify`
    /// and `settled`, which is how a run the person walked away from is stopped from speaking into
    /// the bar that came after it.
    var run: ((Manifest, String, Int) -> Void)?

    /// Every **Script** Starkit knows about, which is not the same as every **Script** it can run
    /// (F2). Assigned by the delegate at launch — from the cache first, then from `describe` — and
    /// narrowed immediately either way, so the panel is already the right height before the first
    /// **Summon** rather than resizing while someone is looking at it.
    var catalogue: [Manifest] = [] {
        didSet { narrow() }
    }

    /// Which of the two things the bar is asking for.
    ///
    /// The **Keyword** stage lists **Scripts** and narrows as you type. The **Input** stage has one
    /// **Script** chosen and asks the question it declared — no list, because there is nothing left
    /// to choose, and no narrowing, because what is being typed is an answer.
    ///
    /// A **Script** that `Decides` never reaches the second stage, which is what makes the field a
    /// **Keyword** and not a prompt: Work and Clean run on one ↩ exactly as they did before it
    /// existed.
    private enum Stage {
        case keyword
        case input(Manifest)
    }

    private var stage = Stage.keyword

    /// What was typed in the **Keyword** stage, held while the **Input** stage is up so Escape can
    /// put it back. Escape going one stage back rather than all the way out is what makes ↩ on the
    /// wrong **Script** cost one keystroke instead of a re-**Summon**.
    private var typed = ""

    /// What the **Keyword** typed so far selects, in the order it will be listed.
    private var matches: [Manifest] = []

    /// Which of them ↩ runs. Moved by `move`, and never off the rows on screen.
    private var selected = 0

    /// How many runs the bar has started. The current one is the only one allowed to speak.
    ///
    /// A **Dismissal** abandons whatever was in flight — the run itself carries on, because a
    /// `bun` already spawned is not something a keystroke should be able to unspawn, but it has
    /// nothing to say here any more. Without this, a **Script** hung against its 5 s deadline could
    /// **Notify** into a bar **Summoned** afterwards for something else entirely.
    private var runs = 0

    /// Whether a run is in flight, which is the spinner and the locked field.
    private var working = false

    /// Whether the run in flight has already put something on screen, so a run that said its piece
    /// leaves the bar up rather than **Dismissing** it out from under the sentence.
    private var spoke = false

    /// What is on screen instead of the list — a **Notify** from a **Script**, or a **Refusal** in
    /// Starkit's own voice. The list and a message never share the bar: the list is what you could
    /// choose and the message is what happened, and only one of those is the answer to ↩.
    private var message: String?

    /// When the **Summon** being measured started, or 0 between them.
    private var summonedAt: CFAbsoluteTime = 0

    /// What is watching for the click that **Dismisses** the bar, or nothing while it is down.
    private var clicksElsewhere: Any?

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
        // reasons, and since T5.4 the design needs it: a **Script** runs with the bar still up, and
        // both an **Open** it performs and the hand-back before a **Paste** activate another
        // application. Auto-hiding would take the bar away mid-run, spinner and all. A **Dismissal**
        // stays something asked for — ⌃⌘K, Escape, or a click outside (`watchForClicksElsewhere`),
        // none of which a launch can be mistaken for.
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

        // Placed once and never again: the sentence sits a footer above the bottom edge, and it is
        // the panel that grows to hold it rather than the view that moves. Keeping it out of
        // `layOut` is what keeps F3's budget about narrowing.
        messages.setFrameOrigin(NSPoint(x: 0, y: Self.footer))
        messages.isHidden = true
        background.addSubview(messages)

        panel.contentView = background
        super.init()

        // Everything typed reaches C1 through the field: `controlTextDidChange` narrows, and
        // `doCommandBy` is where ↩ arrives as a selector rather than as a key (F13).
        field.delegate = self
        // Escape is one stage back before it is a **Dismissal**, which is the only key in the bar
        // whose meaning depends on which stage is up.
        panel.cancel = { [weak self] in
            guard let self else { return }
            if case .input = self.stage { self.stopAsking() } else { self.dismiss() }
        }
        placeField()
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

    /// Put the panel on screen once, invisibly, so the first real **Summon** is not what pays for it.
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
        if panel.isVisible { dismiss() } else { summon() }
    }

    func summon() {
        let start = CFAbsoluteTimeGetCurrent()
        summonedAt = start

        // Narrowed before it is placed, because placing depends on how tall it is. Nothing has been
        // typed at this point, so this is the whole **Catalogue** — a bar that lists what you have
        // rather than an empty box you must already know the answer to fill.
        narrow()
        place()
        watchForClicksElsewhere()
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
    /// before a **Paste**. It is also why the act has its own name: `hide` is what AppKit calls one
    /// of the things a **Dismissal** does, not the **Dismissal** itself.
    ///
    /// The field is emptied *after* the panel is off screen: clearing it narrows back to the whole
    /// **Catalogue**, which shrinks the panel, and doing that first would be a bar collapsing on its
    /// way out.
    ///
    /// `NSApp.hide` only while Starkit still has the activation to give back. Since T5.4 the bar is
    /// on screen while a run performs its **Effects**, and C7 hands focus back itself before a
    /// **Paste** — so by the time this runs the person is usually already back in the application
    /// that was pasted into, and hiding an application that is not active is a message to the window
    /// server about nothing.
    func dismiss() {
        summonedAt = 0
        stopWatchingForClicksElsewhere()
        panel.orderOut(nil)
        if NSApp.isActive { NSApp.hide(nil) }
        // Whatever was in flight loses the bar it was going to speak into. The run itself carries
        // on — a `bun` already spawned is not something a keystroke can unspawn, and its **Effects**
        // are still performed — but it stops being this bar's business.
        stopWorking()
        // Dropped before the stage is left, so a **Dismissal** in the middle of a question does not
        // restore the **Keyword** that asked it into a field about to be emptied anyway.
        typed = ""
        stopAsking()
        field.stringValue = ""
        message = nil
        narrow()
    }

    /// Watch for the click that means the bar is not what is being reached for.
    ///
    /// A **global** monitor, which sees only what is on its way to *another* application — so a click
    /// on the bar itself never arrives here. That is the whole definition of "outside", decided by
    /// the window server rather than by hit-testing a frame, and it means the menu bar item is inside
    /// too, because the item is Starkit's as much as the panel is.
    ///
    /// Not `hidesOnDeactivate`, which is the one-line version and answers the wrong question. Since
    /// T5.4 a **Script** runs with the bar still up and an **Open** it performs activates another
    /// application: the same lost focus as a click, and it must not put the bar away. A mouse-down
    /// answers the *person*, so a launch can never be mistaken for a **Dismissal**, and T5.4 needed
    /// no "is a run in flight" flag to protect the difference — the mechanism chosen two tasks
    /// earlier for a hazard that had not arrived yet turned out to need nothing added to it.
    ///
    /// Only while the bar is up. A monitor left installed forever would have Starkit in the path of
    /// every click on the machine for the ~99% of the time it has nothing on screen, and G4 is a
    /// promise about what Starkit costs while idle.
    ///
    /// All three buttons, because the question is whether a person touched something else and no
    /// button answers it differently.
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

    /// ↩ — run what is selected, and stay to see what happens.
    ///
    /// **The bar no longer leaves first.** Until T5.4 it hid before the run started, because a bar
    /// sitting there through four seconds of a cold Electron **Open** (T1.5) is indistinguishable
    /// from a hang. A spinner is what makes the difference visible, and once the difference is
    /// visible the bar is the right place for what the run has to say — F14 asks for the spinner and
    /// the **Vocabulary** asks for a **Notify** to be shown "in the **Shelf** itself, while it is
    /// still on screen".
    ///
    /// What that costs is the hand-back that hiding used to do for free: C7 now performs it itself
    /// before every **Paste**, which is the wait T5.3 wrote and did not have to pay.
    ///
    /// The **Keyword** run is the **Manifest**'s and not what was typed: `wo` selects Work and Work
    /// is what runs.
    ///
    /// In the **Input** stage ↩ is the second one — the **Script** is already chosen and this is its
    /// answer.
    private func accept() {
        // A second ↩ while the first is still running would start a run the bar cannot show, since
        // there is one spinner and one message. The field is locked for the same reason.
        guard !working else { return }

        switch stage {
        case .keyword:
            guard matches.indices.contains(selected) else { return }
            let manifest = matches[selected]
            let input = Keyword.split(field.stringValue).input
            // A question already answered is not asked. Typing the **Input** on the same line as
            // the **Keyword** is the shortcut for someone who already knows the answer, and it is
            // what ↩ did before the stage existed — the stage is for the case where nothing was
            // typed after the **Keyword**, which is the case the **Seed** is for.
            if let question = manifest.asks, input.isEmpty {
                ask(manifest, question: question)
                return
            }
            run?(manifest, input, began())

        case .input(let manifest):
            // Whole and verbatim. The field holds the **Input** alone here, so splitting it again
            // would read the first word of an answer as a **Keyword**.
            run?(manifest, field.stringValue, began())
        }
    }

    /// The bar, working: the mark becomes a spinner and the field stops taking keys.
    ///
    /// Locked rather than merely ignored, because a **Keyword** narrowing under a spinner would be
    /// the bar answering a question nobody asked — the run in flight is already the answer to the
    /// last one. Escape still arrives, because it reaches the window rather than the field.
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

    /// A **Script** saying why it did nothing — C7 performing a **Notify**, arrived on the main
    /// thread.
    ///
    /// Dropped rather than shown if the bar it was meant for has gone. A **Notify** belongs in the
    /// **Shelf** *while it is still on screen*; a bar that came back on its own to deliver a
    /// sentence would be the window SPEC says never appears, and it would be delivering it to
    /// someone who has moved on.
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
    /// A **Refusal** lands here as well as in the menu bar. F12 asks that the message survive the
    /// bar closing, which C10 is what answers — but the bar is now the thing in front of the person
    /// at the moment it happens, and the deadline is the case that proves it: a run killed at 5 s
    /// with the sentence only in a tooltip would be a spinner that stopped and a bar that vanished.
    /// Two places, one for each question — what happened, and what is still wrong.
    ///
    /// Nothing said and nothing wrong means the run did what was asked, and the bar has no further
    /// business being on screen.
    func settled(_ refusal: String?, for run: Int) {
        guard run == runs, working else {
            // Said out loud for the same reason a dropped **Notify** is, and it is the louder of
            // the two: a run abandoned at Escape still reaches its deadline, and "the bar stayed
            // away" and "the bar never heard" are the same picture from the outside.
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

        // Back to a field that can be typed into: after a **Notify** the answer is usually one edit
        // away from being right, and ↩ from there is the whole repair. The caret is coloured after
        // the field editor exists again, for the reason `summon` does it there — it belongs to the
        // editor and not to the field, and locking the field is what took the editor away.
        panel.makeFirstResponder(field)
        (panel.fieldEditor(false, for: field) as? NSTextView)?.insertionPointColor = Palette.accent
    }

    /// Put a sentence where the list was, and grow the bar to hold it.
    ///
    /// - Parameter inStarkitsVoice: a **Refusal** rather than a **Notify**. Who is talking is the
    ///   one thing a person cannot work out from the words — "no network" from a **Script** and
    ///   "killed after 5 seconds" from Starkit read the same at a glance — so it is marked rather
    ///   than worded, in the same column and with the same symbol C10 uses.
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
    /// The list goes rather than being replaced by the chosen **Script**'s name: the bar is a list
    /// of what you are choosing from, and there is nothing left to choose. What remains is the head
    /// — the **Keyword** you typed, now a chip in the same column it was typed in, and the question
    /// where the **Keyword** used to be.
    ///
    /// The **Seed** arrives selected, which is what makes accepting it one keystroke and replacing
    /// it none (`CONTEXT.md`). An empty clipboard **Seeds** with nothing and the stage arrives
    /// anyway — the **Seed** is what the **Input** starts out holding, not whether it is asked for.
    private func ask(_ manifest: Manifest, question: String) {
        typed = field.stringValue
        stage = .input(manifest)

        let seed = NSPasteboard.general.string(forType: .string) ?? ""
        keywordChip.show(manifest.keyword)
        field.placeholderAttributedString = Self.placeholder(question)
        field.stringValue = seed
        field.currentEditor()?.selectAll(nil)
        placeField()

        // Nothing matches in this stage, which is what takes the list away and shrinks the panel
        // back to the head. A message from an earlier run goes with it: the question being put up
        // is a new one.
        message = nil
        matches = []
        selected = 0
        list.present([], selected: 0)
        fit()

        report("   \(manifest.keyword) asks for \(question) — Seeded with \(seed.count) characters")
    }

    /// Back to the **Keyword** stage, with what was typed still in the field.
    ///
    /// Escape's first meaning, and also what a **Dismissal** does on its way out, so the bar is
    /// never **Summoned** back into the middle of a question nobody remembers being asked.
    ///
    /// The caret goes to the end rather than selecting what comes back: this text is being returned
    /// to, not offered, and a **Keyword** that vanishes on the next keystroke is not what the person
    /// left there.
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

    /// Move the selection one row, in whichever direction Cocoa was asked for.
    ///
    /// Bounded by what is *shown* rather than by what matched. The list is capped at `mostRows` and
    /// the way past the last of them is to type, so a selection that could travel past the eighth
    /// row would be ↩ running a **Script** whose name is not on screen — the one thing a bar that
    /// lists rather than guesses must never do.
    ///
    /// It stops at the ends rather than wrapping. With at most eight rows in front of you, wrapping
    /// saves a keystroke that was never expensive and costs the certainty of knowing where the band
    /// went; every macOS launcher this bar is measured against stops too.
    private func move(by step: Int) {
        let shown = min(matches.count, Self.mostRows)
        let next = min(max(selected + step, 0), shown - 1)
        guard shown > 0, next != selected else { return }
        selected = next
        list.select(selected)
    }

    /// Narrow the list to what has been typed, and grow or shrink the panel to hold the result (F3).
    ///
    /// Narrowing puts a message away, because narrowing is choosing a different **Script** and the
    /// message was about the last one. Typing an **Input** does not narrow and does not clear it: at
    /// that point the sentence on screen is what the edit is answering, and it should still be there
    /// while it is being answered.
    private func narrow() {
        message = nil
        matches = Keyword.matches(Keyword.split(field.stringValue).keyword, in: catalogue)
        selected = 0
        list.present(Array(matches.prefix(Self.mostRows)), selected: selected)
        fit()
    }

    /// Grow the panel downwards to hold whatever is under the head, keeping its top edge where it
    /// was.
    ///
    /// The field must not move while someone is typing into it, so the height changes at the bottom
    /// and the origin moves to compensate — an `NSWindow` frame is measured from its bottom-left,
    /// which is the corner that has to give.
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

    /// How much bar there is below the head: a message, or the rows, or neither.
    ///
    /// Never both. A list is what you could still choose and a message is what already happened, and
    /// a bar showing both would be offering ↩ two meanings at once.
    private func under() -> CGFloat {
        if message != nil { return messages.frame.height + Self.footer }
        let shown = min(matches.count, Self.mostRows)
        return shown == 0 ? 0 : CGFloat(shown) * Self.row + Self.footer
    }

    /// The head at the top, whatever the bar is showing under it, filling what is left.
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

    /// Where the field starts, which is after the **Keyword** chip when there is one.
    ///
    /// The chip takes the column the typed text was in, so the **Keyword** does not move when it
    /// stops being editable — it is the same word in the same place, no longer being typed.
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

    /// The one piece of text in the bar that is Starkit talking rather than the person — "Keyword"
    /// in the first stage, and an asking **Script**'s question in the second.
    ///
    /// In the accent rather than the system's grey, which is what says whose voice it is without a
    /// second element on screen to say it with. Taken towards the background it sits on, because
    /// periwinkle at full strength on cream is a colour rather than a word.
    private static func placeholder(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 21),
                .foregroundColor: Palette.placeholder,
            ]
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
        // Nothing narrows in the **Input** stage. The **Script** is chosen and what is being typed
        // is its answer, so there is no **Keyword** in the field to match against.
        guard case .keyword = stage else { return }
        let start = CFAbsoluteTimeGetCurrent()
        narrow()
        report("   \(matches.count) of \(catalogue.count) Scripts in \(milliseconds(since: start))")
    }

    /// F13 inside the field: the selector Cocoa names for the key, never the key itself.
    ///
    /// Three selectors, four ways of pressing them — ⌃N and ⌃P are `moveDown:` and `moveUp:` in
    /// macOS's own key bindings, so they arrive here having cost nothing, and so would anything else
    /// a person has bound to moving. That is the whole of F13's argument, and it is why ↩ was read
    /// as `insertNewline:` at T2.4 rather than as a keycode that would have been deleted now.
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
        // Everything else is the field editor's, including the arrows that move along the line a
        // **Keyword** and an **Input** are typed on.
        default: return false
        }
        return true
    }
}

/// Starkit's mark at the head of the bar, and the spinner it turns into while a run is in flight.
///
/// The same square in the same place rather than a second element appearing beside it: the mark is
/// the one thing in the bar that is Starkit rather than the person, and a run is Starkit working.
/// A spinner somewhere else would be a new thing to look at; this is the thing you were already
/// looking at, doing something.
///
/// Cream on periwinkle rather than the fruit's own yellow on the blur: at 20pt over a material that
/// could be anything, the palette's creams have no contrast to spend. The chip is what gives the
/// glyph a background it can be light against, and it is the same mark as the menu bar's, which is
/// the point of them matching.
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
        // Forced light in both appearances, because what it sits on is the periwinkle chip and not
        // the window — the same reason the glyph it replaces is cream rather than `labelColor`.
        spinner.appearance = NSAppearance(named: .darkAqua)
        // Not drawn at all between runs, so the chip is the mark and nothing else while the bar is
        // idle — and no animation is left turning where nobody asked for one (G4).
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
/// One sentence, wrapped, in the column the names and the typed text are in — so it reads as the
/// answer to what was typed above it rather than as a new element. `detail` never reaches here: a
/// Gleam diagnostic or a stack trace is many lines and belongs on stderr, which is where C4 already
/// puts it.
///
/// A **Refusal** carries C10's symbol in the mark's column, and a **Notify** carries nothing. That
/// is the whole of whose-voice-is-this, and it is marked rather than worded because the words
/// themselves cannot say it — "there is no network" from a **Script** and "killed after 5 seconds"
/// from Starkit read identically, and only one of them is something a **Script** author wrote.
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
        // Wrapped rather than truncated, unlike every other label in the bar. A **Keyword** that
        // does not fit can be recognised from its first half; a sentence saying what went wrong
        // cannot, and it is the only text here a person has to read all of.
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
        // The cell asked how tall it needs to be at this width, which is the only measurement that
        // accounts for the wrapping — a label's intrinsic size is a single line unless something
        // tells it what width it has.
        let space = NSRect(x: 0, y: 0, width: room, height: .greatestFiniteMagnitude)
        let height = (sentence.cell?.cellSize(forBounds: space).height ?? Self.padding).rounded(.up)
        sentence.frame = NSRect(x: leading, y: Self.padding, width: room, height: height)
        setFrameSize(NSSize(width: frame.width, height: (height + Self.padding * 2).rounded(.up)))

        symbol.isHidden = !inStarkitsVoice
        // Centred on the *first line* rather than on the block, so a sentence that wraps to two
        // lines still starts where the symbol says it does — and in the mark's own column, which is
        // the column Starkit speaks from at the head of the bar.
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

/// The **Keyword**, once it has been chosen: what you typed, become the thing you chose.
///
/// Monospaced and on the accent band, which are the two things the rows already say about a
/// **Keyword** — it is a thing to be typed, and this one is the selected one. The stage change is
/// the same selection carried up into the head rather than a new idea about colour.
///
/// It sizes itself to the word, because a fixed width would either clip `personal` or leave a gap
/// after `work`, and the field starts where the chip ends.
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

    /// Move the band, leaving what the rows say alone. Which **Manifest** a row carries changes when
    /// the list narrows, and that is a different event from the selection moving within it.
    func select(_ selected: Int) {
        for (index, row) in rows.enumerated() { row.select(index == selected) }
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

        // `labelColor` for the name, not the palette. Palette is explicit that it does not replace
        // the system's text colours: those already answer light and dark correctly, and a periwinkle
        // name would be a legibility bug on whichever appearance was not being looked at while
        // choosing it. The palette's job here is the band behind the selected row.
        //
        // The **Keyword** is the exception, and `Palette.aside` says why: `secondaryLabelColor` is
        // weighted for an opaque window, and this bar is not one.
        name.font = .systemFont(ofSize: 15)
        name.textColor = .labelColor
        keyword.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        keyword.textColor = Palette.aside
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
        select(selected)
    }

    /// Redrawn only when the answer changed. A selection moving one row is told to every row, and
    /// two of them are the only ones it is news to.
    func select(_ selected: Bool) {
        guard self.selected != selected else { return }
        self.selected = selected
        needsDisplay = true
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
        // Backing first, then the cream over it: the first says how dark the bar is, the second says
        // whose bar it is. Both go over the material rather than replacing it, so the blur is still
        // doing the work of sitting in front of a desktop — it just no longer decides the contrast.
        Palette.backing.setFill()
        outline.fill()
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
