# Starkit — Implementation Plan

Ordered, vertically sliced tasks for MVP (slices 0–5 and 7 of [SPEC.md](../SPEC.md)). Acceptance
criteria live in `SPEC.md` per slice; this document holds the dependency order, the checkpoints,
and the verification command for each task. The task checklist is [todo.md](./todo.md).

Every task is one complete path that can be run and seen to work. No task builds a layer that
nothing exercises yet.

## Dependency graph

```
C12 Toolchain ──┬─→ C5 Builder ──→ C2 Catalogue ──┐
                │        │                        │
                └─→ C4 Runner ←──────────────────┐│
                         │                       ││
   C8 ContextGatherer ───┘                       ││
                         │                       ││
                         └─→ C7 Effector         ││
                                                 ││
              C3 HotKey ──→ C1 SummonPanel ←─────┘│
                                   ↑              │
                              (Keyword) ──────────┘

   C10 MenuBarStatus ← C3, C5, C12   (reports failure of each)
   C6 Watcher → C5, writes manifests + registry   (slice 6, not MVP)
   C11 Scaffolder → C6                            (slice 6, not MVP)
   C9 LoginItem                                   (independent, last)
```

Gleam side: `starkit.gleam` (**Vocabulary**) precedes everything; `registry.gleam` is generated
from `src/scripts/`; `entry.gleam` needs both.

**Critical path:** Vocabulary → entry → gen-registry → build → Toolchain → Builder → Runner →
Effector(Open). That path is slice 1 and it is the whole architecture end to end.

## Risk order

Two things could invalidate design decisions rather than just needing more work, so both are
pulled forward:

1. ~~**Paste** (T0.5, a spike).~~ **Retired.** `CGEvent` ⌘V lands in the previously frontmost app
   from a self-signed bundle, in 23.1 ms against F7's 200 ms, with multi-byte text intact and the
   grant surviving a rebuild. The **Effect** needed no rethinking — but pulling it forward paid for
   itself anyway, because it moved a different component: the bar cannot be typed into unless the
   **Shelf** activates, so C1 must take activation and C7 must hand it back. Found in slice 0 for
   the cost of one throwaway bundle; found in slice 4 it would have arrived on top of T2.2, T2.4
   and T5.1, all of which assume how the panel takes focus.
2. **Spawn-on-Summon** (T1.4). The 6.7 ms figure was measured with a hand-rolled harness, not
   inside an app under `SMAppService`. Fallback is cold spawn at 53 ms, which still meets the
   original F5 target, so this is a budget risk rather than a design risk.

Everything else has either a working precedent in `cmd-tab` or a measurement behind it.

## Phase 1 — Foundations (slice 0)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T0.1 | `Package.swift`, `Info.plist` (`LSUIElement`), `main.swift` with a menu bar item | — | `swift build`; app shows in menu bar, absent from Dock |
| T0.2 | `setup-signing.sh` + signing in `build.sh`, adapted from `cmd-tab` | T0.1 | `codesign -dv build/Starkit.app` reports the same identity after two rebuilds |
| T0.3 | `~/.starkit` skeleton: `gleam.toml`, `starkit.gleam` **Vocabulary**, `entry.gleam`, 5 **Script** stubs, `gen-registry.sh` | — | `cd ~/.starkit && gleam build`; running `gen-registry.sh` twice leaves `registry.gleam` unchanged |
| T0.4 | `install.sh`: `/Applications`, idempotent seed, first `gleam build` | T0.2, T0.3 | run twice; `shasum` of an edited **Script** identical before and after |
| T0.5 | **Paste spike** — throwaway: activate previous app, synthesise ⌘V, restore nothing | T0.2 | text lands in TextEdit after the panel hides; grant survives a rebuild |

**Checkpoint A — reached.** The app installs, keeps its signature, and **Paste** works at 23.1 ms.
The spike itself is deleted; what it measured is in `DESIGN.md` §4 (F7) and §9, and the code is in
git history rather than in the tree, because a throwaway that survives stops being one.

Two things it hands to later tasks:

- **T2.2 must activate**, and its "≤ 50 ms to visible" now needs reading as *visible*, not *ready
  to type*: `isKeyWindow` is still false on the run-loop turn that shows the panel, and settles
  about 50 ms later. Whether that is felt as latency is a T2.2 measurement, not an assumption.
- **T5.3 inherits held modifiers.** ⌃⌘K may still be down when a **Script** finishes, and a
  `CGEvent` built from `.combinedSessionState` would post ⌃⌘V. Unreachable from a menu-driven
  spike; the fix is `.privateState` or waiting on `flagsChanged`.

## Phase 2 — The spine, no UI (slice 1)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T1.1 | **Vocabulary** types + `work` **Script** + `entry.gleam` answering `describe` / `run` | T0.3 | `node run.mjs describe` prints 5 manifests; `node run.mjs run work '{}'` prints the `work` **Open** **Effects**. Not `entry.mjs` directly — it exports `main` without calling it (T0.3) |
| T1.2 | C12 Toolchain — login-shell resolution, `starkit.toml` override, named error when absent | T0.1 | with `PATH` stripped, the error names the **Toolchain**; no crash |
| T1.3 | C5 Builder + `Staleness` as a pure, tested rule. **Introduces a `StarkitCore` library target**: SwiftPM cannot cleanly link an executable into a test target, so everything tested lives outside the executable — `Staleness` and `Keyword` both move there | T1.2 | `swift test` — 4 cases: source newer, artefact newer, shared module newer, artefact missing |
| T1.4 | C4 Runner — spawn `node`, feed a run, decode **Effects**, 5 s deadline | T1.1, T1.3 | `Starkit run work --dry-run` prints 4 **Open** **Effects**, opens nothing |
| T1.5 | C7 Effector — **Open** only | T1.4 | `Starkit run work` opens ghostty, Slack, Notion, Zen |
| T1.6 | Isolation check — no new code, an executable reading of [ADR 0002](../docs/adr/0002-one-project-with-per-script-staleness.md) | T1.5 | break `youtube.gleam`: `run work` still works, `run youtube` refuses and prints the compile error |

**Checkpoint B** — one **Script** works end to end from a terminal, and the isolation guarantee is
demonstrated rather than asserted. This is the architecture proven; everything after is surface.

## Phase 3 — The bar (slice 2)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T2.1 | C3 HotKey ⌃⌘K + C10 MenuBarStatus going red when it can't hold the chord | T0.1 | with Script Kit running, icon is red **and** ⌃⌘K reaches Script Kit — never swallowed |
| T2.2 | C1 SummonPanel — one `NSPanel` built at launch, shown/hidden, Escape hides | T2.1 | ≤ 50 ms to visible; the first ⌃⌘K is no slower than the tenth |
| T2.3 | C2 Catalogue — read `manifests.json`; `Keyword` parsing as a pure, tested rule | T1.1 | `swift test` — first token splits from **Input**; no match; **Keyword** that prefixes another |
| T2.4 | Bar view — list, filter, selection, ↩ runs | T2.2, T2.3 | `wo` selects Work, ↩ runs it, bar disappears |
| T2.5 | F13 — handle `moveUp:`/`moveDown:`/`insertNewline:`/`cancelOperation:` rather than keycodes | T2.4 | ⌃N/⌃P **and** ↑/↓ both move the selection |

**Checkpoint C** — ⌃⌘K runs Work. Starkit is usable for 2 of 5 **Scripts** (Work, Personal).

## Phase 4 — Clean (slice 3)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T4.1 | `clean` **Script** + `gleeunit` tests, **tests written first** | T1.1 | `gleam test` — untouchables excluded, empty list, Starkit itself never **Killed** |
| T4.2 | C8 ContextGatherer + the `needs` → gather → payload path | T1.4 | `run clean --dry-run` shows **Running Apps** in the payload; no `osascript` process spawned |
| T4.3 | C7 **Kill** — `forceTerminate` | T4.2 | Clean **Kills** every regular app but the untouchables; Starkit survives |

Tests precede implementation here and nowhere else: **Kill** never asks, and a filter bug is
irreversible. See `SPEC.md` § Testing strategy.

**Checkpoint D** — 3 of 5 **Scripts** working. Nothing needs Accessibility yet.

## Phase 5 — Youtube (slice 4)

The hard slice. Everything permission-, timing- and ordering-sensitive lives here.

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T5.1 | **Input** stage in the bar + **Seed** from clipboard, selected | T2.4 | **Seed** arrives selected; typing replaces it without clearing |
| T5.2 | `youtube` **Script** + tests + `gleam_fetch` | T1.1 | `gleam test` — 6 URL shapes plus a bare 11-char ID; `run youtube --dry-run` prints a **Paste** |
| T5.3 | C7 **Paste** — restore focus, `CGEvent` ⌘V, leave the pasted text on the clipboard | T0.5, T5.2 | pastes into the app frontmost *before* the bar; ⌘V afterwards repeats it |
| T5.4 | **Notify** in the bar, spinner while running, 5 s kill | T5.3 | offline → **Notify**, no paste; a hung request dies at 5 s with a spinner until then |
| T5.5 | Accessibility grant survives a rebuild | T5.3 | rebuild, reinstall, paste still works with no new prompt |

**Checkpoint E** — 4 of 5, and the only permission-gated path is working and stable across
rebuilds.

## Phase 6 — Link from url (slice 5)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T6.1 | `link` **Script** + tests, including pages where the `h1` regex is wrong | T5.3 | `gleam test`; a real URL pastes `[Title](url)` with quotes and dashes normalised |
| T6.2 | Non-`https` **Input** → **Notify** | T6.1 | typing a non-URL produces a **Notify** and no paste |

The known-wrong pages are recorded as the limit of a regex standing in for a DOM selector, not
fixed. Fixing them means an HTML parser, which is a **Vocabulary** decision (`Ask first`).

## Phase 7 — Boot (slice 7)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T7.1 | C9 LoginItem — `SMAppService`, lifted from `cmd-tab`; menu toggle reflects reported state | T0.4 | reboot: menu bar item present, ⌃⌘K works within 3 s |
| T7.2 | Bundle moved out of `/Applications` and back does not silently unregister | T7.1 | the menu shows what `SMAppService` reports, never a cached assumption |

## Phase 8 — Close the budget

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T8.1 | `--bench` flag; measure every row of [DESIGN.md](../DESIGN.md) §8 and record actuals | T7.1 | all 7 budget rows carry a measured number, not a target |
| T8.2 | Idle cost measurement for G4 | T7.1 | idle RSS and idle CPU recorded in `DESIGN.md` §3, next to Script Kit's |

T8.2 fills the one blank in the competitive assessment: Script Kit's idle RSS was never measured
because it wasn't running. Starkit's should not be a blank too.

## Deferred (slice 6, specified but outside MVP)

C6 Watcher and C11 Scaffolder. Until they land, a new **Script** costs a manual
`scripts/gen-registry.sh`. Since **Scripts** are always written in Zed and the Watcher is the only
thing that makes a new one visible, expect to want this immediately after MVP — see
`SPEC.md` for its acceptance criteria.

## What would change the plan

- ~~**T0.5 fails**~~ → it didn't. The alternatives it would have forced — synthesising keystrokes
  character by character, or clipboard-only with ⌘V pressed by hand — are unneeded and recorded
  only because their absence is what makes the **Paste** **Effect** as simple as it is.
- **T1.4 misses 20 ms** → fall back to cold spawn at 53 ms, which still meets F5's original
  target. Budget risk, not design risk.
- **T2.2 misses 50 ms** → drop the panel's blur/material before dropping anything behavioural.
- **Gleam moves its build output path** → C4 and C5 both hardcode
  `build/dev/javascript/<pkg>/<mod>.mjs`, which is not a documented interface. Narrowed at T0.3 to
  a single reference inside our own `run.mjs`, so a move is one line rather than a redesign.
  Recorded as a watched tension in `DESIGN.md` §9.
