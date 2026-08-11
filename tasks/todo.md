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
- [ ] **T4.2** C8 ContextGatherer + the `needs` → gather → payload path
- [ ] **T4.3** C7 **Kill** — `forceTerminate`

> **Checkpoint D** — 3 of 5.

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

- [ ] **T6.1** `link` **Script** + tests, including the pages the `h1` regex gets wrong
- [ ] **T6.2** Non-`https` **Input** → **Notify**

## Phase 7 — Boot

- [ ] **T7.1** C9 LoginItem — `SMAppService`, lifted from `cmd-tab`
- [ ] **T7.2** Moving the bundle and back does not silently unregister

## Phase 8 — Close the budget

- [ ] **T8.1** `--bench` flag; record actuals for all 7 rows of `DESIGN.md` §8
- [ ] **T8.2** Idle RSS and CPU for G4, recorded next to Script Kit's in `DESIGN.md` §3

## Deferred — slice 6, specified, outside MVP

- [ ] C6 Watcher — `FSEvents` → regenerate registry, build, rewrite manifests, set menu bar state
- [ ] C11 Scaffolder — template a **Script** from a **Keyword** and open it in Zed
