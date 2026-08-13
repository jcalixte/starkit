# Starkit — Design (QFD)

How Starkit delivers what `CONTEXT.md` names. This document owns goals, measurable functions,
chosen approaches, and the trade-offs taken. It does not define vocabulary, which is `CONTEXT.md`'s
job, and it does not record hard-to-reverse decisions, which live in `docs/adr/`.

Every target below comes from a measurement on the development machine and not an estimate.
Where a number appears without a source, it is a budget still to be verified.

Strength weights used in matrices: **9** strong, **3** medium, **1** weak, blank none.

---

## Houses of Quality

Four houses, cascaded, each one's importance column carried down from the one before: **Goals** set
the weight, **Functions** inherit it, **Components** inherit theirs from the functions, **Operations**
from the components, and **Controls** from the operations. Nothing in a basement is asserted.

The diagrams live in their own files because each carries the TikZ preamble in full — there is no
project-level one — and 240 lines of LaTeX ahead of §1 would bury the document they describe.

| House | Renders | Drawn in | Table behind it |
| ----- | ------- | -------- | --------------- |
| **I** | Goals × Functions | [house-1-goals-functions.md](./docs/houses/house-1-goals-functions.md) | §1, §2, §5, §6 |
| **II** | Functions × Components | [house-2-functions-components.md](./docs/houses/house-2-functions-components.md) | §7 |
| **III** | Components × Operations | [house-3-components-operations.md](./docs/houses/house-3-components-operations.md) | §11 |
| **IV** | Operations × Controls | [house-4-operations-controls.md](./docs/houses/house-4-operations-controls.md) | §11 |

Start with [House I](./docs/houses/house-1-goals-functions.md): it is the whole design on one page.

No house draws the perception zone. §3 holds measured function benchmarks and no 0–5 goal ratings,
and inventing seven of them for Script Kit would be the guess §3 refuses on the record.

**What the four of them found**, in one place, with the detail in §5, §7, §11 and §10:

- **F10 and F2 rank first and second**, which is C6 and C2. §7 had argued that about C6 already.
- **C1 ranks first among components** at 15.6 % and had never been singled out at all.
- **C7 is joint-riskiest and 9th by weight.** §7 was ranking by risk and calling it effort.
- **G4 is weight 8 and has no function.** Footprint is met by trades, not by anything §2 holds.
- **The cascade stops at `swift build` for C1 and C6** — 29.3 % of the component weight reaches no
  operation and therefore no control. Deliberate, per `SPEC.md`, and now sized.

---

## 1. Goals — the WHATs

One user, so weights are asserted directly instead of derived from segments.

| ID  | Goal                                          | Weight | Source            |
| --- | --------------------------------------------- | :----: | ----------------- |
| G2  | It's there every time I reach for it          |   10   | stated: boot start, broken Script must not block others |
| G1  | The automation fires before I notice waiting  |   9    | stated twice: "speed is important" |
| G4  | It costs nothing while I'm not using it       |   8    | stated: "smallest footprint", sharpened to idle cost |
| G3  | A new automation is one file and one minute   |   7    | original ask: "create or edit files" |
| G7  | Upgrading bun or Gleam never breaks it, and I never tell it where they are | 7 | stated: "easily update node and gleam versions or getting the default one" |
| G5  | I write Gleam, not glue around Gleam          |   6    | choosing Gleam was the point; [ADR 0001](./docs/adr/0001-compile-gleam-to-javascript.md) |
| G6  | There's almost nothing to remember            |   6    | stated: "real simplicity", a small **Vocabulary** baseline and not a cap |

G2 outranks G1 deliberately: a launcher that is fast but occasionally absent is worse than one
that is merely quick, because the absence costs a whole trip to diagnose.

## 2. Functions — the HOWs

### Summon & match

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F1  | Put the bar on screen                   |  ↓  | ≤ 50 ms from ⌃⌘K; measured 7.4 ms |
| F2  | Know the catalogue without building     |  ↓  | ≤ 5 ms, from cached **Manifests**    |
| F3  | Narrow to a **Script** as you type      |  ↓  | ≤ 16 ms; measured 2.0 ms         |
| F18 | Reach a **Script** by a shorthand it declares |  ↓  | `yt` finds `youtube`; a **Keyword** typed in full always wins |
| F13 | Drive the whole bar from the home row   |  ↑  | 0 mouse, 0 arrow-key-only paths; ⌃N/⌃P work |

### Build & run

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F4  | Bring the **Artefact** up to date, or **Refuse** | ↓ | ≤ 40 ms; measured 23–25 ms    |
| F5  | Execute the **Artefact**                |  ↓  | ≤ 20 ms; measured 27–29 ms cold, which is the design (T3 dropped) |
| F6  | Gather only the declared **Context**    |  ↓  | ≤ 5 ms; measured 0.013 ms, against 463 ms via `osascript` |

### Act

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F7  | Perform each **Effect** in order, restoring focus before **Paste** | ↓ | ≤ 200 ms for **Paste**, 18.9 ms measured; an **Open** takes what LaunchServices takes, ~35 ms warm and seconds cold |

### Survive

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F8  | Hold the chord, and be visibly broken when it can't | ↑ | 100 % held; failure shown, never silent |
| F9  | Be ready after login                    |  ↓  | ≤ 3 s; 734 ms from `env -i`, and ~3 s across a real boot (T7.1) |
| F10 | Surface breakage at save time, not **Summon** time | ↓ | ≤ 500 ms after save; measured 201–238 ms, and 360 ms against the installed app |
| F12 | Report a run that failed at runtime     |  ↑  | message survives the bar closing |
| F14 | Bound how long a run may hold the bar   |  ↓  | killed at 5 s; measured 5004–5007 ms, spinner shown while running |
| F15 | Follow the **Toolchain** the shell reports, and notice when it moves | ↑ | 0 manual configuration; a missing runtime is red before it is needed |

### Author

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F11 | Turn an unmatched **Keyword** into a new **Script** | ↓ | 1 file touched, 0 registry edits, 1 deliberate confirmation, all three built at T9.3 |
| F16 | Take a **Script** away without leaving the home row | ↓ | 2 keystrokes, 0 registry edits, always recoverable |
| F17 | Open a **Script** where it is written | ↓ | 1 keystroke from the bar to the editor |

## 3. Competitive assessment

Against Script Kit, which is the incumbent and does all five jobs today. Measured on this
machine; blanks are where nothing was measured.

**Function benchmarks**

| Function                     | Starkit (measured) | Script Kit (measured) |
| ---------------------------- | ------------------ | --------------------- |
| F5 execute                   | 27–29 ms           | —                     |
| F6 gather **Running Apps**   | 0.013–0.020 ms in-process, 4.2–5.7 ms on the first read | 463 ms, `osascript` |
| **Vocabulary** size (G6)     | 10 bespoke names   | 356 injected globals  |
| On-disk total (G4)           | 3.9 MB             | 1.86 GB               |
| — the app                    | 492 KB             | 717 MB (Electron)     |
| — support directory          | 3.4 MB `~/.starkit`, of which 3.3 MB is Gleam's `build/` | 1.1 GB `~/.kit` + 42 MB `~/.kenv` |
| Idle RSS (G4)                | 86 MB resident, 21 MB phys footprint | — |
| Idle CPU (G4)                | 0 ms over 300 s, and 0 again over 60 s with C6 watching | — |

What this tells us: the `osascript` figure is the single largest latency in the current system and
disappears entirely by moving **Context** gathering in-process. The 356-to-10 vocabulary ratio is
what "real simplicity" meant, and it is already banked by the closed vocabularies in `CONTEXT.md`,
so the design's job on G6 is not to erode it.

Idle cost was measured at T8.2 against the installed bundle launched by `SMAppService` and left
alone. The two memory figures are both true and answer different questions: 86 MB is what `ps`
reports resident, most of it AppKit and CoreGraphics pages shared with every other application on the
machine, and 21 MB is the phys footprint, the part that is Starkit's alone and would be returned if
it quit. G4 is about the second. Script Kit's column stays a blank on both rows on purpose: measuring
it means launching it, and it takes ⌃⌘K with a `CGEventTap` that consumes the chord before Carbon
dispatch (§4 F8), so the measurement would cost the working system it is being compared against.

The CPU figure is a zero, and the reason is structural. 0.47 s of CPU across a 22-minute life, none
of it in the 300 s window, which is under the 10 ms `ps` resolves to, so what was measured is
"nothing measurable" and not a small quantity. All of it was spent at launch, because after launch
nothing in Starkit runs until the chord arrives: no timer, no poll. C6 was the one thing expected to
change this and it did not. Re-taken at T9.2 with the stream running, the CPU time did not move
across 60 s and the resident size did not either. An `FSEvents` stream is a subscription: the process
is told, it does not ask. A polling design would have shown up in this row; this one contains no
poll.

## 4. Cascade — Goals → Functions → How → Components

Each function sits under the goal it serves most; secondary goals are noted inline.

- **G2** It's there every time I reach for it _W:10_
  - **F8** Hold the chord, be visibly broken when it can't
    - **How**: `RegisterEventHotKey`, which needs no permission and cannot be silently disabled,
      unlike the `CGEventTap` in `cmd-tab`, which only needed a tap because it *intercepts* ⌘⇥
      - The second half of this function does not exist, and cannot. Measured at T2.1: Carbon
        does not arbitrate between applications. Two processes both asking for ⌃⌘K are both given
        it, each told nothing about the other, and a `CGEventTap`, which is how Script Kit
        listens, sees the key before hotkey dispatch and can consume it, so the chord never
        arrives and macOS reports that to nobody. Registration succeeds either way. "Be visibly
        broken when it can't" therefore covers only the failures that are ours to see; a chord
        eaten upstream is visible in one place only, which is the bar not coming up. Paying
        Accessibility for a tap of our own buys nothing, since an earlier tap still consumes first
      - **Component**: C3 HotKey · C10 MenuBarStatus
  - **F9** Be ready after login _(also G4)_
    - **How**: `SMAppService.mainApp`, no helper bundle. A login-launched app gets a minimal
      `PATH`, so the **Toolchain** is resolved at each launch by asking the login shell: one spawn
      for both tools, `command -v` so the shell's own answer wins and a version manager's shim
      resolves as a shim. It follows version-manager moves for free. Rejected: caching absolute
      paths at install, which pins whatever was current then. `~/.starkit/starkit.toml` holds an
      *override* for when the shell lies, not the source of truth, and a wrong path in it goes red
      at launch and not at the **Summon** that first needs it
      - The shell must be interactive, `-ilc` and not `-lc`. Corrected at T1.2 against a
        measurement: a login shell that is not interactive never reads `~/.zshrc`, which is where
        `PATH` is actually set. `~/.bun/bin` is added there on this machine, so `-lc` cannot see
        `bun` from a clean environment at all. The earlier 16.4/22.4 ms figure was taken with `-lc`
        from a terminal, which hands down a `PATH` that already contains the answer, and it was
        validated against node, whose `.vite-plus` shim does sit in the login `PATH`. Both facts
        hid the failure. Under `SMAppService` there is no inherited `PATH` to fall back on, so it
        would have gone red on every boot, the exact F9 failure, reachable only by testing from an
        empty environment instead of a terminal. Costs 510 ms against 35 ms, once per launch,
        17 % of the 3 s budget. `-ic` was measured at 537 ms, so dropping `.zprofile` buys nothing:
        the price is reading `~/.zshrc`, not the login half
      - The registration is macOS's, and it is about a bundle rather than a path. Asked for by
        `install.sh` through the *installed* bundle, for the reason `SPEC.md` records under
        `install.sh`, and read back fresh every time the menu opens, since System Settings can
        change it with nothing told to us. Measured at T7.2 against `sfltool dumpbtm`: the record
        follows the bundle across a move and survives the delete-and-`ditto` every install performs,
        so neither silently unregisters
      - **Component**: C9 LoginItem · C12 Toolchain
  - **F10** Surface breakage at save time, not **Summon** time
    - **How**: `FSEventStream` on `~/.starkit/src` → regenerate the registry, build, rewrite the
      **Manifests**, then set the menu bar state. The whole of `src/` and not `src/scripts/`,
      because an install vendors `starkit.gleam`, `entry.gleam` and `text.gleam` into that same tree
      and C5 already treats the first two as shared modules: the **Vocabulary** changing under
      someone's feet has to invalidate their **Artefacts** like a **Script** changing does
      - Measured at T9.2 at 201–238 ms from save to rebuilt, of which 73–87 ms is Starkit's own
        work: regenerate, `gleam build`, `describe`, write. A save that does not compile reaches the
        menu bar in 169 ms with the previous list still in the bar, which is F2 and F10 being the same
        mechanism seen from two sides. Two outliers at 594 and 628 ms were recorded under load, and
        the excess in both was delivery and not work. 360 ms against the installed bundle and the
        real `~/.starkit` is the number that counts and the one to watch: it is the same work
        over a larger tree, and it is 72 % of the budget
      - FSEvents' own latency window cannot be used for the coalescing. Set to 100 ms it delivered
        the first event of a quiet period up to 509 ms late, though `NoDefer` is documented to prevent
        exactly that, which spent F10's entire budget before Starkit had been told anything. So the
        window is asked for 0 and the burst is coalesced in a 50 ms timer of our own, because an
        editor save is several events: Zed writes a sibling temporary and renames it, which measured
        as two rebuilds at zero latency, the second of them wasted
      - Writing the registry is itself a change inside the watched tree, so adding or removing a
        **Script** costs one extra pass. It terminates because the second finds the file already
        correct and writes nothing, which is convergence and not a path filter, since an editor's
        temporary is a name this code would have to guess at
      - **Component**: C6 Watcher · C10 MenuBarStatus
  - **F4** Bring the **Artefact** up to date, or **Refuse** _(also G1)_
    - **How**: watcher builds on save, so **Summon** usually finds the work already done; the
      shelf re-checks as a safety net. Per-**Script** content hashing against what the last
      successful build compiled decides **Stale**
      ([ADR 0002](./docs/adr/0002-one-project-with-per-script-staleness.md)). Was mtime until T1.4,
      which measured it wrong: Gleam compares content, so a touched file could never be made
      **Current** again
      - **Component**: C5 Builder
  - **F12** Report a run that failed at runtime
    - **How**: capture the child's stderr; the bar is still on screen, because only a **Paste**
      closes it, so a crash needs no notification channel of its own
      - It stopped being true at T2.4 and is true again after T5.4. ↩ hid the bar before the
        run started, which left a **Refusal** nowhere to land, and C10 grew a `run` **Concern** to
        catch it. With the bar now staying for the run, the sentence goes to both: the bar answers
        "what just happened" while the person is standing in front of it, and the menu bar answers
        "what is still wrong" after it has gone, which is the half this criterion names
      - **Component**: C4 Runner · C1 SummonPanel · C10 MenuBarStatus
  - **F14** Bound how long a run may hold the bar
    - **How**: kill at 5 s with a spinner while running. Rejected: dismiss-and-orphan, which
      would land **Effects** minutes later in whatever app you had since switched to
      - Both halves measured at T5.4 against a **Script** that loops forever: five seconds of
        spinner, then `SIGKILL` and the sentence in the bar. The spinner is the mark at the head
        of the bar rather than a second element, because a run is Starkit working, and the mark is
        the one thing on screen that is already Starkit
      - Dismiss-and-orphan is what Escape does, deliberately and only when asked. The run
        carries on, since a `bun` already spawned is not something a keystroke can unspawn, but it
        loses the bar it was going to speak into, so nothing arrives on screen minutes later
      - **Component**: C4 Runner · C1 SummonPanel

- **G1** The automation fires before I notice waiting _W:9_
  - **F1** Put the bar on screen
    - **How**: one `NSPanel` built at launch, then shown and hidden, so the first ⌃⌘K of a
      session costs what the hundredth does (`cmd-tab`'s precedent)
      - Building it at launch was not enough for that. Measured at T2.2 over 24 **Summons**:
        with the window pre-built but never shown, the first ⌃⌘K still cost **25.3 ms** to appear
        and **60.9 ms** to become key, against medians of 7.4 and 13.6. The window server, the
        material and the first activation each charge once, and building the window pays none of
        them. A silent pass through `orderFront` at launch, transparent and off screen, moves the
        charge to where nothing is waiting: first **Summon** 10.5–12.0 ms and 19.7–23.6 ms across
        three runs, in line with their own medians
      - "On screen" and "ready to type" are two numbers, which is what T0.5 handed forward:
        activation travels through the window server, so `isKeyWindow` is false on the run-loop turn
        that shows the panel. Both are inside the 50 ms now; before the warm pass the second was
        not, and the gap is not cosmetic, because keys pressed before the panel is key go to the
        application the person came from
      - **Component**: C1 SummonPanel
  - **F2** Know the catalogue without building
    - **How**: `manifests.json`, rewritten by the watcher after each successful build. Reading a
      cache instead of describing on demand is also what keeps the bar usable while broken
      - **Component**: C2 Catalogue · C6 Watcher
  - **F18** Reach a **Script** by a shorthand it declares
    - **How**: a **Script** declares `other_keywords: ["yt"]` and the bar matches those as well as
      its canonical **Keyword**, in four bands: canonical exactly, another exactly, canonical by
      prefix, another by prefix
      - The bands exist so a shorthand cannot cost you a **Keyword**. Two letters is the fastest
        thing to type in this bar, and without an ordering `yt` would sit behind any **Script** whose
        name merely starts with those letters. A **Keyword** typed in full still wins outright, and
        the canonical one wins a tie, so nothing that worked before can be shadowed by a name added
        afterwards
      - A new field on the `Script` constructor is something nothing can migrate for you, and this is
        the second time this design has spent that (T5.1 was the first, for `asks`), because Gleam
        has no default field values, so every **Script** gains a line or the project stops compiling.
        It is also the only place it could go: `SPEC.md` forbids per-**Script** configuration outside
        its **Manifest**, which rules out a config file, and `starkit.toml` is the **Toolchain**'s
      - It is not a new word. `CONTEXT.md` bans "alias" and asserted one **Keyword** per
        **Script**; by its own definition a shorthand typed into the same field *is* a **Keyword**, so
        the cardinality moved instead of the vocabulary
      - **Component**: C2 Catalogue
  - **F3** Narrow to a **Script** as you type
    - **How**: prefix match on **Keyword** over ~5 entries; no index worth building
      - Measured at T2.4: 2.0 ms for the keystroke that changes the shape of the bar, 0.1 ms for
        one that does not. The match itself is not what costs. Resizing the window and drawing a
        row that was hidden is, and it is paid only when the number of matches changes. Both are
        inside one frame, so the rows are built at launch and reused instead of created per
        keystroke: the same argument as F1, one level down
      - An empty field selects nothing, the same rule F11 already holds. Nothing typed lists the
        whole **Catalogue**, and the registry sorts its **Keywords**, so the row a band would land on
        is `clean`, the **Script** that force-terminates every application without asking. Selecting
        it costs one chord and one ↩ and nothing in between reads as a decision, which is the
        shortest destructive path a bar can have. The band belongs to something that was narrowed to
        or arrived on: the first keystroke, or a deliberate ↓
      - **Component**: C2 Catalogue · C1 SummonPanel
  - **F5** Execute the **Artefact**
    - **How**: spawn `bun` per run and keep nothing between runs. Measured at T1.4 through
      `Process`, against the installed `~/.starkit`: **19.8 ms min / 22.7 median / 24.2 p90**, of
      which about 5 ms is `Process`'s own fork and exec. A fresh process per run also means a fresh
      module cache, so an edited **Script** is always the one that runs, at 0 MB idle. Rejected:
      resident `bun` (sub-ms but holds memory and needs cache-busting)
    - T3 dropped at T1.4. Its whole justification was that a cold spawn cost 54.9 ms on node,
      2.7× over budget; on bun it is 22.7 ms median, 3 ms over a threshold whose entire purpose is
      imperceptibility, under two frames at 60 Hz, next to **Effects** that launch applications.
      What it would have bought is ~16 ms. What it would have cost was not only the process
      lifecycle: a process spawned before a **Keyword** is known cannot be handed one on `argv`, so
      feeding it a run means replacing `run.mjs`'s argument reading with a stdin protocol, framing
      and a read loop, in a **Shelf**-owned file vendored into `~/.starkit`, on top of dismissal
      mid-run, a second **Summon**, a child that died while waiting, and a build that landed
      underneath it. §7 named C4 the riskiest component; this is the version with no lifecycle in it
    - Its conflict with F1 is dissolved rather than resolved. There is no speculative spawn to
      sequence after the panel, so nothing competes with F1's 50 ms
      - **Component**: C4 Runner
  - **F6** Gather only the declared **Context**
    - **How**: `NSWorkspace.runningApplications` filtered to `.activationPolicy == .regular`,
      in-process. Replaces a 463 ms `osascript` call that also needed Automation permission.
      Built at T4.2 and measured there at **0.006–0.016 ms** against a 5 ms budget, but only
      after the first read, which costs 2.8–7.8 ms and is buying the workspace connection rather
      than the list. That one is paid at launch, where nothing is waiting, for the same reason C1
      builds its window there. Declaring the **Needs** is what makes it free rather than merely
      cheap: a **Script** with an empty `needs` gathers nothing and measures 0.00 ms, so the cost is
      on the runs that asked for it and on no others. The **Needs** cross the wire under the names
      `entry.gleam` decodes them by, and a name this binary does not know is a **Refusal** naming
      it, because half a **Context** is not a smaller **Context** but a **Script** deciding about a
      machine that does not exist
      - **Component**: C8 ContextGatherer
  - **F7** Perform each **Effect** in order, restoring focus before **Paste** _(also G5)_
    - **How**: `NSWorkspace.open` / `forceTerminate` need no permission. **Open** measured at
      T1.5 at ~35 ms warm and seconds cold, since it returns only once the launch is under way.
      **Kill** arrived at T4.3 and needs no permission either, which is what makes the one guarantee
      here Starkit's own to keep: a **Kill** aimed at Starkit is a **Refusal**, because the process
      performing a list of **Effects** cannot be one of the things on it. That is the third lock on
      a door C8 and `clean.gleam` already hold shut, and the only one that holds for a **Script**
      that writes the name itself instead of reading it out of a **Context**. A **Kill** finding
      nothing of that name running is *done* and not refused, since the **Effect** asks that an
      application not be running and one that quit on its own has answered it; the price of that, a
      misspelling passing in silence, is what T4.3 paid on the first try.
      **Paste** activates the previously frontmost app then synthesises ⌘V via `CGEvent`, which is
      the one thing needing Accessibility. Pasted text stays on the clipboard by design. Measured
      at T0.5: 23.1 ms for the whole **Paste**, of which 19.4 ms is waiting for the app to report
      itself active again. Awaited via `didActivateApplicationNotification` instead of polled,
      because polling would block the run loop that notification has to arrive on; the deadline
      behind it exists for the case where it never fires. Multi-byte text arrives intact, so it is
      not a second problem to solve, and the Accessibility grant reaches a process already
      running, unlike the event tap in `cmd-tab`, where something restarts after it is given. Built
      at T5.3, where "the previously frontmost app" became something sampled as it happens and
      pinned when the **Shelf** activates, because at **Paste** time the answer is Starkit; where
      the event source became `.privateState`; and where the grant is asked for at the first
      **Paste** rather than at launch, a **Paste** without it being a **Refusal** naming System
      Settings
      - The grant survives the install path, checked at T5.5 against a bundle that genuinely
        differs, since a rebuild of unchanged source is byte-identical and only a changed one tests
        anything. `designated => identifier "dev.apoena.starkit" and certificate leaf = H"e2c66dd6…"`
        names neither the code hash nor the path, which is why a new binary and a deleted-and-recopied
        `/Applications/Starkit.app` both go unnoticed. The certificate is the fragile term
      - TCC attributes to the responsible process, so the same binary run from a shell rather
        than launched as a bundle is a different subject and prompts again. That bounds the debug
        CLI: `Starkit run youtube <url>` can paste only if the *terminal* holds the grant
      - "≤ 10 ms otherwise" is withdrawn (T8.1). It had contradicted the ~35 ms warm above since
        T1.5, and the target is what was wrong: it was written imagining an **Effect** is a function
        call, when an **Open** is a request that LaunchServices start or raise an application and
        returns once the launch is under way. That cost is macOS's and the application's, and a
        budget over something Starkit does not control cannot be met or missed, which is why the
        four warm **Opens** at ~440 ms of T2.4's 498 were a scheduling problem, answered by moving the
        whole ↩ path off the main thread, and never a latency to shave. What remains Starkit's here is
        performing them in order and holding the **Kill** guarantee, neither of which is a duration.
        **Paste** keeps its 200 ms, because the wait inside it *is* ours to bound: 18.9 ms measured at
        T5.4
      - **Component**: C7 Effector

- **G3** A new automation is one file and one minute _W:7_
  - **F11** Turn an unmatched **Keyword** into a new **Script**
    - **How**: write `src/scripts/<keyword>.gleam` from a template and open it in `$EDITOR`
      (Zed). The bar scaffolds, the editor is where all typing happens. Registry generation is a
      consequence of `src/` changing and not of using the create flow, so a **Script** written
      directly in Zed registers itself too; that is the *only* path by which a new **Script**
      becomes visible, which makes the Watcher load-bearing rather than a convenience. The
      `Create "foo"` row is never the default selection, so Enter on a typo does nothing at all
      - "Never the default selection" is a type, not a check. The bar's selection became
        `Int?` at T9.3: with no match there is nothing selected, so ↩ has nothing to act on and the
        offer is reached by a deliberate ↓. Held as an optional instead of as a guard against index
        zero because the alternative puts the offer under the cursor the instant a **Keyword** stops
        matching, which would make misspelling one the fastest way to write a file. ↑ from nothing
        selected does nothing either: the offer sits below the field, and arriving on it by pressing
        *up* is the same accident reached by a different key
      - A row is one of two things, `.script(Manifest)` or `.create(String)`, rather than a
        **Manifest** with a flag on it: a **Manifest** describes a **Script** that exists, and a
        made-up one reaching `run` is the bug the case cannot express
      - The offer is withheld, never repaired. It appears only for what Gleam would accept as a
        module name, since the file becomes `import scripts/<keyword>`, so `My Notes` is not offered
        at all rather than quietly turned into `my_notes`, which would be a **Keyword** nobody can
        find again. The name shown is derived (`daily_notes` → *Daily notes*), because one field to
        fill in is the whole of this function and a wrong guess is one line to change
      - C11 never overwrites. A file can exist while its **Keyword** matches nothing: a **Script**
        that has never compiled is absent from `manifests.json` and therefore absent from the list, so
        "nothing matched" and "nothing is there" are different questions. The existing file is opened
        instead, and it is almost certainly the one that would not compile
      - The template has to compile on arrival, because C6 builds it within 200 ms of it landing
        and a template with a hole in it would turn the menu bar red as its own welcome. Verified by
        writing exactly the bytes `Scaffold` emits into a watched home: listed 174 ms later, and it
        runs. It is `gleam format`-clean for the reason the registry is, which is that the editor
        about to open it may format on save
      - **Component**: C11 Scaffolder · C6 Watcher
  - **F16** Take a **Script** away without leaving the home row
    - **How**: ⌃D on the selected **Script** asks, ⌃D again moves it to the Trash. C6 notices the
      file has gone, so this edits `src/scripts/` and nothing else: deleting from the bar and
      deleting in Finder are the same event, which is F11's argument run backwards
      - The Trash, never `unlink`. This is the only thing in Starkit that destroys something a person
        wrote, and `~/.starkit` is not a repository, so a **Script** may have existed only there. The
        difference between the two calls is whether a mistake is a mistake or a loss, and `trashItem`
        also puts the undo where someone already knows to look, which no message in a bar can do
      - Two presses, and the question names the files. The first ⌃D replaces the list with
        *Delete “Youtube”? ⌃D again moves youtube.gleam and youtube_test.gleam to the Trash. Escape
        keeps it.* in the list's place, because the two are exclusive by design and this is the one
        question in the bar whose answer cannot be taken back. The armed **Keyword** is held rather
        than the row index, so narrowing, moving the selection, or a new **Catalogue** from C6
        disarms rather than retargets: the second press can only ever land on the **Script** the
        question named
      - A **Script**'s test is part of it, found by deleting one (T9.4). `gleam build` typechecks
        `test/`, so removing `youtube.gleam` and leaving `youtube_test.gleam` importing it broke the
        whole project 200 ms later and turned the menu bar red. Both files move, both are named in
        the question, and both are recoverable. A suite under some other name still breaks the build
        and shows up as Gleam naming the missing module, a failure this cannot prevent without
        reading every import
      - ⌃D costs `deleteForward:` in the field, which is the price of staying on the home row and
        was chosen knowingly: every home-row candidate is a text-editing binding (⌃H, ⌃K, ⌃D). It
        arrives as the selector Cocoa names for the key, so F13's rule survives intact, and the
        **Input** stage hands the key back to the text, where the field holds an answer rather than
        a **Keyword**
      - **Component**: C11 Scaffolder · C6 Watcher
  - **F17** Open a **Script** where it is written _(also G5)_
    - **How**: ⌥↩ on the selected **Script** opens it in Zed and **Dismisses** the bar. It is
      F11's "the editor is where all typing happens" applied to a **Script** that already exists, so
      it is the same `open` and not a second way to reach one
      - ⌥↩ and ⌃O both arrive, because macOS binds both to `insertNewlineIgnoringFieldEditor:`,
        the same free pair T2.5 found when ⌃N and ⌃P turned out to be `moveDown:` and `moveUp:`. It is
        also the cheapest key in the bar to take: inserting a newline *ignoring the field editor* has
        nothing to do in a field that holds one line, where ⌃D cost F16 the field's forward-delete
      - It refuses instead of creating when the file is not there. A **Keyword** listed with
        nothing behind it is a **Script** that has gone, and writing a template over that answers a
        question nobody asked
      - **Component**: C11 Scaffolder
  - **F13** Drive the whole bar from the home row _(also G1)_
    - ⌘ chords travel a different road from ⌃ chords, and that is why ⌘V did not work. Everything
      above arrives through `StandardKeyBinding.dict` and the field editor, which needs no menu.
      ⌘V, ⌘C, ⌘X, ⌘A and ⌘Z are dispatched by AppKit as *menu key equivalents*, so with no
      `NSApp.mainMenu` there was nothing to dispatch them to and all five were dead in the one field
      Starkit has. Fixed by building a main menu an `LSUIElement` application never draws, which is
      invisible, and is the reason the gap was invisible too. It survived this long because of T5.1:
      an **Input** arrives **Seeded** from the clipboard and selected, so the case ⌘V exists for had
      already happened, and pasting anything *else* was simply impossible
    - **How**: handle Cocoa action selectors (`moveUp:`, `moveDown:`, `insertNewline:`,
      `cancelOperation:`) instead of keycodes, inheriting ⌃N/⌃P, the arrows, ⌃A/⌃E/⌃K and any
      future `DefaultKeyBinding.dict` for free
      - **Component**: C1 SummonPanel

- **G7** Upgrading bun or Gleam never breaks it _W:7_
  - **F15** Follow the **Toolchain** the shell reports, and notice when it moves
    - **How**: ask the login shell at each launch. Nothing is pinned, so a bun or Gleam upgrade is
      not an event, and this was verified instead of assumed: 1.3.8 and 1.3.14 spawn within noise of
      each other. Measured 510 ms per launch at T1.2, resolving `~/.bun/bin/bun`, which is the real
      binary, since bun has no version-manager shim, so unlike node there is no indirection to pay
      for and no shim-versus-binary choice to get wrong. That `~/.bun/bin` is reachable only through
      `~/.zshrc` is what forced the interactive shell and the cost with it; the argument is under
      F9. Rejected: caching the absolute path, which pins a version `bun upgrade` will move
      underneath it; and a hardcoded `PATH` list, which would have missed `~/.bun` entirely, the
      same blind spot `-lc` had, arrived at from the other direction
      - **Component**: C12 Toolchain · C10 MenuBarStatus

- **G5** I write Gleam, not glue _W:6_ · **G6** Almost nothing to remember _W:6_
  - Both are served by the **Vocabulary** being closed and by every capability arriving as an
    **Effect** instead of an escape hatch. No function of their own: they are constraints the
    other functions are judged against. Current standing: 0 FFI declarations, 10 bespoke names.

## 5. House I — Goals × Functions

Transposed against the canonical orientation: functions are rows here, because eighteen markdown
columns do not fit and [House I](./docs/houses/house-1-goals-functions.md) already draws it the
other way round. Σ = `Σ(goal weight ×
strength)`. Rel % is Σ over the house total of 2061, and it is the number House II carries down.

| Function                    | G2 (10) | G1 (9) | G4 (8) | G3 (7) | G7 (7) | G5 (6) | G6 (6) |   Σ | Rank | Rel % |
| --------------------------- | :-----: | :----: | :----: | :----: | :----: | :----: | :----: | --: | :--: | ----: |
| F1 bar on screen            |    3    |   9    |        |        |        |        |        | 111 |  9   |   5.4 |
| F2 catalogue without build  |    9    |   9    |        |        |        |        |        | 171 |  2   |   8.3 |
| F3 narrow as you type       |         |   9    |        |        |        |        |        |  81 |  14  |   3.9 |
| F18 shorthand **Keyword**   |         |   9    |        |        |        |        |        |  81 |  14  |   3.9 |
| F13 home row only           |         |   9    |        |   3    |        |        |   9    | 156 |  3   |   7.6 |
| F4 **Current**, or **Refuse** |  9    |   3    |        |   3    |        |        |        | 138 |  5   |   6.7 |
| F5 execute the **Artefact** |         |   9    |   9    |        |        |        |        | 153 |  4   |   7.4 |
| F6 gather **Context**       |         |   9    |        |        |        |   3    |   3    | 117 |  8   |   5.7 |
| F7 **Effects** in order     |         |   9    |        |        |        |   9    |        | 135 |  6   |   6.6 |
| F8 hold the chord           |    9    |        |        |        |        |        |        |  90 |  11  |   4.4 |
| F9 ready after login        |    9    |        |   3    |        |   3    |        |        | 135 |  6   |   6.6 |
| F10 breakage at save time   |    9    |        |   3    |   9    |        |        |        | 177 |  1   |   8.6 |
| F12 report a crash          |    9    |        |        |        |        |        |        |  90 |  11  |   4.4 |
| F14 bound the run           |    9    |        |        |        |        |        |        |  90 |  11  |   4.4 |
| F15 follow the **Toolchain** |   3    |        |        |        |   9    |        |   3    | 111 |  9   |   5.4 |
| F11 **Keyword** to **Script** |       |        |        |   9    |        |        |   3    |  81 |  14  |   3.9 |
| F16 take one away           |         |        |        |   9    |        |        |        |  63 |  18  |   3.1 |
| F17 open in editor          |         |        |        |   9    |        |   3    |        |  81 |  14  |   3.9 |
| **Σ per goal**              |   690   |  675   |  120   |  294   |   84   |   90   |  108   | 2061 |     |       |

**Top engineering priorities.** F10 first (8.6 %) and F2 second (8.3 %), which is C6 and C2, the
watcher and the catalogue. §7's prose reached the same place by argument — "C6 is the quiet
load-bearing one" — and the arithmetic did not need telling. F13 third (7.6 %) is the one that
would not have been guessed: driving the bar from the home row is worth more than executing an
**Artefact**, because it is the only function that lands on three goals at once, two of them
strongly. F16 is last (3.1 %), the newest function in the doc and the least load-bearing, which is
the right order to have built things in.

**What the goal row exposes.** G1 and G2 hold 36 % of the total goal weight and take **66 % of the
house**. The other four goals hold 51 % of the weight and take 19 %. For G5 and G6 that is already
on the record — §4 says outright they have "no function of their own" — but G4 and G7 are in exactly
the same position and §4 does not say so. G4 is weight 8, the third-heaviest goal in the document,
and 120 of 2061. Nothing in §2 names a footprint. §3 measures one, and the 3.9 MB against 1.86 GB is
won by T1, T2 and T12 — by trades, not by a function anybody has to hold. See §10.

## 6. Roof — Function × Function

Only the pairs §4 or §9 already argues for. Blank is the overwhelming majority and the honest
answer: most function pairs in this system do not touch. Symbols follow the houses above.

| Pair       |  Sym  | What backs it                                                                       |
| ---------- | :---: | ----------------------------------------------------------------------------------- |
| F2 · F9    |  ++   | the cached **Catalogue** reaches the panel before resolve, build and `describe` run, which is the only reason a ~3 s boot is tolerable |
| F2 · F10   |  ++   | "F2 and F10 being the same mechanism seen from two sides"                            |
| F4 · F10   |  ++   | the watcher builds on save, so a **Summon** usually finds the work already done      |
| F10 · F11  |  ++   | registry generation is a consequence of `src/` changing, so the watcher is the only path by which a new **Script** becomes visible |
| F10 · F16  |  ++   | C6 notices the file has gone; deleting from the bar and deleting in Finder are one event |
| F12 · F14  |  ++   | the deadline's `SIGKILL` produces a **Refusal** that lands in a bar still on screen  |
| F1 · F6    |   +    | both warm at launch, where nothing is waiting, and for the same stated reason        |
| F4 · F5    |   +    | a **Stale** **Artefact** **Refuses** instead of running the wrong one                |
| F4 · F15   |   +    | nothing builds without a resolved `gleam`                                           |
| F5 · F6    |   +    | `ContextGatherer.warm()` moves the 2.8–7.8 ms first read off the run's clock         |
| F5 · F12   |   +    | bun's stack trace reaches the **Refusal**'s `detail` with the **Script**'s own message on top |
| F5 · F14   |   +    | the 5 s deadline is what bounds a run at all                                        |
| F5 · F15   |   +    | nothing runs without a resolved `bun`                                               |
| F13 · F17  |   +    | ⌥↩ and ⌃O were free: `insertNewlineIgnoringFieldEditor:` has nothing to do in a one-line field |
| F1 · F7    |   −    | the bar must activate to be typed into, so **Paste** must hand activation back. 19.4 ms of the 23.1 is that hand-back |
| F3 · F18   |   −    | a shorthand typed into the same field would sit behind any **Keyword** merely starting with those letters |
| F13 · F16  |   −    | ⌃D cost the field its `deleteForward:`, and every home-row candidate is a text-editing binding |
| F9 · F15   |   −    | asking the login shell spends 325–510 ms of a 3 s budget, once per launch            |

**Conflicts that actually shape the design.** Three, and each is handled differently.

- **F1 against F7** is not resolved and cannot be: it is one decision split across C1 and C7, and
  §9 keeps it as a watched tension rather than a fixed bug. The 19.4 ms is the price of the split.
- **F9 against F15** is paid, knowingly, and is the largest single cost in the system. The
  alternative — pinning paths in `starkit.toml` — buys 330 ms by trading away the thing G7 exists
  to get, so it stays a debugging convenience.
- **F3 against F18** and **F13 against F16** were both resolved inside the function that caused
  them: four match bands, and accepting the loss of `deleteForward:`. Neither needs an ADR.

**F1 against F5 is deliberately blank.** It was the design's sharpest conflict until T1.4 and is
now dissolved rather than mitigated: with T3 dropped there is no speculative spawn to sequence after
the panel, so nothing competes with F1's 50 ms. A mark would claim a tension that no longer exists.

## 7. Components & Function → Component map

| ID  | Component         | Responsibility                                              | ADR      |
| --- | ----------------- | ----------------------------------------------------------- | -------- |
| C1  | SummonPanel       | the bar: show/hide, filtering, key handling                 |          |
| C2  | Catalogue         | read `manifests.json`, resolve **Keyword** → **Script**      |          |
| C3  | HotKey            | register ⌃⌘K, report failure to hold it                     |          |
| C4  | Runner            | spawn/kill `bun`, feed a run, 5 s deadline, collect **Effects** and stderr | ADR-0001, ADR-0003 |
| C5  | Builder           | `gleam build`, per-**Script** **Stale** check by content hash | ADR-0002 |
| C6  | Watcher           | `FSEvents` → regenerate registry, build, rewrite **Manifests**   | ADR-0002 |
| C7  | Effector          | perform **Open** / **Kill** / **Paste** / **Notify**, focus and clipboard |          |
| C8  | ContextGatherer   | gather declared **Context** slices in-process                |          |
| C9  | LoginItem         | `SMAppService` registration                                 |          |
| C10 | MenuBarStatus     | normal / red, the only ambient signal Starkit emits          |          |
| C11 | Scaffolder        | write a new **Script** from a **Keyword**, or move one to the Trash |          |
| C12 | Toolchain         | resolve `bun` and `gleam` paths from `starkit.toml`          | ADR-0003 |

### Function → Component

Transposed for the same reason §5 is, and drawn as
[House II](./docs/houses/house-2-functions-components.md). Component Σ = `Σ(function Σ from §5 × strength)`, so a
component's weight is inherited from the goals and not asserted here. House total 27 765.

| Function                      | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | C10 | C11 | C12 |
| ----------------------------- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| F1 bar on screen (111)        | 9  |    |    |    |    |    |    |    |    |     |     |     |
| F2 catalogue without build (171) |  | 9 |    |    |    | 3  |    |    |    |     |     |     |
| F3 narrow as you type (81)    | 9  | 9  |    |    |    |    |    |    |    |     |     |     |
| F18 shorthand **Keyword** (81) | 3 | 9  |    |    |    |    |    |    |    |     |     |     |
| F13 home row only (156)       | 9  |    |    |    |    |    |    |    |    |     |     |     |
| F4 **Current**, or **Refuse** (138) | |  |    |    | 9  | 3  |    |    |    |     |     |     |
| F5 execute the **Artefact** (153) | |  |    | 9  |    |    |    |    |    |     |     | 3   |
| F6 gather **Context** (117)   |    |    |    |    |    |    |    | 9  |    |     |     |     |
| F7 **Effects** in order (135) | 3  |    |    |    |    |    | 9  |    |    |     |     |     |
| F8 hold the chord (90)        |    |    | 9  |    |    |    |    |    |    | 3   |     |     |
| F9 ready after login (135)    |    |    |    |    |    |    |    |    | 9  | 3   |     | 9   |
| F10 breakage at save (177)    |    |    |    |    | 3  | 9  |    |    |    | 9   |     |     |
| F12 report a crash (90)       | 3  |    |    | 9  |    |    |    |    |    | 3   |     |     |
| F14 bound the run (90)        | 3  |    |    | 9  |    |    |    |    |    |     |     |     |
| F15 follow the **Toolchain** (111) | | |    |    |    |    |    |    |    | 3   |     | 9   |
| F11 **Keyword** to **Script** (81) | | |   |    |    | 9  |    |    |    |     | 9   |     |
| F16 take one away (63)        |    |    |    |    |    | 9  |    |    |    |     | 9   |     |
| F17 open in editor (81)       |    |    |    |    |    |    |    |    |    |     | 9   |     |
| **Σ**                         | 4320 | 2997 | 810 | 2997 | 1773 | 3816 | 1215 | 1053 | 1215 | 2871 | 2025 | 2673 |
| **Rank**                      | 1  | 3  | 12 | 3  | 8  | 2  | 9  | 11 | 9  | 5   | 7   | 6   |
| **Rel %**                     | 15.6 | 10.8 | 2.9 | 10.8 | 6.4 | 13.7 | 4.4 | 3.8 | 4.4 | 10.3 | 7.3 | 9.6 |

**Where the engineering effort goes — and where the ranking disagrees.** The paragraph this replaces
said C4 and C7 carry the most risk and C6 is the quiet load-bearing one. Computing it confirms half
of that and contradicts the other half, so both now get said with the axis named.

- **C6 Watcher ranks 2nd (13.7 %)**, which is the confirmation. It was argued for as "the quiet
  load-bearing one" and it is: five functions touch it, and it owns F10 — the highest-weighted
  function in the system — outright. If it stops firing, everything still works and silently goes
  **Stale**, which is the worst failure shape in the document because nothing goes red.
- **C1 SummonPanel ranks 1st (15.6 %)** and was not previously singled out at all. Seven functions
  touch it, and it holds F13 (156) and F1 (111) alone. §10's last line already knew why —
  "keyboard navigation is not a detail of the bar; it is most of what using the bar *is*" — and
  15.6 % is that sentence with a number on it.
- **C7 Effector ranks 9th of 12 (4.4 %)**, and it is one of the two components §7 called riskiest.
  Both are true. C7 carries one function, F7, so its *weight* is small; it also carries the only
  permission-gated operation, the activation hand-back, TCC's responsible-process rule and two
  spellings of an application's name, so its *risk* is the highest in the system. **Risk and weight
  are different axes**, and the earlier paragraph was ranking by risk without saying which it meant.
  Effort follows risk here on purpose: a low-weight component that can lose the Accessibility grant
  takes attention a high-weight one that merely draws rows does not.
- **C3 HotKey ranks last (2.9 %)**, which reads wrong until you notice why: half of F8 does not
  exist and cannot (§4), so C3 is `RegisterEventHotKey` and a failure report. The component that
  owns the only way into the entire application is the smallest thing in it, and that is the design
  working.

## 8. Critical performance budget

| Rank | Function | Target | Measured (T8.1) | Watched on | If we miss it |
| ---- | -------- | ------ | --------------- | ---------- | ------------- |
| 1 | F1 bar on screen | ≤ 50 ms from ⌃⌘K | **7.4 ms on screen, 13.6 ms to key**, T2.2's medians; 4.5–14.4 and 9.1–18.6 across T5.4's session, one outlier at 33.3/44.1 | manual feel, then a signpost trace | panel is pre-built; if still slow, drop the blur/material before dropping correctness |
| 2 | F8 hold the chord | 100 % | **every launch has taken it**, which is the only number this row can have: a chord eaten upstream is reported to nobody (§4 F8), so what is measurable is registration, and registration has never failed | menu bar turns red on registration failure | fall through to no-op instead of swallowing the chord; never fail silently |
| 3 | F5 execute | ≤ 20 ms | **27.2–29.3 ms median** (23.2 min, 33.0 p90); **23.1 ms** with the fetch stack out of the registry, which is T1.4's 22.7 recovered | log per-run µs behind a debug flag | nothing to fall back to: cold spawn *is* the design now (T3 dropped). ~8 ms over on a threshold about imperceptibility, 4.7 of it an import graph and not the spawn (below). If it ever matters, T3 is written down and can be built |
| 4 | F4 build | ≤ 40 ms | **23.0–24.5 ms median** (20.0 min, 27.2 p90; 29–36 ms on a process's first build); **23.9–26.1 ms** for the whole staleness check, so hashing every shared module costs ~1 ms | time each `gleam build` | if it regresses, trust the watcher's build and skip the **Summon**-time re-check |
| 5 | F9 ready after login | ≤ 3 s | **82 ms to the chord, 734 ms to all five Scripts** (T7.1, from an empty environment). Its three costs here: resolve **325–354 ms**, build **23–25 ms**, `describe` **26–31 ms**. **Across a real boot the listing took ~3 s**, the same sequence against a load average of 62, which is nearly the whole budget, and is tolerable only because the panel is handed the cached **Catalogue** before any of it runs | first ⌃⌘K after a reboot | if `starkit.toml` paths are wrong, go red immediately rather than failing on first run |
| 6 | F14 run deadline | 5 s | **5004–5007 ms**, so 4–7 ms of overshoot, against a **Script** that loops forever | the deadline itself | none needed; this *is* the fallback |
| 7 | F6 gather **Context** | ≤ 5 ms | **0.013–0.020 ms** warm median (0.011 min, 0.019 p90); **4.2–5.7 ms** on the first read in a process, which crosses the budget on a busy machine | only if a slice ever needs more than `NSWorkspace` | any slice needing a subprocess must be declared, so the cost stays opt-in |

How these were taken: `Starkit run <keyword> --bench[=N]`, five runs of 20 samples, release build,
against the real `~/.starkit`. Ranges are of the *medians* across those runs, because one run's median
moved by 2 ms depending on what else the machine was doing, and a single figure would have been a
choice of which run to quote. The flag performs no **Effects**, since twenty iterations of `work`
would otherwise open eighty applications, and it reports the first sample apart from the median of
the rest, because cold and warm are different numbers everywhere in this system.

Three rows are not the flag's to take. F1 starts at a keypress and C1 already prints it on every
**Summon**, so its numbers are quoted from the slices that pressed the key. F8 is not a duration. F9's
whole number is a launch, which is why only its parts appear above. Everything is quoted from release
builds because the difference is not small: the same **Summon** from a debug bundle measured 25.7 ms
on screen and 36.4 ms to key against release's 10.8 and 16.4 in one session (T5.5).

Naming both paths in `starkit.toml` deletes C12's cost instead of reducing it: resolve falls from
325–354 ms to **0.063 ms**, because `resolve` skips the login-shell spawn when nothing is left to ask
about, and that is the whole of the 120–140 ms launch first seen at T1.2. It stays a debugging
convenience and not the default, because the file holds hard-coded paths, so it buys 330 ms by
trading away the version manager's shim that F9 exists to resolve *to*.

F14 needed a **Script** that hangs, and got one without a line of new code: the same flag pointed
at a scratch `STARKIT_HOME` holding `spin`, which recurses forever. Every run came back at the
deadline with the **Refusal** naming it, 4–7 ms late, since `SIGKILL` follows a semaphore wait and
the wait is what the overshoot measures.

F5's drift since T1.4 is an import graph and not the spawn. 27–29 ms against 22.7 for what should be
the same cold `bun`. `registry.gleam` imports every **Script** statically, so `entry.mjs` pulls in
`youtube` and `link`, and they pull in `gleam_fetch` and `gleam_http`, which means `work` loads the
whole HTTP stack in order to open four applications. Measured by removing those two from a scratch
registry: F5 falls to 23.1 ms and `describe` from 26.4 to 22.7. So ~4.7 ms of every run is modules
that run cannot use, and it grows with the number of **Scripts** that fetch. Fixing it means a lazy
import per **Keyword**, which moves the **Keyword**-to-module mapping out of Gleam and into the shim,
a C4 decision and not a measurement, so it is recorded instead of taken.

F6's cold read can miss its own budget, at 5.7 ms on a busy machine against 4.2 quiet, inside
C8's known 2.8–7.8 ms range for the first `runningApplications` read, and above the 5 ms this row
allows. Nothing needs fixing, because no run pays it: `ContextGatherer.warm()` at launch spends it
where nobody is waiting, and every read after it is three orders of magnitude cheaper. What the number
says is that the warm call is load-bearing and not merely tidy: remove it and the first **Clean** of a
session is over budget on a machine under load.

C12's resolve is faster than T1.2 recorded, at 325–354 ms against 510. Same `-ilc` spawn, same
profile; nothing in Starkit changed, so this is the machine and not the design. It is still the
largest single cost in the system and still the reason F9's budget is in seconds.

## 9. Tradeoffs — Got / Paid / ADR

| ID  | Tradeoff | Got | Paid | ADR |
| --- | -------- | --- | ---- | --- |
| T1 | JavaScript target over Erlang | 93 ms vs 450 ms end-to-end; `fetch` free | no BEAM, no OTP, no actors, no Erlang-only Hex | [0001](./docs/adr/0001-compile-gleam-to-javascript.md) |
| T2 | One project over five | one dep tree, 2.8 MB vs ~14 MB, one-file **Script** creation | all **Scripts** share a build; needs the content-hash **Stale** rule to stay isolated, and one file of bookkeeping to hold the hashes | [0002](./docs/adr/0002-one-project-with-per-script-staleness.md) |
| T3 | ~~Spawn `bun` on **Summon**~~ (**dropped at T1.4**) | would have bought ~16 ms per run | a stdin protocol in the vendored `run.mjs` replacing `argv`, plus a process lifecycle in the riskiest component, to save 3 ms against a 20 ms target about imperceptibility. Kept on record in case F5 ever bites | |
| T4 | **Effects** out, no bidirectional channel | no blocking stdin in Gleam; Accessibility lives in one signed binary; **Scripts** testable by reading stdout | no dynamic pick-lists, so Clean stays all-or-nothing | |
| T5 | Typed **Manifests** over comment headers | declarations are compile-checked; **Effect** and **Context** can't drift | ~80 lines of Gleam; the registry must be generated | |
| T6 | Keep pasted text on the clipboard | paste the same result into several places by hand | re-**Summoning** a **Script** **Seeds** from its own output | |
| T7 | **Kill** over quit | an empty screen, immediately | unsaved work is lost, deliberately | |
| T8 | ~~Local `install.sh` over Homebrew~~ — **revisited once a Developer ID existed** | bought no notarization, no quarantine, and a stable signature that keeps the Accessibility grant; confirmed at T5.5 across a changed binary and a deleted-and-recopied bundle | cost was that nobody else could install it in one line, and that the grant lasted exactly as long as one machine's certificate. Both were paid until the Apple Developer Program made a Developer ID available: its designated requirement is the same on every machine and across every release, so the grant outlives the certificate that happened to be in one keychain. `setup-signing.sh` stays for anyone building their own copy, which is still the path the README leads with | |
| T15 | A notarized download, and the app seeding its own home | Gatekeeper opens the app on a machine that has never seen it, with no right-click-open and no `xattr -d`; a cask can name `gleam` and `bun` as dependencies, which a caveat could only ask for | the seeding rule moves out of `install.sh` and into the binary, because a cask drops the `.app` and runs nothing. First launch grew a branch that only ever runs once, and `seed/` is now carried twice — in the repo and in `Contents/Resources` — with `build.sh` the only thing keeping them the same. Apple's queue has no SLA: the first submission took seven hours, which is why the staple is reachable on its own | |
| T9 | ~~Tree only, no importance matrix~~ — **reversed once the tree had eighteen functions** | bought no grid to keep current, while component priority was argued from goal weights rather than computed. That held while the argument was small enough to hold in one head. Both houses are now drawn: F10, F2 and F13 rank by arithmetic instead of by assertion; C1 turns out to be the heaviest component and had never been named; C7 turns out to be 9th by weight and joint-first by risk, which is the sentence §7 was making without saying which axis it meant; and G4, weight 8, turns out to have no function at all | 126 relation cells and 216 more, recomputed whenever a goal weight, a function or a component moves, plus two TikZ diagrams that must be redrawn with them — and the diagrams carry the preamble twice, since there is no project-level one. The original T9 was right about the cost and wrong about it being avoidable: the tree hid a missing function behind a goal nobody had checked | |
| T10 | Borrow the **Toolchain**, resolve it every launch | bun and Gleam upgrades are non-events; nothing to configure | ~40 ms per launch for both, and a broken `.zshrc` breaks resolution, though it would break your terminal first | |
| T12 | bun over node as the runtime | cold spawn 17.6 ms vs 54.9 ms, which puts a run inside F5's budget with no resident process; one self-contained binary, no version-manager shim | a faster-moving runtime under G7; bun ignores `NO_COLOR`, so C4 must strip ANSI from stderr before F12 shows it | |
| T13 | A **Script** declares its **Input** in a field, over a `Need` variant | the **Vocabulary** keeps **Context** and **Input** apart, since a **Need** is a slice of the machine the **Shelf** gathers, and C8 never has to know one word in that list is not for it | a constructor gained a field, so every **Script** already written on every machine has to be edited once, and `install.sh` cannot do it: the one upgrade this design has no migration for. Taken at T5.1 because five stubs is the cheapest it will ever be | |
| T14 | One vendored `text.gleam` both pasting **Scripts** import, over a copy in each | every note agrees on how a title is spelled, and the mapping is tested once instead of twice, so the split it exists to prevent cannot open up between two files | T1.6's isolation, partly: a **Script** importing it shares its fate, where until now a **Script** that did not compile took only itself down. Bounded by the module being the **Shelf**'s, replaced wholesale on install, and seven string replacements with no dependencies. Taken at T6.1 with the second caller in hand, as T5.2 said to | |
| T11 | `gleam_json` for the wire, over hand-rolled encoding | escaping is the library's problem on the two paths that carry arbitrary text: a page title into **Paste**, an error into **Notify** | one dependency in a **Shelf**-owned `gleam.toml`, resolved on first install; **Scripts** never import it | |

### Tensions being watched

- No dynamic pick-lists (T4). Clean kills everything or nothing. **Trigger to revisit:** a
  **Script** that genuinely must choose among options computed at run time, at which point the
  outbound channel becomes bidirectional instead of being replaced.
- Editing a **Script** while another is broken blocks it (T2). **Trigger:** it actually
  costs you a morning; the fix is per-**Script** projects, and it is not free.
- `link` reads HTML with a scan and not a parser (T6.1). It takes the first `h1`, which is
  the masthead on some sites, is in a comment or a script template on others, and is spelled `<H1>`
  on a few. Every one of those is in `link_test.gleam` asserting the wrong answer, so the limit is a
  known shape. A real one was measured on the way in: `blog.rust-lang.org` serves no `h1` at all and
  gets a **Notify**, because the heading is rendered in the browser rather than in the response, and
  that is the shape this will keep meeting. **Trigger to revisit:** a page you actually wanted to
  save coming out wrong, at which point the answer is an HTML parser, which is a dependency and an
  *Ask first*, not a longer list of special cases.
- The **Scripts** now share a module, and therefore a fate (T14). `text.gleam` is one file of
  string replacements the **Shelf** owns and replaces on install, which is what makes the shared
  fate affordable. **Trigger to revisit:** the second function wanting in. A module that accumulates
  helpers stops being a mapping and becomes a library every **Script** depends on, and the isolation
  T1.6 measured is spent one import at a time.
- The **Vocabulary** will want to grow. G6 is weight 6 and not a cap. **Trigger:** a third
  **Script** wanting the same missing **Effect**.
- C1 and C7 are coupled through activation (T0.5). The bar has to be typed into, and macOS
  routes keys only to the *active* application's key window, so a `.nonactivatingPanel` in an
  inactive app never becomes key and can hold no **Keyword** at all. The **Shelf** must therefore
  take activation on **Summon**, which is precisely what makes "restore focus before **Paste**"
  load-bearing rather than defensive. Measured both ways: without activation the paste costs 2–8 ms
  and cannot be driven; with it, 23.1 ms and it works. **Trigger to revisit:** anything that
  changes how C1 shows the panel changes what C7 has to undo. They are one decision in two
  components, and the 19.4 ms is the price of the split.

  Fired at T5.4, and the split held. The bar now stays on screen for the run, so C1 no longer
  hides before a **Paste** and C7's hand-back went from a wait that was usually already over to the
  only thing returning the keyboard at all: Starkit is active, with a key panel, at the moment it
  asks another application to come forward. Measured instead of assumed, because a `previous.activate()`
  that macOS declined would have put the note into the bar's own text field: **124 characters into
  Zed in 18.9 ms**, with the bar up throughout. So the hand-back is C7's alone and does not depend on
  a **Dismissal** having happened first, which is what the trigger existed to check.
- ~~A synthesised ⌘V inherits the modifiers physically held down.~~ **Closed at T5.3.**
  `.privateState` rather than `.combinedSessionState`, so the event's flags are the only ones it
  carries and ⌃⌘K being held cannot turn a **Paste** into ⌃⌘V. One word, taken before the failure
  was ever seen, which is what writing the trigger down bought: it was cheap here and would have
  been a bug reproducible only while holding a key.
- Any application with an event tap can take ⌃⌘K, and Starkit cannot tell. Measured at T2.1
  against Script Kit: its `uiohook` tap consumes the key before Carbon dispatch, so Starkit's
  handler never runs and its registration still reports success. Left alone instead of worked
  around, because the detection does not exist, and the two things that look like it (our own tap,
  `CGGetEventTapList`) cost a permission or produce false alarms on any machine with a text
  expander on it. **Trigger to revisit:** the chord going dead against something worth keeping
  installed, at which point the answer is a configurable chord and not a cleverer detector.
- A **Script** that reaches the network cannot satisfy the type the **Vocabulary** gives it.
  `starkit.gleam` declares `run: fn(String, Context) -> List(Effect)`, which is synchronous. On the
  JavaScript target there is no synchronous HTTP and Gleam has no `await`: `gleam_fetch` answers
  with a `Promise`, so Youtube (T5.2) and Link (T6.1) would return `Promise(List(Effect))` and fail
  to compile against the one type that must not churn. Found at T1.1 for the cost of reading the
  signature, which is three slices earlier than running into it. The JS half is already covered,
  since `run.mjs` awaits whatever `entry.run` hands back and awaiting a plain string costs nothing,
  so what is open is the Gleam type and not the plumbing. The candidates are not equal: making every
  `run` return a `Promise` is uniform but puts `gleam/javascript/promise` in front of Clean and
  Work, which pay for a concurrency primitive they never use (G5, G6); a second `Script`
  constructor for the asynchronous kind keeps the simple case simple and costs a word in the
  **Vocabulary** (G6 again, and *Ask first*). **Trigger to revisit:** T5.2, which is the first
  **Script** that fetches, so decide it there with a real one in hand rather than now on a guess.

  Settled at T5.2: the second constructor. `Fetching` sits beside `Script` and differs in one
  field, its `run` answering `Promise(List(Effect))`. Asked, as *Ask first* requires. What decided it
  was not uniformity but who pays: `Script` is untouched, so Work, Personal and Clean say nothing
  about promises, and neither does any **Script** already written in `~/.starkit`, which
  `install.sh` never overwrites and no install would migrate. The uniform alternative would have
  broken every one of them on upgrade for the benefit of code that never fetches. What it cost is
  one branch in `entry.gleam`, which had to be pattern-matched instead of reached through
  `script.run`, that being the one field the two constructors do not share a type for, which is the
  same fact seen from the other side. `entry.run` now returns `Promise(String)` in all cases,
  because Gleam cannot answer a `String` down one branch and a `Promise` down another, and
  `run.mjs` has awaited it since T0.3 for exactly this.
- The **Shelf** reads Gleam's build output path directly. `build/dev/javascript/<pkg>/<mod>.mjs`
  is an internal layout and not a documented interface, and F5 depends on it. Mitigation: when a
  build succeeds but the expected **Artefact** is absent, go red with that specific message
  instead of failing as a missing **Script**. **Trigger to revisit:** a Gleam release that moves
  it, at which point the fix is a compiled-in path template and not a redesign.

  Narrowed at T0.3, and it turned out worse before it got better. Gleam's `entry.mjs` only
  `export`s `main`, so nothing calls it and `node entry.mjs` exits silently. `gleam run` works by
  generating a second file named `gleam@@private_main_v1.18.1.mjs`: marked private, and carrying
  the Gleam version in its name, so every upgrade renames it. Depending on that would have put a
  `brew upgrade gleam` between the user and all five **Scripts**, which is exactly what G7 forbids.
  Shelling out to `gleam run` avoids the path but re-resolves the project on every **Summon**, far
  outside the F5 budget. Resolved with `run.mjs`, a shim we own and vendor: it depends only on
  `entry.mjs` exporting a function, and a rename would break it loudly at import rather than
  silently. Confirmed that a plain `gleam build` never emits the private file at all, so nothing in
  the design touches `gleam run`.

- bun is the runtime, and T3 may not survive it (T12). Measured over 60 cold spawns of
  `run.mjs` against the real seed (5 **Scripts**, `gleam_json`) with the benchmark harness's own
  fork/exec subtracted, as min/median/p90: bun 16.0/17.6/21.9 ms, deno 23.6/26.9/29.5, node
  41.0/54.9/59.1 through the `.vite-plus` shim. Output is byte-identical on all three and `run.mjs`
  needs no edit, so the choice was one string in C12 rather than a migration. Deno was rejected
  despite its permission sandbox looking like a fit for typed **Manifests**: the process is spawned
  before a **Keyword** is known, so permissions would have to be the union of every **Script**,
  which enforces nothing, and tailoring them per **Script** means spawning after Enter, at 27 ms
  against F5's 20 ms. Its one differentiator is unreachable from this architecture. A node fallback
  was considered and rejected; [ADR 0003](./docs/adr/0003-run-artefacts-on-bun.md) records why.

  T3 was settled at T1.4 and dropped; see F5 and the T3 row. Verified in passing: `gleam test`
  runs gleeunit under `runtime = "bun"` with no extra configuration, and a throwing **Script** still
  exits 1 with stderr intact, so F12 holds. Confirmed again at T1.4 against a **Script** that
  `panic`s: bun's stack trace reaches the **Refusal**'s `detail` with the **Script**'s own message at
  the top of it.

- `Process.waitUntilExit()` may not be used anywhere. Measured at T1.4: 63–68 ms for
  `/usr/bin/true`, and it pays that even after the pipe has already reached EOF, so it is a polling
  loop and not a wait, larger than three of the seven budget rows on its own. `posix_spawn` +
  `waitpid` is 5.9 ms and `terminationHandler` is free. C5 was written with it and was silently
  spending 65 ms of F4's 40 ms budget on nothing. Both C4 and C5 now wait on `terminationHandler`.
  **Trigger to revisit:** none, since this is a fact about Foundation and not a decision. Worth
  knowing before adding a fourth process anywhere.

## 10. Inconsistencies spotted and fixed

- `CONTEXT.md` claimed a **Script** is pure. Writing the **Manifest** type showed it can't be,
  since Youtube's fetch decides its **Effects**. `CONTEXT.md` now records where the boundary
  actually falls.
- "Footprint" meant three things. Split into G4 (idle cost), G2 (ready at login) and G6
  (**Vocabulary** size). Only after splitting did the 356-vs-10 number become the headline.
- The **Stale** rule compared mtimes, and Gleam compares content. Found at T1.4 by the first
  real `Starkit run work`, which **Refused** a **Script** that was perfectly current: `touch` a
  source and Gleam rightly recompiles nothing, leaving the **Artefact**'s mtime behind the source's
  forever, so nothing could ever clear the **Refusal**. `CONTEXT.md` already defined **Stale** as
  "built from source that has since changed", so the definition was right and the implementation was
  an approximation of it, which is why the fix needed no new vocabulary. Now hashes, in
  [ADR 0002](./docs/adr/0002-one-project-with-per-script-staleness.md). The generalisation is the
  part to remember: where the **Shelf** and Gleam disagree about what "changed" means, Gleam wins,
  because Gleam decides what gets compiled.
- `install.sh` compares before it copies for a reason that has since evaporated. It exists so
  that vendoring a byte-identical **Vocabulary** does not move its mtime and mark all five
  **Scripts** **Stale**. Under content hashing that cannot happen at all. The comparison is still
  worth keeping, since it keeps the mtimes honest for anything else reading them, but it is no
  longer load-bearing, and C5's doc comment no longer claims it is.
- "Shortcut" meant two mechanisms. Resolved to **Keyword** only; the sole key chord
  **Summons** the **Shelf**.
- The **Shelf** was assumed able to hold the keyboard without activating. `main.swift` said so
  in as many words, that an app which never became active has nothing to take away, so nothing to
  give back. T0.5 showed the opposite: not activating costs the bar its keyboard entirely. The
  activation policy stays `.accessory` for the missing Dock icon, but the panel activates, and
  **Paste** hands activation back. Corrected where it was written down rather than only here.
- "Restore the clipboard" was ambiguous between the **Seed** and the pasted text. Resolved:
  keep the pasted text.
- Nothing declared an **Input**, though `CONTEXT.md` had said so since before slice 0. "A
  **Script** that declares an **Input** has it **Seeded**; one that declares none never is" was in
  the relationships all along, and `starkit.gleam` gave every **Script** a `String` whether it
  wanted one or not, so the sentence described a rule the types could not express and the bar could
  not read. Found at T5.1, which is the first task that needed the answer: an **Input** stage that
  appears is not something a return value can decide. The **Vocabulary** was right and the type was
  short of it, which is the same shape as the **Stale** correction at T1.4.
- "Closed **Vocabulary**" read as frozen. Corrected to closed-but-not-frozen.
- Comment headers were recommended, then reversed. The argument was that a broken **Script**
  must stay listed, but measurement showed a broken module fails the whole build either way, so
  the fallback was needed regardless and typed **Manifests** became free.
- F5's first target (≤ 60 ms) was unambitious. Measuring H3 tightened it to ≤ 20 ms; a
  target set before the spike would have shipped 8× slower than necessary and looked green.
- F13 was missing entirely from the first pass at functions, and F12 and F14 nearly were.
  Keyboard navigation is not a detail of the bar; it is most of what using the bar *is*.
- **G4 has no function.** It is weight 8, the third-heaviest goal in the document, and §5 gives it
  120 of 2061 — 5.8 % of a house where it holds 15 % of the weight. Its three cells are all
  side-effects of decisions taken for other reasons: F5 keeps nothing between runs so the run is
  fast, F9 is a login item, F10's FSEvents happens to be a subscription rather than a poll. §3
  measures the goal thoroughly — 3.9 MB against 1.86 GB, 21 MB phys footprint, 0 measurable idle CPU
  — and every one of those numbers is won by a *trade* (T1, T2, T12) rather than by anything §2 holds
  anyone to. So G4 is currently met by luck that happens to be structural. Not resolved by adding a
  function on the spot, because inventing a target for a goal already being met would be the
  reverse of how every other row here was written. Recorded instead, with the trigger: the first
  change that costs idle memory or disk, at which point G4 needs a function with a number, and the
  material to write it is already in §3. The same reading applies more weakly to G7, which at least
  has F15 owning it outright.
- **§7 was ranking by risk and calling it effort.** "C4 and C7 carry the most risk" is true; it sat
  under the heading "where the effort goes" next to no computed weights, so it read as a priority
  ordering. Computing it puts C7 9th of 12. Resolved by naming both axes in §7 rather than by
  changing either judgement — risk says where a mistake costs most, weight says where the goals land,
  and C7 is the row where they disagree hardest.
- **C5's responsibility still said "**Stale** check by mtime."** The mtime rule was replaced by
  content hashing at T1.4, and §10 has recorded that since — but §7's own table kept the old word,
  so the one line describing what C5 does contradicted the ADR anchored beside it in the same row.
  Fixed. It is the same failure mode as F5's stale target caught at T8.1: the summary line went
  stale while the paragraph explaining it stayed correct.
- **§7 models the Shelf's internals and calls them "Components."** Six of `SPEC.md`'s operations
  turned out to have nothing in §7 to relate to: `Starkit icon`, vendoring `seed/` into the bundle,
  `ditto` to `/Applications`, notarize-and-staple, `gleam test` and `gleam format --check`. They act
  on the bundle, on the vendored **Vocabulary**, and on the **Scripts** — and `README.md` says in its
  third paragraph that "**Scripts** live in `~/.starkit`; this repo is only the **Shelf**", so half of
  what is delivered was never in the component list. Found by needing WHATs for House III. Not fixed
  by adding rows, because C1–C12 are coherent as they stand and the seeded half is not a set of Swift
  components; §11 names the six and says what they act on instead. **Trigger to revisit:** a decision
  that turns on the seeded half's structure, at which point §7 grows a second block rather than
  stretching the first.
- **The cascade terminates at `swift build` for C1 and C6.** 29.3 % of the component weight — the
  first- and second-ranked components — reaches no operation in House III beyond the compiler, and
  therefore no control in House IV. `SPEC.md` names SummonPanel and Watcher as deliberately untested
  and argues it well, so the *decision* is on the record; what was not was the size, or the
  distinction that matters: C1 fails loudly, because a bar that does not appear is the first thing
  anyone notices, and C6 fails **silently**, everything still working while the **Artefacts** go
  **Stale**. Recorded, not fixed. **Trigger to revisit:** the first time a **Script** turns out to
  have been **Stale** for a while without anyone noticing, at which point the answer is a control
  rather than a test — something that notices C6 has stopped firing.
- **ADR 0003 anchored nothing.** §7's table named ADR-0001 and ADR-0002 and omitted 0003 entirely,
  though "run **Artefacts** on bun" is exactly what C4 spawns and C12 resolves. Found by needing an
  ADR row for House II's basement, which is a use the table had not been put to before. Both rows
  now name it. `README.md`'s documentation list was missing it too, and now is not.

## 11. The deployment cascade — Houses III and IV

§5 and §7 stop at components, which is where the classical cascade's first two phases stop. These are
the other two: what produces or verifies each **Component**, and what would catch a regression in
each of those. Drawn as [House III](./docs/houses/house-3-components-operations.md) and
[House IV](./docs/houses/house-4-operations-controls.md).

Neither list is invented for the house. The **Operations** are `SPEC.md`'s commands; the **Controls**
are `.github/workflows/ci.yml`'s steps plus the two things that check at runtime rather than at push.
Six things `SPEC.md` lists are deliberately absent from the operations: `Starkit icon`, vendoring
`seed/` into the bundle, `ditto` to `/Applications`, notarize-and-staple, `gleam test` and
`gleam format --check`. They act on the bundle, the vendored **Vocabulary** and the **Scripts** — the
seeded half — and §7 models only the **Shelf**'s internals, so they have no component to relate to.
That is a gap in §7's coverage of what actually gets built, not in the house; see §10.

### Component → Operation

Weights are House II's Rel %, so Σ = `Σ(component Rel % × strength)`.

| Component (Rel %)     | O1 build | O2 sign | O3 registry | O4 gleam build | O5 login | O6 swift test | O7 dry-run | O8 CLI | O9 bench |
| --------------------- | :------: | :-----: | :---------: | :------------: | :------: | :-----------: | :--------: | :----: | :------: |
| C1 SummonPanel (15.6) |    9     |         |             |                |          |               |            |        |          |
| C2 Catalogue (10.8)   |    9     |         |             |                |          |       9       |            |        |          |
| C3 HotKey (2.9)       |    9     |         |             |                |          |               |            |        |          |
| C4 Runner (10.8)      |    9     |         |             |       3        |          |       9       |     9      |        |    9     |
| C5 Builder (6.4)      |    9     |         |             |       9        |          |       9       |            |        |    9     |
| C6 Watcher (13.7)     |    9     |         |      3      |                |          |               |            |        |          |
| C7 Effector (4.4)     |    9     |    9    |             |                |          |       3       |     3      |        |          |
| C8 ContextGatherer (3.8) |  9    |         |             |                |          |               |            |        |    9     |
| C9 LoginItem (4.4)    |    9     |         |             |                |    9     |               |            |        |          |
| C10 MenuBarStatus (10.3) |  9    |         |             |                |          |       3       |            |        |          |
| C11 Scaffolder (7.3)  |    9     |         |             |                |          |               |            |   9    |          |
| C12 Toolchain (9.6)   |    9     |         |             |                |          |               |            |        |    9     |
| **Σ**                 |  900.0   |  39.6   |    41.1     |      90.0      |   39.6   |     296.1     |   110.4    |  65.7  |  275.4   |
| **Rank**              |    1     |    8    |      7      |       5        |    8     |       2       |     4      |   6    |    3     |
| **Rel %**             |   48.4   |   2.1   |     2.2     |      4.8       |   2.1    |     15.9      |    5.9     |  3.5   |   14.8   |

**O1 at 48.4 % is a degenerate first place.** It produces all twelve components, so it was always
going to carry half the house, and it says nothing about where to spend effort. Read the ranking
below it instead: **`swift test` (15.9 %) and `run --bench` (14.8 %)** are the two verification
operations that carry real weight, and they reach C2, C4, C5, C7, C8, C10 and C12.

**C1's and C3's and C6's rows are the finding.** They hold `swift build` and, between them, one
medium cell. That is 32.2 % of the component weight produced by a compiler and verified by nothing.
`SPEC.md` names HotKey, SummonPanel and Watcher in its *Not tested* list and argues the case — each
is a thin call into a framework, and a mock would pass while the app was broken — so this is a
position held on purpose. What the house adds is the size of it, and one distinction `SPEC.md` does
not draw: C1 and C3 fail *loudly*, because a bar that does not appear is the first thing anyone
notices, while C6 fails **silently**, everything still working as the **Artefacts** go **Stale**.
Same empty row, different consequence.

### Operation → Control

Weights are House III's Rel %, so Σ = `Σ(operation Rel % × strength)`.

| Operation (Rel %)          | K1 CI | K2 verify | K3 format | K4 gleam test | K5 unpinned | K6 swift test | K7 red | K8 bench | K9 staple | K10 exit |
| -------------------------- | :---: | :-------: | :-------: | :-----------: | :---------: | :-----------: | :----: | :------: | :-------: | :------: |
| O1 swift build (48.4)      |   9   |           |           |               |             |       3       |        |          |           |          |
| O2 codesign (2.1)          |   3   |     9     |           |               |             |               |        |          |     3     |          |
| O3 Starkit registry (2.2)  |   9   |           |     9     |       3       |             |               |        |          |           |          |
| O4 gleam build (4.8)       |   9   |           |           |       9       |      9      |               |        |          |           |          |
| O5 register at login (2.1) |       |           |           |               |             |               |   3    |          |           |    9     |
| O6 swift test (15.9)       |   9   |           |           |               |             |       9       |        |          |           |          |
| O7 run --dry-run (5.9)     |       |           |           |               |             |       3       |        |          |           |          |
| O8 create, edit, delete (3.5) |    |           |     3     |               |             |               |   9    |          |           |          |
| O9 run --bench (14.8)      |       |           |           |               |             |               |        |    9     |           |          |
| **Σ**                      | 648.0 |   18.9    |   30.3    |     49.8      |    43.2     |     306.0     |  37.8  |  133.2   |    6.3    |   18.9   |
| **Rank**                   |   1   |     8     |     7     |       4       |      5      |       2       |   6    |    3     |    10     |    8     |
| **Rel %**                  | 50.1  |    1.5    |    2.3    |      3.9      |     3.3     |     23.7      |  2.9   |   10.3   |    0.5    |   1.5    |

**CI and `swift test` carry 73.8 % of the control weight**, which is a healthy shape. The third
control is the `--bench` protocol at 10.3 %, and it is a person: five runs of twenty samples, release
build, against the real `~/.starkit`, medians quoted because one run's median moved by 2 ms. §8
records the protocol and `SPEC.md` argues for keeping it out of CI, so this is deliberate. The number
is what is new — a tenth of the control weight in this system is a manual procedure, and it is the
tenth that guards the four performance rows of §8.

**K7 is the most automatic control here and is not in CI.** The menu bar goes red within 200 ms of a
save, on the machine, forever, and it is the only thing controlling O8: a template with a hole in it
would turn the bar red as its own welcome (§4, F11). CI cannot be that. K9 ranks last at 0.5 %, which
is correct — it guards one operation that runs at most once per release.

**Three operations reach no CI control at all**: O5, O7 and O9. Each has a reason on the record —
`start-at-login` asks macOS and exits non-zero when the answer disagrees, `--dry-run` is the
debugging path, `--bench` would be flaky. None is a surprise. What has no reason on the record is
that **O1's row is the only one C1 and C6 appear in anywhere in Houses III and IV**, so the chain
G → F → C → O → K terminates at a compiler for the two heaviest components in the design. Recorded in
§10 rather than fixed here, because fixing it means either testing framework-facing code that
`SPEC.md` argues should not be tested, or adding a control that is not a test — and the second is the
more interesting option: something that notices C6 has stopped firing, which is the one failure in
this system that is silent by construction.

---

## How to keep this honest

- When a new ADR lands → add its components to §7 and re-score affected rows.
- When a spike or measurement returns numbers → update §3 benchmarks, §8 `Measured`, **and §2's
  `Target (now)`**. §2 was left out of this rule until T8.1 and went stale for it: F5 still read
  "measured 6.7 ms warm", which is the warm-process number from the alternative T3 *rejected*, so the
  one line most people would read first described a design that was never built.
- Goals change rarely; functions change with each release; matrices are recomputed when either side changes.
- **A house is a rendering, not a source.** §5, §7 and §11 hold the cells; the four files under
  `docs/houses/` hold the same numbers a second time and cannot be recomputed from anything. So the
  order is always tables first, houses after, and never one without the other.
- **The cascade is a chain, so a change propagates down it.** Each house's importance column *is* the
  house above's Rel %. Adding one function to §2 changes 7 cells in §5, up to 12 in §7, one Σ and
  every Rel % in both — and because House II's Rel % feeds House III's weights, which feed House
  IV's, it moves every number in all four basements. Four diagrams to redraw for one function. This
  is what T9 now costs and the reason it was declined for as long as it was. Recompute in order
  I → II → III → IV; there is no shortcut, and doing it out of order silently mixes generations.
- If a section becomes empty after edits, delete it. An empty section reads as a claim that there
  was nothing to record.
