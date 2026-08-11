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
| G7  | Upgrading node or Gleam never breaks it, and I never tell it where they are | 7 | stated: "easily update node and gleam versions or getting the default one" |
| G5  | I write Gleam, not glue around Gleam          |   6    | choosing Gleam was the point; [ADR 0001](./docs/adr/0001-compile-gleam-to-javascript.md) |
| G6  | There's almost nothing to remember            |   6    | stated: "real simplicity" — a small **Vocabulary** baseline, not a cap |

G2 outranks G1 deliberately: a launcher that is fast but occasionally absent is worse than one
that is merely quick, because the absence costs a whole trip to diagnose.

## 2. Functions — the HOWs

### Summon & match

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F1  | Put the bar on screen                   |  ↓  | ≤ 50 ms from ⌃⌘K                 |
| F2  | Know the catalogue without building     |  ↓  | ≤ 5 ms, from cached manifests    |
| F3  | Narrow to a **Script** as you type      |  ↓  | ≤ 16 ms — one frame              |
| F13 | Drive the whole bar from the home row   |  ↑  | 0 mouse, 0 arrow-key-only paths; ⌃N/⌃P work |

### Build & run

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F4  | Bring the **Artefact** up to date, or refuse | ↓ | ≤ 40 ms — measured 26–33 ms   |
| F5  | Execute the **Artefact**                |  ↓  | ≤ 20 ms — measured 6.7 ms warm   |
| F6  | Gather only the declared **Context**    |  ↓  | ≤ 5 ms — vs 463 ms via `osascript` |

### Act

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F7  | Perform each **Effect** in order, restoring focus before **Paste** | ↓ | ≤ 200 ms for **Paste**, ≤ 10 ms otherwise |

### Survive

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F8  | Hold the chord, and be visibly broken when it can't | ↑ | 100 % held; failure shown, never silent |
| F9  | Be ready after login                    |  ↓  | ≤ 3 s                            |
| F10 | Surface breakage at save time, not **Summon** time | ↓ | ≤ 500 ms after save   |
| F12 | Report a run that failed at runtime     |  ↑  | message survives the bar closing |
| F14 | Bound how long a run may hold the bar   |  ↓  | killed at 5 s; spinner shown while running |
| F15 | Follow the **Toolchain** the shell reports, and notice when it moves | ↑ | 0 manual configuration; a missing runtime is red before it is needed |

### Author

| ID  | Function                                | Dir | Target (now)                     |
| --- | --------------------------------------- | :-: | -------------------------------- |
| F11 | Turn an unmatched **Keyword** into a new **Script** | ↓ | 1 file touched, 0 registry edits, 1 deliberate confirmation |

## 3. Competitive assessment

Against Script Kit, which is the incumbent and does all five jobs today. Measured on this
machine; blanks are where nothing was measured.

**Function benchmarks**

| Function                     | Starkit (target)   | Script Kit (measured) |
| ---------------------------- | ------------------ | --------------------- |
| F5 execute                   | ≤ 20 ms            | —                     |
| F6 gather **Running Apps**   | ≤ 5 ms, in-process | 463 ms, `osascript`   |
| **Vocabulary** size (G6)     | 10 bespoke names   | 356 injected globals  |
| On-disk total (G4)           | ~4 MB              | ~1.86 GB              |
| — the app                    | ~1 MB              | 717 MB (Electron)     |
| — support directory          | ~3 MB              | 1.1 GB `~/.kit` + 42 MB `~/.kenv` |

**What this tells us.** The `osascript` figure is the single largest latency in the current
system and disappears entirely by moving **Context** gathering in-process. The 356-to-10
vocabulary ratio is what "real simplicity" meant, and it is already banked by the closed
vocabularies in `CONTEXT.md` — so the design's job on G6 is not to erode it. Nothing about
Script Kit's idle RSS was measured, because it was not running.

## 4. Cascade — Goals → Functions → How → Components

Each function sits under the goal it serves most; secondary goals are noted inline.

- **G2** It's there every time I reach for it _W:10_
  - **F8** Hold the chord, be visibly broken when it can't
    - **How**: `RegisterEventHotKey` — needs no permission and cannot be silently disabled,
      unlike the `CGEventTap` in `cmd-tab`, which only needed a tap because it *intercepts* ⌘⇥
      - **Component**: C3 HotKey · C10 MenuBarStatus
  - **F9** Be ready after login _(also G4)_
    - **How**: `SMAppService.mainApp`, no helper bundle. A login-launched app gets a minimal
      `PATH`, so the toolchain is resolved at each launch by asking the login shell
      (`/bin/zsh -lc 'command -v node'`) — 15 ms, and it follows version-manager moves for free.
      Rejected: caching absolute paths at install, which pins whatever the shim happened to
      resolve to. `~/.starkit/starkit.toml` holds an *override* for when the shell lies, not the
      source of truth
      - **Component**: C9 LoginItem · C12 Toolchain
  - **F10** Surface breakage at save time, not **Summon** time
    - **How**: `FSEventStream` on `~/.starkit/src` → build, then set the menu bar state
      - **Component**: C6 Watcher · C10 MenuBarStatus
  - **F4** Bring the **Artefact** up to date, or refuse _(also G1)_
    - **How**: watcher builds on save, so **Summon** usually finds the work already done; the
      shelf re-checks as a safety net. Per-**Script** mtime decides **Stale**
      ([ADR 0002](./docs/adr/0002-one-project-with-per-script-staleness.md))
      - **Component**: C5 Builder
  - **F12** Report a run that failed at runtime
    - **How**: capture the child's stderr; the bar is still on screen, because only a **Paste**
      closes it — so a crash needs no notification channel of its own
      - **Component**: C4 Runner
  - **F14** Bound how long a run may hold the bar
    - **How**: kill at 5 s with a spinner while running. Rejected: dismiss-and-orphan, which
      would land **Effects** minutes later in whatever app you had since switched to
      - **Component**: C4 Runner

- **G1** The automation fires before I notice waiting _W:9_
  - **F1** Put the bar on screen
    - **How**: one `NSPanel` built at launch, then shown and hidden — so the first ⌃⌘K of a
      session costs what the hundredth does (`cmd-tab`'s precedent)
      - **Component**: C1 SummonPanel
  - **F2** Know the catalogue without building
    - **How**: `manifests.json`, rewritten by the watcher after each successful build. Reading a
      cache rather than describing on demand is also what keeps the bar usable while broken
      - **Component**: C2 Catalogue · C6 Watcher
  - **F3** Narrow to a **Script** as you type
    - **How**: prefix match on **Keyword** over ~5 entries; no index worth building
      - **Component**: C2 Catalogue · C1 SummonPanel
  - **F5** Execute the **Artefact**
    - **How**: spawn `node` when the bar appears, kill it once idle and dismissed. Ready in
      46 ms of the 400–800 ms you spend typing, then 6.7 ms per run, at 0 MB idle. Rejected:
      resident `node` (0.03 ms but 52 MB and needs mtime cache-busting), cold spawn per run
      (53 ms). A fresh process per **Summon** also means a fresh module cache, so an edited
      **Script** is always the one that runs
    - **Conflicts with F1**: the spawn must happen *after* the panel is on screen, never before
      it. 46 ms of `posix_spawn` ahead of the bar would eat most of F1's 50 ms budget to save
      time later — exactly backwards, since the bar appearing is the part you can see
      - **Component**: C4 Runner
  - **F6** Gather only the declared **Context**
    - **How**: `NSWorkspace.runningApplications` filtered to `.activationPolicy == .regular`,
      in-process. Replaces a 463 ms `osascript` call that also needed Automation permission
      - **Component**: C8 ContextGatherer
  - **F7** Perform each **Effect** in order, restoring focus before **Paste** _(also G5)_
    - **How**: `openApplication` / `forceTerminate` need no permission; **Paste** activates the
      previously frontmost app then synthesises ⌘V via `CGEvent`, which is the one thing needing
      Accessibility. Pasted text stays on the clipboard by design. Measured at T0.5: 23.1 ms for
      the whole **Paste**, of which 19.4 ms is waiting for the previously frontmost app to report
      itself active again. Awaited via `didActivateApplicationNotification` rather than polled,
      because polling would block the run loop that notification has to arrive on; the deadline
      behind it exists for the case where it never fires. Multi-byte text arrives intact, so it is
      not a second problem to solve, and the Accessibility grant reaches a process already
      running — unlike the event tap in `cmd-tab`, nothing restarts after it is given
      - **Component**: C7 Effector

- **G3** A new automation is one file and one minute _W:7_
  - **F11** Turn an unmatched **Keyword** into a new **Script**
    - **How**: write `src/scripts/<keyword>.gleam` from a template and open it in `$EDITOR`
      (Zed) — the bar scaffolds, the editor is where all typing happens. Registry generation is a
      consequence of `src/` changing, not of using the create flow, so a **Script** written
      directly in Zed registers itself too; that is the *only* path by which a new **Script**
      becomes visible, which makes the Watcher load-bearing rather than a convenience. The
      `Create "foo"` row is never the default selection, so Enter on a typo does nothing at all
      - **Component**: C11 Scaffolder · C6 Watcher
  - **F13** Drive the whole bar from the home row _(also G1)_
    - **How**: handle Cocoa action selectors (`moveUp:`, `moveDown:`, `insertNewline:`,
      `cancelOperation:`) rather than keycodes, inheriting ⌃N/⌃P, the arrows, ⌃A/⌃E/⌃K and any
      future `DefaultKeyBinding.dict` for free
      - **Component**: C1 SummonPanel

- **G7** Upgrading node or Gleam never breaks it _W:7_
  - **F15** Follow the **Toolchain** the shell reports, and notice when it moves
    - **How**: ask the login shell at each launch. Nothing is pinned, so a node or Gleam upgrade
      is not an event. Measured: 15 ms, and it resolves `~/.vite-plus/bin/node` — the shim, which
      is the version-agnostic entry point. Rejected: caching `process.execPath`, which is the
      *most* fragile of the three available paths because it pins the node version
      (`…/js_runtime/node/24.19.0/bin/node`); and a hardcoded `PATH` list, which would have missed
      `.vite-plus` entirely. The shim costs ~10 ms per spawn over the real binary, hidden inside
      the typing window
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
| C4  | Runner            | spawn/kill `node`, feed a run, 5 s deadline, collect **Effects** and stderr | ADR-0001 |
| C5  | Builder           | `gleam build`, per-**Script** **Stale** check by mtime        | ADR-0002 |
| C6  | Watcher           | `FSEvents` → regenerate registry, build, rewrite manifests   | ADR-0002 |
| C7  | Effector          | perform **Open** / **Kill** / **Paste** / **Notify**, focus and clipboard |          |
| C8  | ContextGatherer   | gather declared **Context** slices in-process                |          |
| C9  | LoginItem         | `SMAppService` registration                                 |          |
| C10 | MenuBarStatus     | normal / red, the only ambient signal Starkit emits          |          |
| C11 | Scaffolder        | template a new **Script** from a **Keyword**                 |          |
| C12 | Toolchain         | resolve `node` and `gleam` paths from `starkit.toml`         |          |

**Where the effort goes.** C4 and C7 carry the most risk: C4 owns process lifecycle and the
deadline, C7 owns the only permission-gated operation in the system. C6 is the quiet
load-bearing one — it is what makes F2, F4, F10 and F11 all cheap, and if it stops firing,
everything still works but silently goes **Stale**.

## 8. Critical performance budget

| Rank | Function | Target | Watched on | If we miss it |
| ---- | -------- | ------ | ---------- | ------------- |
| 1 | F1 bar on screen | ≤ 50 ms from ⌃⌘K | manual feel, then a signpost trace | panel is pre-built; if still slow, drop the blur/material before dropping correctness |
| 2 | F8 hold the chord | 100 % | menu bar turns red on registration failure | fall through to no-op rather than swallowing the chord; never fail silently |
| 3 | F5 execute | ≤ 20 ms warm | log per-run µs behind a debug flag | fall back to cold spawn (53 ms) if the resident-per-**Summon** process proves flaky |
| 4 | F4 build | ≤ 40 ms | time each `gleam build` | if it regresses, trust the watcher's build and skip the **Summon**-time re-check |
| 5 | F9 ready after login | ≤ 3 s | first ⌃⌘K after a reboot | if `starkit.toml` paths are wrong, go red immediately rather than failing on first run |
| 6 | F14 run deadline | 5 s | the deadline itself | none needed — this *is* the fallback |
| 7 | F6 gather **Context** | ≤ 5 ms | only if a slice ever needs more than `NSWorkspace` | any slice needing a subprocess must be declared, so the cost stays opt-in |

## 9. Tradeoffs — Got / Paid / ADR

| ID  | Tradeoff | Got | Paid | ADR |
| --- | -------- | --- | ---- | --- |
| T1 | JavaScript target over Erlang | 93 ms vs 450 ms end-to-end; `fetch` free | no BEAM, no OTP, no actors, no Erlang-only Hex | [0001](./docs/adr/0001-compile-gleam-to-javascript.md) |
| T2 | One project over five | one dep tree, 2.8 MB vs ~14 MB, one-file **Script** creation | all **Scripts** share a build; needs the mtime **Stale** rule to stay isolated | [0002](./docs/adr/0002-one-project-with-per-script-staleness.md) |
| T3 | Spawn `node` on **Summon** | 6.7 ms runs at 0 MB idle; fresh module cache each time | 46 ms of speculative work per **Summon**; a process lifecycle to get right | |
| T4 | **Effects** out, no bidirectional channel | no blocking stdin in Gleam; Accessibility lives in one signed binary; **Scripts** testable by reading stdout | no dynamic pick-lists — Clean stays all-or-nothing | |
| T5 | Typed manifests over comment headers | declarations are compile-checked; **Effect** and **Context** can't drift | ~80 lines of Gleam; the registry must be generated | |
| T6 | Keep pasted text on the clipboard | paste the same result into several places by hand | re-**Summoning** a **Script** **Seeds** from its own output | |
| T7 | **Kill** over quit | an empty screen, immediately | unsaved work is lost, deliberately | |
| T8 | Local `install.sh` over Homebrew | no notarization, no quarantine, a stable signature that keeps the Accessibility grant | nobody else can install it in one line | |
| T9 | Tree only, no importance matrix | no 72-cell grid to keep current | component priority is argued from goal weights, not computed | |
| T10 | Borrow the **Toolchain**, resolve it every launch | node and Gleam upgrades are non-events; nothing to configure | 15 ms per launch, and a broken `.zshrc` breaks resolution — though it would break your terminal first | |

### Tensions being watched

- **No dynamic pick-lists** (T4). Clean kills everything or nothing. **Trigger to revisit:** a
  **Script** that genuinely must choose among options computed at run time — at which point the
  outbound channel becomes bidirectional rather than being replaced.
- **Editing a **Script** while another is broken blocks it** (T2). **Trigger:** it actually
  costs you a morning; the fix is per-**Script** projects, and it is not free.
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
- **A synthesised ⌘V inherits the modifiers physically held down.** `CGEventSource` built from
  `.combinedSessionState` carries real modifier state, and ⌃⌘K may still be held when a **Script**
  finishes — which would post ⌃⌘V rather than ⌘V. Not reachable from T0.5, whose trigger was a
  menu. **Trigger:** the first **Paste** driven from the chord, at T5.3; the fix is `.privateState`
  or waiting on `flagsChanged`, and it is cheap once seen.
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

## 10. Inconsistencies spotted and fixed

- **`CONTEXT.md` claimed a **Script** is pure.** Writing the manifest type showed it can't be —
  Youtube's fetch decides its **Effects**. The boundary is not purity: a **Script** owns the
  network, the **Shelf** owns the machine.
- **"Footprint" meant three things.** Split into G4 (idle cost), G2 (ready at login) and G6
  (**Vocabulary** size). Only after splitting did the 356-vs-10 number become the headline.
- **"Shortcut" meant two mechanisms.** Resolved to **Keyword** only; the sole key chord
  **Summons** the **Shelf**.
- **The **Shelf** was assumed able to hold the keyboard without activating.** `main.swift` said so
  in as many words — that an app which never became active has nothing to take away, so nothing to
  give back. T0.5 showed the opposite: not activating costs the bar its keyboard entirely. The
  activation policy stays `.accessory` for the missing Dock icon, but the panel activates, and
  **Paste** hands activation back. Corrected where it was written down rather than only here.
- **"Restore the clipboard" was ambiguous** between the **Seed** and the pasted text. Resolved:
  keep the pasted text.
- **"Closed **Vocabulary**" read as frozen.** Corrected to closed-but-not-frozen.
- **Comment headers were recommended, then reversed.** The argument was that a broken **Script**
  must stay listed — but measurement showed a broken module fails the whole build either way, so
  the fallback was needed regardless and typed manifests became free.
- **F5's first target (≤ 60 ms) was unambitious.** Measuring H3 tightened it to ≤ 20 ms; a
  target set before the spike would have shipped 8× slower than necessary and looked green.
- **F13 was missing entirely** from the first pass at functions, and F12 and F14 nearly were.
  Keyboard navigation is not a detail of the bar; it is most of what using the bar *is*.

---

## How to keep this honest

- When a new ADR lands → add its components to §7 and re-score affected rows.
- When a spike or measurement returns numbers → update §3 benchmarks and §8 `Target` / `Watched on`.
- Goals change rarely; functions change with each release; matrices are recomputed when either side changes.
- If a section becomes empty after edits, delete it — empty sections lie.
