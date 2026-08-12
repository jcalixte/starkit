# Starkit — MVP task list

Ordered. Rationale, dependencies and verification steps are in [plan.md](./plan.md); acceptance
criteria per slice are in [SPEC.md](../SPEC.md).

## Phase 1 — Foundations

- [x] **T0.1** `Package.swift`, `Info.plist` (`LSUIElement`), `main.swift` with a menu bar item
- [x] **T0.2** `setup-signing.sh` + signing in `build.sh` — adapt from `cmd-tab`
- [x] **T0.3** `~/.starkit` skeleton: `gleam.toml`, `starkit.gleam`, `entry.gleam`, 5 stubs, `gen-registry.sh`
- [x] **T0.4** `install.sh` — `/Applications`, idempotent seed, first `gleam build`
- [x] **T0.5** Paste spike (throwaway) — ⌘V into the previously frontmost app from a signed bundle

> **Checkpoint A** — reached. Installs, keeps its signature, and **Paste** measured at 23.1 ms
> against a 200 ms budget. The **Effect** survives as designed; what moved is C1 — the bar must
> take activation to be typed into, so T2.2 and T5.3 are one decision (`DESIGN.md` §9).

## Phase 2 — The spine, no UI

- [x] **T1.1** **Vocabulary** types + `work` **Script** + `entry.gleam` (`describe` / `run`)
- [x] **T1.2** C12 Toolchain — login-shell resolution, `starkit.toml` override, named error
- [x] **T1.3** C5 Builder + `Staleness` pure rule **+ its 4 tests**
- [x] **T1.4** C4 Runner — spawn `bun`, feed a run, decode **Effects**, 5 s deadline
- [x] **T1.5** C7 Effector — **Open** only
- [x] **T1.6** Isolation check — break `youtube.gleam`, confirm `work` still runs

> **Checkpoint B** — reached. `Starkit run work` opens four applications from a terminal, and with
> `youtube.gleam` not compiling the other four **Scripts** are untouched while `youtube` alone
> **Refuses**, carrying the Gleam error verbatim. Fixing it brings it back with no other step,
> which is the content-hash rule from T1.4 doing what mtimes could not. The architecture is
> proven end to end; everything after this is surface.

## Phase 3 — The bar

- [x] **T2.1** C3 HotKey ⌃⌘K + C10 MenuBarStatus red when the chord can't be held — the red is
      withdrawn, because macOS reports no such failure ([plan.md](./plan.md), `DESIGN.md` §4 F8)
- [x] **T2.2** C1 SummonPanel — built once at launch, activates, shown/hidden, Escape — and shown
      once invisibly there too, which is what building it at launch does not pay for
- [x] **T2.3** C2 Catalogue + `Keyword` pure parsing **+ its 3 tests** — and writing
      `manifests.json`, since C6 is the thing that would have and it is slice 6
- [x] **T2.4** Bar view — list, filter, selection, ↩ runs — off the main thread, because ↩ measured
      498 ms with every application already running
- [x] **T2.5** F13 — Cocoa action selectors, not keycodes: ⌃N/⌃P did come free, and the selection is
      bounded by the rows *shown* rather than by the matches, so ↩ cannot run a name off screen
- [x] **T2.6** A click outside **Dismisses** the bar — a mouse-down monitor, never
      `hidesOnDeactivate`, which cannot tell a click from a **Script**'s **Open**; and it needs no
      Accessibility, measured rather than assumed

> **Checkpoint C** — reached. ⌃⌘K **Summons** the bar in **10.7 ms**, `wo` narrows to Work, ↩ runs
> it, and ↑/↓/⌃N/⌃P move between the five. It goes away three ways and stays for the one that only
> looks like a fourth: another application taking focus with no mouse-down, which is T5.4's whole
> hazard answered before T5.4 exists. Still 2 of 5 **Scripts** usable (Work, Personal) — everything
> Phase 3 added is how you reach a **Script**, not how many there are.

> **Phase 5 is being taken before Phase 4.** Nothing in it depends on Clean — the dependency column
> in [plan.md](./plan.md) reads T2.4, T1.1, T0.5 — and it is the phase the plan itself calls the hard
> one, so the risk in it is worth meeting with four phases of slack rather than none. It also lands
> T5.4 while T2.4 and T2.6 are still warm, which is the code it rewrites. What it spends early is
> Checkpoint D's "nothing needs Accessibility yet".

## Phase 4 — Clean

- [x] **T4.1** `clean` **Script** — **tests first**, before it runs for real: the first run was a
      compile error, and emptying the untouchable list turns four assertions red, so the suite is
      known to catch the bug with no undo rather than assumed to. Two lists, because they are two
      promises — `keep` is yours to edit, and Starkit is untouchable whatever it says, since
      **Effects** are performed in order and a **Kill** aimed at Starkit ends the run halfway down
      its own list
- [x] **T4.2** C8 ContextGatherer + the `needs` → gather → payload path — 0.01 ms against F6's 5,
      and no `osascript`; the first read in a process costs 2.8–7.8 ms and buys the workspace
      connection rather than the list, so it is paid at launch where nobody is waiting. A **Need**
      this binary cannot gather is a **Refusal** naming it, because a **Script** handed half a
      **Context** decides about a machine that does not exist
- [x] **T4.3** C7 **Kill** — `forceTerminate`, verified at a scale that could be undone: a scratch
      home whose keep list spared everything but one expendable application, so the whole path ran
      and the terminal it ran from survived it. The first real **Kill** matched nothing, because
      `localizedName` is the name in the machine's language and this one calls Calculator
      *Calculatrice* — one string that **Opens** an application and cannot **Kill** it is a seam in
      the **Vocabulary**, closed by asking LaunchServices the same question C7 already asks for an
      **Open**. A **Kill** aimed at Starkit is a **Refusal**: the third lock, and the only one that
      holds for a **Script** that writes the name itself

> **Checkpoint D** — reached. 3 of 5, and the destructive **Script** closes what it was told to and
> nothing else. It cannot close the thing performing it, which is now true in three places and
> tested in one.

## Phase 5 — Youtube

- [x] **T5.1** **Input** stage + **Seed** from clipboard, arriving selected — and the declaration
      `CONTEXT.md` had described since before slice 0 with nothing in the types to express it: a
      **Script** **Asks** or **Decides**, which is a field on the constructor and therefore the one
      upgrade this design cannot migrate for you
- [x] **T5.2** `youtube` **Script** + tests (6 URL shapes) + `gleam_fetch` — taken before T5.1,
      because it needs no UI and proves the slice from a terminal; and it is where the **Vocabulary**
      grew **Fetching**, which `DESIGN.md` §9 left for the first fetching **Script** to decide
- [x] **T5.3** C7 **Paste** — restore focus, ⌘V, leave the pasted text on the clipboard; and the
      held-modifier hazard `DESIGN.md` §9 has carried since T0.5, closed with `.privateState`
      before it was ever seen
- [x] **T5.4** **Notify** in the bar, spinner, 5 s kill — and the answer to what T5.3 handed it: the
      bar goes when the run has nothing left to say. A **Refusal** shows there too, because a run
      killed at 5 s is a spinner stopping and a bar vanishing with the reason in a tooltip; C10 keeps
      it for after the bar has gone, which is the half F12 names
- [x] **T5.5** Accessibility grant survives a rebuild — after making the criterion into a test, since
      a rebuild of unchanged source is byte-identical and would have passed whatever TCC keyed on.
      Against a bundle that genuinely differs it holds: the designated requirement names the
      identifier and the certificate leaf, and neither the code hash nor the path is in it

> **Checkpoint E** — reached. 4 of 5, and the only permission-gated path in the system works and
> keeps working across a rebuild, a re-signing and a delete-and-reinstall of the bundle. What ends
> the grant is a second certificate, which is the one thing `setup-signing.sh` refuses to make.

## Phase 6 — Link from url

- [x] **T6.1** `link` **Script** + tests, including the pages the `h1` scan gets wrong — a scan and
      not a regex, because Gleam's stdlib has none and a sixth dependency buys nothing: the pages
      that come out wrong are the same either way, since the limit is *not a DOM parser*. Two thirds
      of the 26 cases assert a wrong answer on purpose, so the limit is a shape rather than a
      rumour, and one of them is real — `blog.rust-lang.org` serves no `h1` at all. `normalise` also
      moved out to a vendored `text.gleam` here, which is the decision T5.2 left to the second
      caller: one mapping both notes share, paid for with the isolation a **Script** used to have
- [x] **T6.2** Non-`https` **Input** → **Notify** — named back where there is a scheme (`http`,
      `ftp`, `file`), because "no" without the reason is a bar you argue with, and where there is
      none the message names the fix instead, since a bare host is the common case. The reason it
      is refused at all: this **Script**'s output is a page's heading written into a note verbatim,
      and over cleartext that heading is whoever is in the middle's to choose

> **Five of five.** Every **Script** the MVP specifies now works, and what is left is boot and
> numbers — no new **Vocabulary**, no new permission, nothing a **Script** has not already done.

## Phase 7 — Boot

- [ ] **T7.1** C9 LoginItem — `SMAppService`, lifted from `cmd-tab`, minus the `isEnabled: Bool` it
      came with: what that answers is "are we registered", and what a menu needs is "what does macOS
      say now". So the menu is built when it opens and never on a state change, and `install.sh`
      turns it on through the *installed* bundle, since the registration belongs to the bundle and
      not to the running instance. From an empty environment ⌃⌘K is live at 82 ms and all five
      **Scripts** are listed at 734 ms against F9's 3 s — **but the criterion is a reboot, and that
      is owed**
- [x] **T7.2** Moving the bundle and back does not silently unregister — and it does not, measured
      against `sfltool dumpbtm` rather than our own report, since the report is the thing in
      question: the record follows the bundle to `/tmp` and back, and a delete-and-`ditto`, which is
      what every install does, does not move it at all. `SMAppService` answers about a *bundle* and
      not a path, which is why the `swift build` binary cannot register and why the whole hazard is
      smaller than it looks. Then the same round trip through the running app — turned off from a
      terminal behind its back, the menu came up unticked, and clicking it turned it back on

## Phase 8 — Close the budget

- [x] **T8.1** `--bench` flag; record actuals for all 7 rows of `DESIGN.md` §8 — four of them are the
      flag's, and it performs no **Effects**, since twenty iterations of `work` would open eighty
      applications. F1 starts at a keypress and C1 prints itself, F8 is not a duration, F9's whole
      number is a launch: those three are quoted from the slices that took them. F14 came free — a
      three-line `spin` in a scratch home dies at 5004–5007 ms, and the overshoot is the semaphore
      wait before `SIGKILL`. **F5 has drifted to 27–29 ms and the spawn is innocent**: `registry.gleam`
      imports every **Script**, so `work` loads `gleam_fetch` to open four applications, and taking
      the two fetching **Scripts** out of a scratch registry brings back T1.4's number exactly. Left
      unfixed on purpose — a lazy import per **Keyword** is a C4 decision. Also settled: the
      `starkit.toml` override deletes C12's 330 ms rather than trimming it (0.063 ms), and **F7's
      "≤ 10 ms otherwise" is withdrawn**, because an **Open** costs what LaunchServices costs and a
      budget over what Starkit does not control can be neither met nor missed
- [x] **T8.2** Idle RSS and CPU for G4, recorded next to Script Kit's in `DESIGN.md` §3 — 0 ms of CPU
      across 300 s against a 0.47 s lifetime, all of it spent at launch, because nothing polls or
      watches until the chord arrives. Memory is two numbers rather than one: 86 MB resident, mostly
      AppKit pages shared with every application on the machine, and 21 MB phys footprint, which is
      what quitting would give back. Script Kit's half stays blank — measuring it means launching it,
      and its event tap would take ⌃⌘K off the machine being compared

> **Every row carries a number, and one criterion is still owed.** Six of the seven budgets are met;
> F5 is ~8 ms over, of which 4.7 is `gleam_fetch` loaded by **Scripts** that do not fetch, and the
> judgement from T1.4 stands — this is a threshold about imperceptibility. The one thing outstanding
> in the whole MVP is T7.1's criterion: a machine restarting and the item being there. The budget
> behind it is answered; the reboot is not.

## Phase 9 — Authoring (slice 6, taken after MVP)

- [x] **T9.1** The registry rule moves into Swift — because C6 runs inside an installed bundle with no
      repo beside it and could never have called `gen-registry.sh`, and because two implementations
      writing one file is worse than the inconvenience: the output has to be byte-identical or
      `registry.gleam`'s mtime moves, and that marks **every Script Stale**, since it is one of C5's
      shared modules. So the rule is pure and in `StarkitCore` with 5 tests, the filesystem half is
      C6's, and `gen-registry.sh` is gone. The port was **diffed against it** rather than reasoned
      about — same scratch directory, a `link_check`/`linkedin` pair for the ordering, and the only
      difference is the two header lines changed on purpose. `gleam format --check` passes on what it
      writes for five **Scripts** and for none, which is the mtime claim checked instead of asserted;
      and a home with no **Scripts** compiles, because `[]` alone cannot typecheck in Gleam and the
      annotation has to go on a binding. `install.sh` asks the installed bundle for it now
- [x] **T9.2** C6 Watcher — `FSEvents` on `src/` → regenerate, build, rewrite manifests, menu bar state,
      with a launch and a save running **one** sequence rather than two that could drift: the registry
      goes before the build, since the build compiles what the registry imports, and that order now
      exists once. **FSEvents' own latency window is unusable here** — at 100 ms it delivered the first
      event of a quiet period up to 509 ms late, spending F10's whole budget before Starkit was told
      anything, and `NoDefer` is documented to prevent exactly that. A zero window fixed the latency
      and broke the coalescing, because Zed saves by writing a temporary and renaming it, which
      measured as two rebuilds — so the coalescing is a 50 ms timer of ours. **201–238 ms save to
      rebuilt**, 73–87 ms of it Starkit's own work; a broken save reaches the menu bar in 169 ms with
      the other **Scripts** still running from the last good build. Adding a **Script** costs one extra
      pass, because writing the registry is a change inside the watched tree, and it converges rather
      than being filtered by a name an editor chooses. Idle CPU did not move with the stream running,
      which closes the row T8.2 left open
- [x] **T9.3** C11 Scaffolder — `Create "<keyword>"`, template, open in Zed. **"Never the default
      selection" became a type**: the bar's selection is `Int?`, so with no match there is nothing
      selected and ↩ has nothing to act on — as a guard against index zero it would have been a rule to
      remember in three places, and its failure would be silent *and* would make misspelling a
      **Keyword** the fastest way to write a file. A row is `.script(Manifest)` or `.create(String)`
      rather than a **Manifest** with a flag, because a made-up **Manifest** reaching `run` is the bug
      worth making unwriteable — and that change turned up a real one: `ask` emptied `matches` while the
      panel's height now comes from `choices`, so the **Input** stage kept the list's height under a
      question with no list. C11 **writes one file and stops** — C6 makes it real, which is why F11's
      "0 registry edits" holds and why the bar and Zed are the same event — and it **never overwrites**,
      since a **Script** that has never compiled is missing from the list while its file is right there.
      The template was checked by letting C6 build the exact bytes it emits: listed 174 ms later, runs,
      and `gleam format`-clean. **It shipped crashing and that is the lesson**: `Data.write` was given
      `[.atomic, .withoutOverwriting]`, which Foundation traps on unconditionally — a `fatalError`, so
      the `do/catch` was decoration and every ↩ on that row killed the app. `.withoutOverwriting` is
      the half kept, since clobbering a **Script** is the only outcome that loses work. It reached
      someone because **C11 was the one component the debug CLI could not reach**, so its only
      filesystem call had never been executed; `Starkit create <keyword>` fixes that properly, and no
      test would have — the write is in the app module and a mock would have passed. Now exercised:
      writes, refuses to overwrite an edited file, names an invalid **Keyword**, and C6 lists the
      result 238 ms later. **Driven by hand afterwards**: the offer was taken from the bar, the file
      appeared, and the **Script** it wrote was later deleted from the bar too. ↩ on a typo doing
      nothing is the one criterion nobody has pressed, and it is the one the `Int?` selection makes
      unwriteable rather than merely unlikely

## Phase 10 — Taking a Script away

- [x] **T9.4** F16 — ⌃D twice on a selected **Script** moves it to the Trash, plus `Starkit delete`.
      **The home row is the hard part**: every candidate is already a text-editing binding, so ⌃D was
      spent knowingly — it stops deleting a character in the **Keyword** field, and the **Input** stage
      hands it back, since there the field holds an answer. It still arrives as the selector Cocoa
      names, so T2.5's no-keycodes rule survives. The friction is a **question in the list's place**
      rather than a label on the row: the two are already exclusive, and the row version was removed
      instead of left, because `message != nil` hides the list and that state could not be reached. The
      armed **Keyword** is held and never the row index, so narrowing, moving and a new **Catalogue**
      all disarm — deleting the wrong file is the only mistake here that pressing something else cannot
      undo. **A Script's test is part of it**, learned by deleting one: `gleam build` typechecks
      `test/`, so trashing `youtube.gleam` while `youtube_test.gleam` still imported it broke the whole
      project 200 ms later and turned the menu bar red. Both move now, both are named in the question,
      both recoverable — the **Trash**, never `unlink`, because `~/.starkit` is not a repository
- [x] **T9.6** F17 — ⌥↩ (and ⌃O, free: macOS binds both to `insertNewlineIgnoringFieldEditor:`) opens
      the selected **Script** in Zed, plus `Starkit edit <keyword>`. The cheapest key in the bar to
      take, because inserting a newline *ignoring the field editor* has no meaning in a one-line field
      — where ⌃D cost F16 the field's forward-delete. Read out of `StandardKeyBinding.dict` rather than
      guessed, which is how it came up that ⌘↩ is not a text binding at all and would have needed the
      keycodes T2.5 spent a slice avoiding. **Refuses** when the file is gone rather than writing a
      template over the question. Confirmed by hand — and the first report that it did not work was a
      build that had been committed but not installed, which is its own lesson about what "shipped"
      means when the thing under test is a bundle in `/Applications`
- [x] **T9.8** ⌘V works in the bar — and ⌘C, ⌘X, ⌘A, ⌘Z, which were equally dead. **A dispatch path,
      not a bug**: ⌃N/⌃P/⌃A/⌃E/Escape all arrive through `StandardKeyBinding.dict` and the field editor
      and need no menu, which is T2.5's finding; ⌘ chords are dispatched by AppKit as *menu key
      equivalents*, so an app with no `NSApp.mainMenu` has nothing to dispatch them to. Fixed with a
      main menu an `LSUIElement` app never draws — invisible, which is why the gap was invisible too.
      **T5.1 hid it for six phases**: an **Input** arrives **Seeded** from the clipboard and selected,
      so the case ⌘V exists for had already happened, and pasting anything else was impossible. Proved
      in a throwaway harness before shipping — same menu, real `NSTextField`, synthetic ⌘V through
      `performKeyEquivalent`, marker landed, clipboard saved and put back
- [x] **T9.7** F18 — a **Script** declares `other_keywords: ["yt"]` and the bar matches them. **The
      glossary said no first**: `CONTEXT.md` bans "alias" and asserted exactly one **Keyword** per
      **Script**. Reversing the ban was the wrong fix — by its own definition a shorthand typed into the
      same field *is* a **Keyword**, so the **cardinality** moved instead, to "exactly one *canonical*
      **Keyword**, which is its module name, and any number more". It was called `aliases` for twenty
      minutes first, which is the drift that document exists to catch. Matching is **four bands** —
      canonical exact, other exact, canonical prefix, other prefix — because two letters is the fastest
      thing to type and `yt` must not sit behind every **Script** merely starting with those letters,
      while a **Keyword** typed in full still wins outright. **A breaking constructor change**, the
      second this design has spent (T5.1 was `asks`): Gleam has no default field values, and it is the
      only legal home, since `SPEC.md` forbids per-**Script** configuration outside its **Manifest**.
      The five **Scripts** here were migrated one line each with the diff shown, and the wire name is
      pinned by a test — a Swift property renamed without its `CodingKey` decodes to none, and `yt`
      would stop finding anything with nothing reporting why
- [x] **T9.5** `login` → `start-at-login`, because `Starkit login on` reads as a sentence about an
      account and Starkit has none. The menu has said **Start at Login** since T7.1; one thing, one name

> **Still owed: T7.1's reboot.** Everything else on this list is done, and slice 6 has nothing left
> deferred behind it.

