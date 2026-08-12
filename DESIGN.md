# Starkit — Design (QFD)

How Starkit delivers what `CONTEXT.md` names. This document owns goals, measurable functions,
chosen approaches, and the trade-offs taken; it does not define vocabulary — `CONTEXT.md` does —
and it does not record hard-to-reverse decisions, which live in `docs/adr/`.

Every target below comes from a measurement on the development machine rather than an estimate.
Where a number appears without a source, it is a budget still to be verified.

Strength weights used in matrices: **9** strong, **3** medium, **1** weak, blank none.

---

## 1. Goals — the WHATs

One user, so weights are asserted directly rather than derived from segments.

| ID  | Goal                                          | Weight | Source            |
| --- | --------------------------------------------- | :----: | ----------------- |
| G2  | It's there every time I reach for it          |   10   | stated: boot start, broken Script must not block others |
| G1  | The automation fires before I notice waiting  |   9    | stated twice: "speed is important" |
| G4  | It costs nothing while I'm not using it       |   8    | stated: "smallest footprint", sharpened to idle cost |
| G3  | A new automation is one file and one minute   |   7    | original ask: "create or edit files" |
| G7  | Upgrading bun or Gleam never breaks it, and I never tell it where they are | 7 | stated: "easily update node and gleam versions or getting the default one" |
| G5  | I write Gleam, not glue around Gleam          |   6    | choosing Gleam was the point; [ADR 0001](./docs/adr/0001-compile-gleam-to-javascript.md) |
| G6  | There's almost nothing to remember            |   6    | stated: "real simplicity" — a small **Vocabulary** baseline, not a cap |

G2 outranks G1 deliberately: a launcher that is fast but occasionally absent is worse than one
that is merely quick, because the absence costs a whole trip to diagnose.

## 2. Functions — the HOWs

### Summon & match

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F1  | Put the bar on screen                   |  ↓  | ≤ 50 ms from ⌃⌘K — measured 7.4 ms |
| F2  | Know the catalogue without building     |  ↓  | ≤ 5 ms, from cached **Manifests**    |
| F3  | Narrow to a **Script** as you type      |  ↓  | ≤ 16 ms — measured 2.0 ms        |
| F13 | Drive the whole bar from the home row   |  ↑  | 0 mouse, 0 arrow-key-only paths; ⌃N/⌃P work |

### Build & run

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F4  | Bring the **Artefact** up to date, or **Refuse** | ↓ | ≤ 40 ms — measured 23–25 ms   |
| F5  | Execute the **Artefact**                |  ↓  | ≤ 20 ms — measured 27–29 ms cold, which is the design (T3 dropped) |
| F6  | Gather only the declared **Context**    |  ↓  | ≤ 5 ms — measured 0.013 ms, vs 463 ms via `osascript` |

### Act

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F7  | Perform each **Effect** in order, restoring focus before **Paste** | ↓ | ≤ 200 ms for **Paste** — 18.9 ms measured; an **Open** takes what LaunchServices takes, ~35 ms warm and seconds cold |

### Survive

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F8  | Hold the chord, and be visibly broken when it can't | ↑ | 100 % held; failure shown, never silent |
| F9  | Be ready after login                    |  ↓  | ≤ 3 s — measured 734 ms; a reboot is owed |
| F10 | Surface breakage at save time, not **Summon** time | ↓ | ≤ 500 ms after save — measured 201–238 ms, and 360 ms against the installed app |
| F12 | Report a run that failed at runtime     |  ↑  | message survives the bar closing |
| F14 | Bound how long a run may hold the bar   |  ↓  | killed at 5 s — measured 5004–5007 ms; spinner shown while running |
| F15 | Follow the **Toolchain** the shell reports, and notice when it moves | ↑ | 0 manual configuration; a missing runtime is red before it is needed |

### Author

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F11 | Turn an unmatched **Keyword** into a new **Script** | ↓ | 1 file touched, 0 registry edits, 1 deliberate confirmation — all three built at T9.3 |

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

**What this tells us.** The `osascript` figure is the single largest latency in the current
system and disappears entirely by moving **Context** gathering in-process. The 356-to-10
vocabulary ratio is what "real simplicity" meant, and it is already banked by the closed
vocabularies in `CONTEXT.md` — so the design's job on G6 is not to erode it.

**Idle cost, measured at T8.2** against the installed bundle launched by `SMAppService` and left
alone. The two memory figures are both true and answer different questions: 86 MB is what `ps`
reports resident, most of it AppKit and CoreGraphics pages shared with every other application on the
machine, and 21 MB is the phys footprint — the part that is Starkit's alone and would be returned if
it quit. G4 is about the second. Script Kit's column stays a blank on both rows on purpose: measuring
it means launching it, and it takes ⌃⌘K with a `CGEventTap` that consumes the chord before Carbon
dispatch (§4 F8), so the measurement would cost the working system it is being compared against.

**The CPU figure is a zero, and it is the design showing rather than a number worth celebrating.**
0.47 s of CPU across a 22-minute life, none of it in the 300 s window — under the 10 ms `ps` resolves
to, so what was measured is "nothing measurable" rather than a small quantity. All of it was spent at
launch, because after launch nothing in Starkit runs until the chord arrives: no timer, no poll, no
watch. **C6 was the one thing expected to change this, and it did not** — re-taken at T9.2 with the
stream running, the CPU time did not move across 60 s and the resident size did not either. An
`FSEvents` stream is a subscription: the process is told, it does not ask. What would have shown up
here is the poll this design does not contain.

## 4. Cascade — Goals → Functions → How → Components

Each function sits under the goal it serves most; secondary goals are noted inline.

- **G2** It's there every time I reach for it _W:10_
  - **F8** Hold the chord, be visibly broken when it can't
    - **How**: `RegisterEventHotKey` — needs no permission and cannot be silently disabled,
      unlike the `CGEventTap` in `cmd-tab`, which only needed a tap because it *intercepts* ⌘⇥
      - **The second half of this function does not exist, and cannot.** Measured at T2.1: Carbon
        does not arbitrate between applications. Two processes both asking for ⌃⌘K are both given
        it, each told nothing about the other — and a `CGEventTap`, which is how Script Kit
        listens, sees the key before hotkey dispatch and can consume it, so the chord never
        arrives and macOS reports that to nobody. Registration succeeds either way. "Be visibly
        broken when it can't" therefore covers only the failures that are ours to see; a chord
        eaten upstream is visible in one place only, which is the bar not coming up. Paying
        Accessibility for a tap of our own buys nothing — an earlier tap still consumes first
      - **Component**: C3 HotKey · C10 MenuBarStatus
  - **F9** Be ready after login _(also G4)_
    - **How**: `SMAppService.mainApp`, no helper bundle. A login-launched app gets a minimal
      `PATH`, so the **Toolchain** is resolved at each launch by asking the login shell — one spawn
      for both tools, `command -v` so the shell's own answer wins and a version manager's shim
      resolves as a shim. It follows version-manager moves for free. Rejected: caching absolute
      paths at install, which pins whatever was current then. `~/.starkit/starkit.toml` holds an
      *override* for when the shell lies, not the source of truth, and a wrong path in it goes red
      at launch rather than at the **Summon** that first needs it
      - **The shell must be interactive**, `-ilc` and not `-lc`. Corrected at T1.2 against a
        measurement: a login shell that is not interactive never reads `~/.zshrc`, which is where
        `PATH` is actually set — `~/.bun/bin` is added there on this machine, so `-lc` cannot see
        `bun` from a clean environment at all. The earlier 16.4/22.4 ms figure was taken with `-lc`
        from a terminal, which hands down a `PATH` that already contains the answer, and it was
        validated against node, whose `.vite-plus` shim does sit in the login `PATH`. Both facts
        hid the failure. Under `SMAppService` there is no inherited `PATH` to fall back on, so it
        would have gone red on every boot — the exact F9 failure, reachable only by testing from an
        empty environment rather than a terminal. Costs 510 ms against 35 ms, once per launch,
        17 % of the 3 s budget. `-ic` was measured at 537 ms, so dropping `.zprofile` buys nothing:
        the price is reading `~/.zshrc`, not the login half
      - **The registration is macOS's, and it is about a bundle rather than a path.** Asked for by
        `install.sh` through the *installed* bundle — an install is when the promise was asked for,
        boot included, where an app registering itself at launch would overrule someone who had just
        turned it off — and read back fresh every time the menu opens, since System Settings can
        change it with nothing told to us. Measured at T7.2 against `sfltool dumpbtm`: the record
        follows the bundle across a move and survives the delete-and-`ditto` every install performs,
        so neither silently unregisters
      - **Component**: C9 LoginItem · C12 Toolchain
  - **F10** Surface breakage at save time, not **Summon** time
    - **How**: `FSEventStream` on `~/.starkit/src` → regenerate the registry, build, rewrite the
      **Manifests**, then set the menu bar state. The whole of `src/` rather than `src/scripts/`,
      because an install vendors `starkit.gleam`, `entry.gleam` and `text.gleam` into that same tree
      and C5 already treats the first two as shared modules — the **Vocabulary** changing under
      someone's feet has to invalidate their **Artefacts** like a **Script** changing does
      - **Measured at T9.2: 201–238 ms from save to rebuilt**, of which 73–87 ms is Starkit's own
        work — regenerate, `gleam build`, `describe`, write. A save that does not compile reaches the
        menu bar in 169 ms with the previous list still in the bar, which is F2 and F10 being the same
        mechanism seen from two sides. Two outliers at 594 and 628 ms were recorded under load, and
        the excess in both was delivery rather than work. **360 ms against the installed bundle and the
        real `~/.starkit`**, which is the number that counts and the one to watch: it is the same work
        over a larger tree, and it is 72 % of the budget
      - **FSEvents' own latency window cannot be used for the coalescing.** Set to 100 ms it delivered
        the first event of a quiet period up to 509 ms late — `NoDefer` is documented to prevent
        exactly that and does not — which spent F10's entire budget before Starkit had been told
        anything. So the window is asked for 0 and the burst is coalesced in a 50 ms timer of our own,
        because an editor save is several events: Zed writes a sibling temporary and renames it, which
        measured as two rebuilds at zero latency, the second of them wasted
      - **Writing the registry is itself a change inside the watched tree**, so adding or removing a
        **Script** costs one extra pass. It terminates because the second finds the file already
        correct and writes nothing — convergence rather than a path filter, since an editor's
        temporary is a name this code would have to guess at
      - **Component**: C6 Watcher · C10 MenuBarStatus
  - **F4** Bring the **Artefact** up to date, or **Refuse** _(also G1)_
    - **How**: watcher builds on save, so **Summon** usually finds the work already done; the
      shelf re-checks as a safety net. Per-**Script** content hashing against what the last
      successful build compiled decides **Stale**
      ([ADR 0002](./docs/adr/0002-one-project-with-per-script-staleness.md)). Was mtime until T1.4,
      which measured it wrong — Gleam compares content, so a touched file could never be made
      **Current** again
      - **Component**: C5 Builder
  - **F12** Report a run that failed at runtime
    - **How**: capture the child's stderr; the bar is still on screen, because only a **Paste**
      closes it — so a crash needs no notification channel of its own
      - **It stopped being true at T2.4 and is true again after T5.4.** ↩ hid the bar before the
        run started, which left a **Refusal** nowhere to land, and C10 grew a `run` **Concern** to
        catch it. With the bar now staying for the run, the sentence goes to both: the bar answers
        "what just happened" while the person is standing in front of it, and the menu bar answers
        "what is still wrong" after it has gone, which is the half this criterion names
      - **Component**: C4 Runner · C1 SummonPanel · C10 MenuBarStatus
  - **F14** Bound how long a run may hold the bar
    - **How**: kill at 5 s with a spinner while running. Rejected: dismiss-and-orphan, which
      would land **Effects** minutes later in whatever app you had since switched to
      - **Both halves measured at T5.4** against a **Script** that loops forever: five seconds of
        spinner, then `SIGKILL` and the sentence in the bar. The spinner is the mark at the head
        of the bar rather than a second element — a run is Starkit working, and the mark is the
        one thing on screen that is already Starkit
      - **Dismiss-and-orphan is what Escape does**, deliberately and only when asked. The run
        carries on — a `bun` already spawned is not something a keystroke can unspawn — but it
        loses the bar it was going to speak into, so nothing arrives on screen minutes later
      - **Component**: C4 Runner · C1 SummonPanel

- **G1** The automation fires before I notice waiting _W:9_
  - **F1** Put the bar on screen
    - **How**: one `NSPanel` built at launch, then shown and hidden — so the first ⌃⌘K of a
      session costs what the hundredth does (`cmd-tab`'s precedent)
      - **Building it at launch was not enough for that.** Measured at T2.2 over 24 **Summons**:
        with the window pre-built but never shown, the first ⌃⌘K still cost **25.3 ms** to appear
        and **60.9 ms** to become key, against medians of 7.4 and 13.6. The window server, the
        material and the first activation each charge once, and building the window pays none of
        them. A silent pass through `orderFront` at launch — transparent and off screen — moves the
        charge to where nothing is waiting: first **Summon** 10.5–12.0 ms and 19.7–23.6 ms across
        three runs, in line with their own medians
      - **"On screen" and "ready to type" are two numbers**, which is what T0.5 handed forward:
        activation travels through the window server, so `isKeyWindow` is false on the run-loop turn
        that shows the panel. Both are inside the 50 ms now; before the warm pass the second was
        not, and the gap is not cosmetic — keys pressed before the panel is key go to the
        application the person came from
      - **Component**: C1 SummonPanel
  - **F2** Know the catalogue without building
    - **How**: `manifests.json`, rewritten by the watcher after each successful build. Reading a
      cache rather than describing on demand is also what keeps the bar usable while broken
      - **Component**: C2 Catalogue · C6 Watcher
  - **F3** Narrow to a **Script** as you type
    - **How**: prefix match on **Keyword** over ~5 entries; no index worth building
      - **Measured at T2.4: 2.0 ms for the keystroke that changes the shape of the bar, 0.1 ms for
        one that does not.** The match itself is not what costs — resizing the window and drawing a
        row that was hidden is, and it is paid only when the number of matches changes. Both are
        inside one frame, so the rows are built at launch and reused rather than created per
        keystroke: the same argument as F1, one level down
      - **Component**: C2 Catalogue · C1 SummonPanel
  - **F5** Execute the **Artefact**
    - **How**: spawn `bun` per run and keep nothing between runs. Measured at T1.4 through
      `Process`, against the installed `~/.starkit`: **19.8 ms min / 22.7 median / 24.2 p90**, of
      which about 5 ms is `Process`'s own fork and exec. A fresh process per run also means a fresh
      module cache, so an edited **Script** is always the one that runs, at 0 MB idle. Rejected:
      resident `bun` (sub-ms but holds memory and needs cache-busting)
    - **T3 dropped at T1.4.** Its whole justification was that a cold spawn cost 54.9 ms on node,
      2.7× over budget; on bun it is 22.7 ms median, 3 ms over a threshold whose entire purpose is
      imperceptibility — under two frames at 60 Hz, next to **Effects** that launch applications.
      What it would have bought is ~16 ms. What it would have cost was not only the process
      lifecycle: a process spawned before a **Keyword** is known cannot be handed one on `argv`, so
      feeding it a run means replacing `run.mjs`'s argument reading with a stdin protocol — framing
      and a read loop, in a **Shelf**-owned file vendored into `~/.starkit` — on top of dismissal
      mid-run, a second **Summon**, a child that died while waiting, and a build that landed
      underneath it. §7 named C4 the riskiest component; this is the version with no lifecycle in it
    - **Its conflict with F1 is dissolved rather than resolved.** There is no speculative spawn to
      sequence after the panel, so nothing competes with F1's 50 ms
      - **Component**: C4 Runner
  - **F6** Gather only the declared **Context**
    - **How**: `NSWorkspace.runningApplications` filtered to `.activationPolicy == .regular`,
      in-process. Replaces a 463 ms `osascript` call that also needed Automation permission.
      Built at T4.2 and measured there at **0.006–0.016 ms** against a 5 ms budget — but only
      after the first read, which costs 2.8–7.8 ms and is buying the workspace connection rather
      than the list. That one is paid at launch, where nothing is waiting, for the same reason C1
      builds its window there. **Declared** is what makes it free rather than merely cheap: a
      **Script** with an empty `needs` gathers nothing and measures 0.00 ms, so the cost is on the
      runs that asked for it and on no others. The **Needs** cross the wire under the names
      `entry.gleam` decodes them by, and a name this binary does not know is a **Refusal** naming
      it — half a **Context** is not a smaller **Context**, it is a **Script** deciding about a
      machine that does not exist
      - **Component**: C8 ContextGatherer
  - **F7** Perform each **Effect** in order, restoring focus before **Paste** _(also G5)_
    - **How**: `NSWorkspace.open` / `forceTerminate` need no permission — **Open** measured at
      T1.5 at ~35 ms warm and seconds cold, since it returns only once the launch is under way.
      **Kill** arrived at T4.3 and needs no permission either, which is what makes the one guarantee
      here Starkit's own to keep: a **Kill** aimed at Starkit is a **Refusal**, because the process
      performing a list of **Effects** cannot be one of the things on it. That is the third lock on
      a door C8 and `clean.gleam` already hold shut, and the only one that holds for a **Script**
      that writes the name itself rather than reading it out of a **Context**. A **Kill** finding
      nothing of that name running is *done*, not refused — the **Effect** asks that an application
      not be running, and one that quit on its own has answered it — and the price of that, a
      misspelling passing in silence, is what T4.3 paid on the first try
      **Paste** activates the previously frontmost app then synthesises ⌘V via `CGEvent`, which is
      the one thing needing Accessibility. Pasted text stays on the clipboard by design. Measured
      at T0.5: 23.1 ms for the whole **Paste**, of which 19.4 ms is waiting for the app to report
      itself active again. Awaited via `didActivateApplicationNotification` rather than polled,
      because polling would block the run loop that notification has to arrive on; the deadline
      behind it exists for the case where it never fires. Multi-byte text arrives intact, so it is
      not a second problem to solve, and the Accessibility grant reaches a process already
      running — unlike the event tap in `cmd-tab`, nothing restarts after it is given. Built at
      T5.3, where "the previously frontmost app" became something sampled as it happens and pinned
      when the **Shelf** activates, because at **Paste** time the answer is Starkit; where the event
      source became `.privateState`; and where the grant is asked for at the first **Paste** rather
      than at launch, a **Paste** without it being a **Refusal** naming System Settings
      - **The grant survives the install path**, checked at T5.5 against a bundle that genuinely
        differs — a rebuild of unchanged source is byte-identical, so only a changed one tests
        anything. `designated => identifier "dev.apoena.starkit" and certificate leaf = H"e2c66dd6…"`
        names neither the code hash nor the path, which is why a new binary and a deleted-and-recopied
        `/Applications/Starkit.app` both go unnoticed. The certificate is the fragile term
      - **TCC attributes to the responsible process**, so the same binary run from a shell rather
        than launched as a bundle is a different subject and prompts again. That bounds the debug
        CLI: `Starkit run youtube <url>` can paste only if the *terminal* holds the grant
      - **"≤ 10 ms otherwise" is withdrawn** (T8.1). It had contradicted the ~35 ms warm above since
        T1.5, and the target is what was wrong: it was written imagining an **Effect** is a function
        call, when an **Open** is a request that LaunchServices start or raise an application and
        returns once the launch is under way. That cost is macOS's and the application's, and a
        budget over something Starkit does not control cannot be met or missed — which is why the
        four warm **Opens** at ~440 ms of T2.4's 498 were a scheduling problem, answered by moving the
        whole ↩ path off the main thread, and never a latency to shave. What remains Starkit's here is
        performing them in order and holding the **Kill** guarantee, neither of which is a duration.
        **Paste** keeps its 200 ms, because the wait inside it *is* ours to bound: 18.9 ms measured at
        T5.4
      - **Component**: C7 Effector

- **G3** A new automation is one file and one minute _W:7_
  - **F11** Turn an unmatched **Keyword** into a new **Script**
    - **How**: write `src/scripts/<keyword>.gleam` from a template and open it in `$EDITOR`
      (Zed) — the bar scaffolds, the editor is where all typing happens. Registry generation is a
      consequence of `src/` changing, not of using the create flow, so a **Script** written
      directly in Zed registers itself too; that is the *only* path by which a new **Script**
      becomes visible, which makes the Watcher load-bearing rather than a convenience. The
      `Create "foo"` row is never the default selection, so Enter on a typo does nothing at all
      - **"Never the default selection" is a type, not a check.** The bar's selection became
        `Int?` at T9.3: with no match there is nothing selected, so ↩ has nothing to act on and the
        offer is reached by a deliberate ↓. Held as an optional rather than as a guard against index
        zero because the alternative puts the offer under the cursor the instant a **Keyword** stops
        matching, which would make misspelling one the fastest way to write a file. ↑ from nothing
        selected does nothing either — the offer sits below the field, and arriving on it by pressing
        *up* is the same accident wearing a different key
      - **A row is one of two things**, `.script(Manifest)` or `.create(String)`, rather than a
        **Manifest** with a flag on it: a **Manifest** describes a **Script** that exists, and a
        made-up one reaching `run` is the bug the case cannot express
      - **The offer is withheld, never repaired.** It appears only for what Gleam would accept as a
        module name — the file becomes `import scripts/<keyword>` — so `My Notes` is not offered at
        all rather than quietly turned into `my_notes`, which would be a **Keyword** nobody can find
        again. The name shown is derived (`daily_notes` → *Daily notes*), because one field to fill in
        is the whole of this function and a wrong guess is one line to change
      - **C11 never overwrites.** A file can exist while its **Keyword** matches nothing: a **Script**
        that has never compiled is absent from `manifests.json` and therefore absent from the list, so
        "nothing matched" and "nothing is there" are different questions. The existing file is opened
        instead — almost certainly the one that would not compile
      - **The template has to compile on arrival**, because C6 builds it within 200 ms of it landing
        and a template with a hole in it would turn the menu bar red as its own welcome. Verified by
        writing exactly the bytes `Scaffold` emits into a watched home: listed 174 ms later, and it
        runs. It is `gleam format`-clean for the reason the registry is — the editor about to open it
        may format on save
      - **Component**: C11 Scaffolder · C6 Watcher
  - **F13** Drive the whole bar from the home row _(also G1)_
    - **How**: handle Cocoa action selectors (`moveUp:`, `moveDown:`, `insertNewline:`,
      `cancelOperation:`) rather than keycodes, inheriting ⌃N/⌃P, the arrows, ⌃A/⌃E/⌃K and any
      future `DefaultKeyBinding.dict` for free
      - **Component**: C1 SummonPanel

- **G7** Upgrading bun or Gleam never breaks it _W:7_
  - **F15** Follow the **Toolchain** the shell reports, and notice when it moves
    - **How**: ask the login shell at each launch. Nothing is pinned, so a bun or Gleam upgrade is
      not an event — verified rather than assumed: 1.3.8 and 1.3.14 spawn within noise of each
      other. Measured 510 ms per launch at T1.2, resolving `~/.bun/bin/bun`, which is the real
      binary — bun has no version-manager shim, so unlike node there is no indirection to pay for
      and no shim-versus-binary choice to get wrong. That `~/.bun/bin` is reachable only through
      `~/.zshrc` is what forced the interactive shell and the cost with it; the argument is under
      F9. Rejected: caching the absolute path, which pins a version `bun upgrade` will move
      underneath it; and a hardcoded `PATH` list, which would have missed `~/.bun` entirely — the
      same blind spot `-lc` had, arrived at from the other direction
      - **Component**: C12 Toolchain · C10 MenuBarStatus

- **G5** I write Gleam, not glue _W:6_ · **G6** Almost nothing to remember _W:6_
  - Both are served by the **Vocabulary** being closed and by every capability arriving as an
    **Effect** rather than an escape hatch. No function of their own: they are constraints the
    other functions are judged against. Current standing: 0 FFI declarations, 10 bespoke names.

## 7. Components

| ID  | Component         | Responsibility                                              | ADR      |
| --- | ----------------- | ----------------------------------------------------------- | -------- |
| C1  | SummonPanel       | the bar: show/hide, filtering, key handling                 |          |
| C2  | Catalogue         | read `manifests.json`, resolve **Keyword** → **Script**      |          |
| C3  | HotKey            | register ⌃⌘K, report failure to hold it                     |          |
| C4  | Runner            | spawn/kill `bun`, feed a run, 5 s deadline, collect **Effects** and stderr | ADR-0001 |
| C5  | Builder           | `gleam build`, per-**Script** **Stale** check by mtime        | ADR-0002 |
| C6  | Watcher           | `FSEvents` → regenerate registry, build, rewrite **Manifests**   | ADR-0002 |
| C7  | Effector          | perform **Open** / **Kill** / **Paste** / **Notify**, focus and clipboard |          |
| C8  | ContextGatherer   | gather declared **Context** slices in-process                |          |
| C9  | LoginItem         | `SMAppService` registration                                 |          |
| C10 | MenuBarStatus     | normal / red, the only ambient signal Starkit emits          |          |
| C11 | Scaffolder        | template a new **Script** from a **Keyword**                 |          |
| C12 | Toolchain         | resolve `bun` and `gleam` paths from `starkit.toml`          |          |

**Where the effort goes.** C4 and C7 carry the most risk: C4 owns process lifecycle and the
deadline, C7 owns the only permission-gated operation in the system. C6 is the quiet
load-bearing one — it is what makes F2, F4, F10 and F11 all cheap, and if it stops firing,
everything still works but silently goes **Stale**.

## 8. Critical performance budget

| Rank | Function | Target | Measured (T8.1) | Watched on | If we miss it |
| ---- | -------- | ------ | --------------- | ---------- | ------------- |
| 1 | F1 bar on screen | ≤ 50 ms from ⌃⌘K | **7.4 ms on screen, 13.6 ms to key** — T2.2's medians; 4.5–14.4 and 9.1–18.6 across T5.4's session, one outlier at 33.3/44.1 | manual feel, then a signpost trace | panel is pre-built; if still slow, drop the blur/material before dropping correctness |
| 2 | F8 hold the chord | 100 % | **every launch has taken it**, which is the only number this row can have: a chord eaten upstream is reported to nobody (§4 F8), so what is measurable is registration, and registration has never failed | menu bar turns red on registration failure | fall through to no-op rather than swallowing the chord; never fail silently |
| 3 | F5 execute | ≤ 20 ms | **27.2–29.3 ms median** (23.2 min, 33.0 p90) — and **23.1 ms** with the fetch stack out of the registry, which is T1.4's 22.7 recovered | log per-run µs behind a debug flag | nothing to fall back to: cold spawn *is* the design now (T3 dropped). ~8 ms over on a threshold about imperceptibility, 4.7 of it an import graph rather than the spawn (below). If it ever matters, T3 is written down and can be built |
| 4 | F4 build | ≤ 40 ms | **23.0–24.5 ms median** (20.0 min, 27.2 p90; 29–36 ms on a process's first build); **23.9–26.1 ms** for the whole staleness check, so hashing every shared module costs ~1 ms | time each `gleam build` | if it regresses, trust the watcher's build and skip the **Summon**-time re-check |
| 5 | F9 ready after login | ≤ 3 s | **82 ms to the chord, 734 ms to all five Scripts** (T7.1, from an empty environment; a reboot is still owed). Its three costs here: resolve **325–354 ms**, build **23–25 ms**, `describe` **26–31 ms** | first ⌃⌘K after a reboot | if `starkit.toml` paths are wrong, go red immediately rather than failing on first run |
| 6 | F14 run deadline | 5 s | **5004–5007 ms** — 4–7 ms of overshoot, against a **Script** that loops forever | the deadline itself | none needed — this *is* the fallback |
| 7 | F6 gather **Context** | ≤ 5 ms | **0.013–0.020 ms** warm median (0.011 min, 0.019 p90); **4.2–5.7 ms** on the first read in a process, which crosses the budget on a busy machine | only if a slice ever needs more than `NSWorkspace` | any slice needing a subprocess must be declared, so the cost stays opt-in |

**How these were taken.** `Starkit run <keyword> --bench[=N]`, five runs of 20 samples, release build,
against the real `~/.starkit`. Ranges are of the *medians* across those runs, because one run's median
moved by 2 ms depending on what else the machine was doing, and a single figure would have been a
choice of which run to quote. The flag performs no **Effects** — twenty iterations of `work` would
otherwise open eighty applications — and it reports the first sample apart from the median of the rest,
because cold and warm are different numbers everywhere in this system.

**Three rows are not the flag's to take.** F1 starts at a keypress and C1 already prints it on every
**Summon**, so its numbers are quoted from the slices that pressed the key. F8 is not a duration. F9's
whole number is a launch, which is why only its parts appear above. Everything is quoted from release
builds because the difference is not small: the same
**Summon** from a debug bundle measured 25.7 ms on screen and 36.4 ms to key against release's 10.8
and 16.4 in one session (T5.5).

**Naming both paths in `starkit.toml` deletes C12's cost rather than reducing it**: resolve falls from
325–354 ms to **0.063 ms**, because `resolve` skips the login-shell spawn when nothing is left to ask
about, and that is the whole of the 120–140 ms launch first seen at T1.2. It stays a debugging
convenience and not the default — the file holds hard-coded paths, so it buys 330 ms by trading away
the version manager's shim that F9 exists to resolve *to*.

**F14 needed a **Script** that hangs**, and got one without a line of new code: the same flag pointed
at a scratch `STARKIT_HOME` holding `spin`, which recurses forever. Every run came back at the
deadline with the **Refusal** naming it, 4–7 ms late — `SIGKILL` after a semaphore wait, and the wait
is what the overshoot measures.

**F5's drift since T1.4 is an import graph, not the spawn.** 27–29 ms against 22.7 for what should be
the same cold `bun`. `registry.gleam` imports every **Script** statically, so `entry.mjs` pulls in
`youtube` and `link`, and they pull in `gleam_fetch` and `gleam_http` — which means `work` loads the
whole HTTP stack in order to open four applications. Measured by removing those two from a scratch
registry: F5 falls to 23.1 ms and `describe` from 26.4 to 22.7. So ~4.7 ms of every run is modules
that run cannot use, and it grows with the number of **Scripts** that fetch. Fixing it means a lazy
import per **Keyword**, which moves the **Keyword**-to-module mapping out of Gleam and into the shim —
a C4 decision, not a measurement, so it is recorded rather than taken.

**F6's cold read can miss its own budget**, at 5.7 ms on a busy machine against 4.2 quiet — inside
C8's known 2.8–7.8 ms range for the first `runningApplications` read, and above the 5 ms this row
allows. Nothing needs fixing, because no run pays it: `ContextGatherer.warm()` at launch spends it
where nobody is waiting, and every read after it is three orders of magnitude cheaper. What the number
says is that the warm call is load-bearing rather than tidy — remove it and the first **Clean** of a
session is over budget on a machine under load.

**C12's resolve is faster than T1.2 recorded**: 325–354 ms against 510. Same `-ilc` spawn, same
profile; nothing in Starkit changed, so this is the machine and not the design. It is still the
largest single cost in the system and still the reason F9's budget is in seconds.

## 9. Tradeoffs — Got / Paid / ADR

| ID  | Tradeoff | Got | Paid | ADR |
| --- | -------- | --- | ---- | --- |
| T1 | JavaScript target over Erlang | 93 ms vs 450 ms end-to-end; `fetch` free | no BEAM, no OTP, no actors, no Erlang-only Hex | [0001](./docs/adr/0001-compile-gleam-to-javascript.md) |
| T2 | One project over five | one dep tree, 2.8 MB vs ~14 MB, one-file **Script** creation | all **Scripts** share a build; needs the content-hash **Stale** rule to stay isolated, and one file of bookkeeping to hold the hashes | [0002](./docs/adr/0002-one-project-with-per-script-staleness.md) |
| T3 | ~~Spawn `bun` on **Summon**~~ — **dropped at T1.4** | would have bought ~16 ms per run | a stdin protocol in the vendored `run.mjs` replacing `argv`, plus a process lifecycle in the riskiest component, to save 3 ms against a 20 ms target about imperceptibility. Kept on record in case F5 ever bites | |
| T4 | **Effects** out, no bidirectional channel | no blocking stdin in Gleam; Accessibility lives in one signed binary; **Scripts** testable by reading stdout | no dynamic pick-lists — Clean stays all-or-nothing | |
| T5 | Typed **Manifests** over comment headers | declarations are compile-checked; **Effect** and **Context** can't drift | ~80 lines of Gleam; the registry must be generated | |
| T6 | Keep pasted text on the clipboard | paste the same result into several places by hand | re-**Summoning** a **Script** **Seeds** from its own output | |
| T7 | **Kill** over quit | an empty screen, immediately | unsaved work is lost, deliberately | |
| T8 | Local `install.sh` over Homebrew | no notarization, no quarantine, a stable signature that keeps the Accessibility grant — confirmed at T5.5 across a changed binary and a deleted-and-recopied bundle | nobody else can install it in one line; the grant lasts exactly as long as the certificate does | |
| T9 | Tree only, no importance matrix | no 72-cell grid to keep current | component priority is argued from goal weights, not computed | |
| T10 | Borrow the **Toolchain**, resolve it every launch | bun and Gleam upgrades are non-events; nothing to configure | ~40 ms per launch for both, and a broken `.zshrc` breaks resolution — though it would break your terminal first | |
| T12 | bun over node as the runtime | cold spawn 17.6 ms vs 54.9 ms, which puts a run inside F5's budget with no resident process; one self-contained binary, no version-manager shim | a faster-moving runtime under G7; bun ignores `NO_COLOR`, so C4 must strip ANSI from stderr before F12 shows it | |
| T13 | A **Script** declares its **Input** in a field, over a `Need` variant | the **Vocabulary** keeps **Context** and **Input** apart — a **Need** is a slice of the machine the **Shelf** gathers, and C8 never has to know one word in that list is not for it | a constructor gained a field, so every **Script** already written on every machine has to be edited once, and `install.sh` cannot do it — the one upgrade this design has no migration for. Taken at T5.1 because five stubs is the cheapest it will ever be | |
| T14 | One vendored `text.gleam` both pasting **Scripts** import, over a copy in each | every note agrees on how a title is spelled, and the mapping is tested once rather than twice — the split it exists to prevent cannot open up between two files | T1.6's isolation, partly: a **Script** importing it shares its fate, where until now a **Script** that did not compile took only itself down. Bounded by the module being the **Shelf**'s, replaced wholesale on install, and seven string replacements with no dependencies. Taken at T6.1 with the second caller in hand, as T5.2 said to | |
| T11 | `gleam_json` for the wire, over hand-rolled encoding | escaping is the library's problem on the two paths that carry arbitrary text — a page title into **Paste**, an error into **Notify** | one dependency in a **Shelf**-owned `gleam.toml`, resolved on first install; **Scripts** never import it | |

### Tensions being watched

- **No dynamic pick-lists** (T4). Clean kills everything or nothing. **Trigger to revisit:** a
  **Script** that genuinely must choose among options computed at run time — at which point the
  outbound channel becomes bidirectional rather than being replaced.
- **Editing a **Script** while another is broken blocks it** (T2). **Trigger:** it actually
  costs you a morning; the fix is per-**Script** projects, and it is not free.
- **`link` reads HTML with a scan rather than a parser** (T6.1). It takes the first `h1`, which is
  the masthead on some sites, is in a comment or a script template on others, and is spelled `<H1>`
  on a few. Every one of those is in `link_test.gleam` asserting the wrong answer, so the limit is a
  known shape. A real one was measured on the way in: `blog.rust-lang.org` serves no `h1` at all and
  gets a **Notify**, because the heading is rendered in the browser rather than in the response, and
  that is the shape this will keep meeting. **Trigger to revisit:** a page you actually wanted to
  save coming out wrong — at which point the answer is an HTML parser, which is a dependency and an
  *Ask first*, not a longer list of special cases.
- **The **Scripts** now share a module, and therefore a fate** (T14). `text.gleam` is one file of
  string replacements the **Shelf** owns and replaces on install, which is what makes the shared
  fate affordable. **Trigger to revisit:** the second function wanting in. A module that accumulates
  helpers stops being a mapping and becomes a library every **Script** depends on, and the isolation
  T1.6 measured is spent one import at a time.
- **The **Vocabulary** will want to grow.** G6 is weight 6, not a cap. **Trigger:** a third
  **Script** wanting the same missing **Effect** — two is coincidence.
- **C1 and C7 are coupled through activation** (T0.5). The bar has to be typed into, and macOS
  routes keys only to the *active* application's key window — so a `.nonactivatingPanel` in an
  inactive app never becomes key and can hold no **Keyword** at all. The **Shelf** must therefore
  take activation on **Summon**, which is precisely what makes "restore focus before **Paste**"
  load-bearing rather than defensive. Measured both ways: without activation the paste costs 2–8 ms
  and cannot be driven; with it, 23.1 ms and it works. **Trigger to revisit:** anything that
  changes how C1 shows the panel changes what C7 has to undo — they are one decision in two
  components, and the 19.4 ms is the price of the split.

  **Fired at T5.4, and the split held.** The bar now stays on screen for the run, so C1 no longer
  hides before a **Paste** and C7's hand-back went from a wait that was usually already over to the
  only thing returning the keyboard at all — Starkit is active, with a key panel, at the moment it
  asks another application to come forward. Measured rather than assumed, because a `previous.activate()`
  that macOS declined would have put the note into the bar's own text field: **124 characters into
  Zed in 18.9 ms**, with the bar up throughout. So the hand-back is C7's alone and does not depend on
  a **Dismissal** having happened first, which is what the trigger existed to check.
- ~~**A synthesised ⌘V inherits the modifiers physically held down.**~~ **Closed at T5.3.**
  `.privateState` rather than `.combinedSessionState`, so the event's flags are the only ones it
  carries and ⌃⌘K being held cannot turn a **Paste** into ⌃⌘V. One word, taken before the failure
  was ever seen, which is what writing the trigger down bought: it was cheap here and would have
  been a bug reproducible only while holding a key.
- **Any application with an event tap can take ⌃⌘K, and Starkit cannot tell.** Measured at T2.1
  against Script Kit: its `uiohook` tap consumes the key before Carbon dispatch, so Starkit's
  handler never runs and its registration still reports success. Left alone rather than worked
  around — the detection does not exist, and the two things that look like it (our own tap,
  `CGGetEventTapList`) cost a permission or produce false alarms on any machine with a text
  expander on it. **Trigger to revisit:** the chord going dead against something worth keeping
  installed, at which point the answer is a configurable chord, not a cleverer detector.
- **A **Script** that reaches the network cannot satisfy the type the **Vocabulary** gives it.**
  `starkit.gleam` declares `run: fn(String, Context) -> List(Effect)`, which is synchronous. On the
  JavaScript target there is no synchronous HTTP and Gleam has no `await`: `gleam_fetch` answers
  with a `Promise`, so Youtube (T5.2) and Link (T6.1) would return `Promise(List(Effect))` and fail
  to compile against the one type that must not churn. Found at T1.1 for the cost of reading the
  signature, which is three slices earlier than running into it. The JS half is already covered —
  `run.mjs` awaits whatever `entry.run` hands back, and awaiting a plain string costs nothing — so
  what is open is the Gleam type, not the plumbing. The candidates are not equal: making every
  `run` return a `Promise` is uniform but puts `gleam/javascript/promise` in front of Clean and
  Work, which pay for a concurrency primitive they never use (G5, G6); a second `Script`
  constructor for the asynchronous kind keeps the simple case simple and costs a word in the
  **Vocabulary** (G6 again, and *Ask first*). **Trigger to revisit:** T5.2, which is the first
  **Script** that fetches — decide it there, with a real one in hand, rather than now on a guess.

  **Settled at T5.2: the second constructor.** `Fetching` sits beside `Script` and differs in one
  field, its `run` answering `Promise(List(Effect))`. Asked, as *Ask first* requires. What decided it
  was not uniformity but who pays: `Script` is untouched, so Work, Personal and Clean say nothing
  about promises, and — the part that is not about taste — neither does any **Script** already
  written in `~/.starkit`, which `install.sh` never overwrites and no install would migrate. The
  uniform alternative would have broken every one of them on upgrade for the benefit of code that
  never fetches. What it cost is one branch in `entry.gleam`, which had to be pattern-matched rather
  than reached through `script.run` — the one field the two constructors do not share a type for,
  which is the same fact seen from the other side. `entry.run` now returns `Promise(String)` in all
  cases, because Gleam cannot answer a `String` down one branch and a `Promise` down another, and
  `run.mjs` has awaited it since T0.3 for exactly this.
- **The **Shelf** reads Gleam's build output path directly** — `build/dev/javascript/<pkg>/<mod>.mjs`
  is an internal layout, not a documented interface, and F5 depends on it. Mitigation: when a
  build succeeds but the expected **Artefact** is absent, go red with that specific message
  rather than failing as a missing **Script**. **Trigger to revisit:** a Gleam release that moves
  it — at which point the fix is a compiled-in path template, not a redesign.

  Narrowed at T0.3, and it turned out worse before it got better. Gleam's `entry.mjs` only
  `export`s `main` — nothing calls it, so `node entry.mjs` exits silently. `gleam run` works by
  generating a second file named `gleam@@private_main_v1.18.1.mjs`: marked private, and carrying
  the Gleam version in its name, so every upgrade renames it. Depending on that would have put a
  `brew upgrade gleam` between the user and all five **Scripts**, which is exactly what G7 forbids.
  Shelling out to `gleam run` avoids the path but re-resolves the project on every **Summon**, far
  outside the F5 budget. Resolved with `run.mjs`, a shim we own and vendor: it depends only on
  `entry.mjs` exporting a function, and a rename would break it loudly at import rather than
  silently. Confirmed that a plain `gleam build` never emits the private file at all, so nothing in
  the design touches `gleam run`.

- **bun is the runtime, and T3 may not survive it** (T12). Measured over 60 cold spawns of
  `run.mjs` against the real seed — 5 **Scripts**, `gleam_json` — with the benchmark harness's own
  fork/exec subtracted, as min/median/p90: bun 16.0/17.6/21.9 ms, deno 23.6/26.9/29.5, node
  41.0/54.9/59.1 through the `.vite-plus` shim. Output is byte-identical on all three and `run.mjs`
  needs no edit, so the choice was one string in C12 rather than a migration. Deno was rejected
  despite its permission sandbox looking like a fit for typed **Manifests**: the process is spawned
  before a **Keyword** is known, so permissions would have to be the union of every **Script**,
  which enforces nothing — and tailoring them per **Script** means spawning after Enter, at 27 ms
  against F5's 20 ms. Its one differentiator is unreachable from this architecture.

  A node fallback was considered and rejected. Node's cold-spawn-per-run is 54.9 ms, 2.7× over F5,
  so falling back to it is not a slower version of the same design — it is a *different* one, which
  means keeping all of T3's resident-process machinery alive for a path exercised approximately
  never. That buys bun's speed and node's complexity at once, and hides the divergence until the
  one day it fires. A missing runtime is what F15 and C10 are already for: red before it is needed,
  the same treatment `gleam` gets.

  **T3 was settled at T1.4 and dropped** — see F5 and the T3 row. Verified in passing: `gleam test`
  runs gleeunit under `runtime = "bun"` with no extra configuration, and a throwing **Script** still
  exits 1 with stderr intact, so F12 holds. Confirmed again at T1.4 against a **Script** that
  `panic`s: bun's stack trace reaches the **Refusal**'s `detail` with the **Script**'s own message at
  the top of it.

- **`Process.waitUntilExit()` may not be used anywhere.** Measured at T1.4: 63–68 ms for
  `/usr/bin/true`, and it pays that even after the pipe has already reached EOF, so it is a polling
  loop rather than a wait — larger than three of the seven budget rows on its own. `posix_spawn` +
  `waitpid` is 5.9 ms and `terminationHandler` is free. C5 was written with it and was silently
  spending 65 ms of F4's 40 ms budget on nothing. Both C4 and C5 now wait on `terminationHandler`.
  **Trigger to revisit:** none — this is a fact about Foundation, not a decision. Worth knowing
  before adding a fourth process anywhere.

## 10. Inconsistencies spotted and fixed

- **`CONTEXT.md` claimed a **Script** is pure.** Writing the **Manifest** type showed it can't be —
  Youtube's fetch decides its **Effects**. The boundary is not purity: a **Script** owns the
  network, the **Shelf** owns the machine.
- **"Footprint" meant three things.** Split into G4 (idle cost), G2 (ready at login) and G6
  (**Vocabulary** size). Only after splitting did the 356-vs-10 number become the headline.
- **The **Stale** rule compared mtimes, and Gleam compares content.** Found at T1.4 by the first
  real `Starkit run work`, which **Refused** a **Script** that was perfectly current: `touch` a
  source and Gleam rightly recompiles nothing, leaving the **Artefact**'s mtime behind the source's
  forever, so nothing could ever clear the **Refusal**. `CONTEXT.md` already defined **Stale** as
  "built from source that has since changed" — the definition was right and the implementation was
  an approximation of it, which is why the fix needed no new vocabulary. Now hashes, in
  [ADR 0002](./docs/adr/0002-one-project-with-per-script-staleness.md). The generalisation is the
  part to remember: where the **Shelf** and Gleam disagree about what "changed" means, Gleam wins,
  because Gleam decides what gets compiled.
- **`install.sh` compares before it copies for a reason that has since evaporated.** It exists so
  that vendoring a byte-identical **Vocabulary** does not move its mtime and mark all five
  **Scripts** **Stale**. Under content hashing that cannot happen at all. The comparison is still
  worth keeping — it keeps the mtimes honest for anything else reading them — but it is no longer
  load-bearing, and C5's doc comment no longer claims it is.
- **"Shortcut" meant two mechanisms.** Resolved to **Keyword** only; the sole key chord
  **Summons** the **Shelf**.
- **The **Shelf** was assumed able to hold the keyboard without activating.** `main.swift` said so
  in as many words — that an app which never became active has nothing to take away, so nothing to
  give back. T0.5 showed the opposite: not activating costs the bar its keyboard entirely. The
  activation policy stays `.accessory` for the missing Dock icon, but the panel activates, and
  **Paste** hands activation back. Corrected where it was written down rather than only here.
- **"Restore the clipboard" was ambiguous** between the **Seed** and the pasted text. Resolved:
  keep the pasted text.
- **Nothing declared an **Input**, though `CONTEXT.md` had said so since before slice 0.** "A
  **Script** that declares an **Input** has it **Seeded**; one that declares none never is" was in
  the relationships all along, and `starkit.gleam` gave every **Script** a `String` whether it
  wanted one or not — so the sentence described a rule the types could not express and the bar could
  not read. Found at T5.1, which is the first task that needed the answer: an **Input** stage that
  appears is not something a return value can decide. The **Vocabulary** was right and the type was
  short of it, which is the same shape as the **Stale** correction at T1.4.
- **"Closed **Vocabulary**" read as frozen.** Corrected to closed-but-not-frozen.
- **Comment headers were recommended, then reversed.** The argument was that a broken **Script**
  must stay listed — but measurement showed a broken module fails the whole build either way, so
  the fallback was needed regardless and typed **Manifests** became free.
- **F5's first target (≤ 60 ms) was unambitious.** Measuring H3 tightened it to ≤ 20 ms; a
  target set before the spike would have shipped 8× slower than necessary and looked green.
- **F13 was missing entirely** from the first pass at functions, and F12 and F14 nearly were.
  Keyboard navigation is not a detail of the bar; it is most of what using the bar *is*.

---

## How to keep this honest

- When a new ADR lands → add its components to §7 and re-score affected rows.
- When a spike or measurement returns numbers → update §3 benchmarks, §8 `Measured`, **and §2's
  `Target (now)`**. §2 was left out of this rule until T8.1 and went stale for it: F5 still read
  "measured 6.7 ms warm", which is the warm-process number from the alternative T3 *rejected*, so the
  one line most people would read first described a design that was never built.
- Goals change rarely; functions change with each release; matrices are recomputed when either side changes.
- If a section becomes empty after edits, delete it — empty sections lie.
