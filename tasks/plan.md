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
2. ~~**Spawn-on-Summon** (T1.4).~~ **Retired — T3 dropped.** Measured through `Process` against the
   real `~/.starkit`, a cold spawn per run is 22.7 ms median (19.8 min, 24.2 p90), 3 ms over F5 on a
   threshold whose purpose is imperceptibility. The 6.7 ms alternative would have cost a stdin
   protocol in the vendored `run.mjs` as well as the lifecycle, since a process spawned before a
   **Keyword** is known cannot be handed one on `argv` — a cost `DESIGN.md` had not recorded. C4
   ships with no process lifecycle in it at all.

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
| T1.1 | **Vocabulary** types + `work` **Script** + `entry.gleam` answering `describe` / `run` | T0.3 | `bun run.mjs describe` prints 5 **Manifests**; `bun run.mjs run work '{}'` prints the `work` **Open** **Effects**. Not `entry.mjs` directly — it exports `main` without calling it (T0.3) |
| T1.2 | C12 Toolchain — login-shell resolution, `starkit.toml` override, named error when absent | T0.1 | with `PATH` stripped, the error names the **Toolchain**; no crash |
| T1.3 | C5 Builder + `Staleness` as a pure, tested rule. **Introduces a `StarkitCore` library target**: SwiftPM cannot cleanly link an executable into a test target, so everything tested lives outside the executable — `Staleness` and `Keyword` both move there | T1.2 | `swift test` — 4 cases: source changed, source unchanged, shared module changed, artefact missing |
| T1.4 | C4 Runner — spawn `bun`, feed a run, decode **Effects**, 5 s deadline | T1.1, T1.3 | `Starkit run work --dry-run` prints 4 **Open** **Effects**, opens nothing |
| T1.5 | C7 Effector — **Open** only | T1.4 | `Starkit run work` opens ghostty, Slack, Notion, Zen |
| T1.6 | Isolation check — no new code, an executable reading of [ADR 0002](../docs/adr/0002-one-project-with-per-script-staleness.md) | T1.5 | break `youtube.gleam`: `run work` still works, `run youtube` **Refuses** and prints the compile error |

T1.2 hands one thing forward: **resolution costs 510 ms and blocks the main thread at launch**, up
from an assumed ~40 ms, because the login shell has to be interactive to see `~/.zshrc` where
`PATH` is set (`DESIGN.md` §4, F9). Inside F9's 3 s, but it means **T2.1 should register the chord
before resolving**, not after — otherwise ⌃⌘K is dead for half a second after every login, which is
the one moment F9 exists to protect.

**Measured again at T5.2, from the other end.** `zsh -ilc` is **240–300 ms** on this machine against
the 510 ms recorded above, so the ordering decision stands on a number half its original size and
does not depend on it. What the second measurement added is where that cost falls: the **Shelf** pays
it once at launch, and `Starkit run` pays it *per invocation*, because every command is a fresh
process that has to ask the shell again. A `youtube` run from a terminal is ~470 ms of which ~50 ms is
YouTube, ~20 ms is `gleam build` on an up-to-date project and ~20 ms is `bun` — the rest is `~/.zshrc`.
The bar never pays any of it, which is why F5's budget and this row measure different things and both
are right.

Naming both paths in `starkit.toml` takes that run to **120–140 ms**, because `resolve` skips the
spawn when nothing is left to ask about. Worth knowing and *not* worth making the default: the file
holds hard-coded paths, so it trades a version manager's shim — the version-agnostic entry point F9
exists to resolve *to* — for speed on a debugging path. Recorded for T8.1, which owns the actuals.

T1.4 hands three things forward. **T3 is dropped**, so C1 has nothing to sequence a speculative
spawn against and F5's conflict with F1 no longer exists. **`Process.waitUntilExit()` is banned** —
63–68 ms of polling regardless of the child, which C5 was already paying against a 40 ms budget;
wait on `terminationHandler`. And **`Staleness` compares content, not mtimes** (ADR 0002, corrected):
the mtime rule refused a **Script** that no rebuild could ever make **Current** again, so the rule,
its tests and the ADR all moved to hashes and C5 now writes `~/.starkit/built.json` after every
successful build. **T1.6 is unaffected and still needs no new code** — the isolation it checks was
verified as part of this task.

T1.5 hands two things forward, both about **Open** costing more than a function call. **It blocks
until the launch is under way** — ~35 ms per application warm, 4.9 s for three cold Electron ones —
so T2.4 must perform **Effects** off the main thread, or the bar freezes for as long as the slowest
cold launch takes. And **which application ends up in front is not the last one asked for**: macOS
activates an application when its launch *finishes*, so a cold Slack arrives after a warm terminal
requested later. Serialising launches to fix that would cost seconds and buy nothing worth having,
so it is recorded rather than fixed, and `NSWorkspace.open` stays the synchronous call rather than
`openApplication(at:configuration:)` with a completion handler and a queue to think about.

T1.6 needed no new code and found nothing to change, which is the outcome it was written to check.
With `youtube.gleam` not compiling, `run work` opened its four applications and `personal`, `clean`
and `link` all still decided; `run youtube` **Refused** with "it has changed since it was last
built" above the Gleam diagnostic, box drawing intact. Two things worth having watched it do:
repairing the file brought `youtube` back with no other step, and copying a byte-identical
`starkit.gleam` over the vendored one — what `install.sh` does on every run — marked nothing
**Stale**. Both are the T1.4 correction from mtimes to content hashes, seen rather than asserted.

**Checkpoint B — reached.** One **Script** works end to end from a terminal, and the isolation
guarantee is demonstrated rather than asserted. This is the architecture proven; everything after
is surface.

## Phase 3 — The bar (slice 2)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T2.1 | C3 HotKey ⌃⌘K + C10 MenuBarStatus going red when it can't hold the chord | T0.1 | with Script Kit running, ⌃⌘K reaches Script Kit and Starkit does not take it; with Script Kit quit, the chord arrives |
| T2.2 | C1 SummonPanel — one `NSPanel` built at launch, shown/hidden, Escape hides | T2.1 | ≤ 50 ms to visible; the first ⌃⌘K is no slower than the tenth |
| T2.3 | C2 Catalogue — read `manifests.json`; `Keyword` parsing as a pure, tested rule | T1.1 | `swift test` — first token splits from **Input**; no match; **Keyword** that prefixes another |
| T2.4 | Bar view — list, filter, selection, ↩ runs | T2.2, T2.3 | `wo` selects Work, ↩ runs it, bar disappears |
| T2.5 | F13 — handle `moveUp:`/`moveDown:`/`insertNewline:`/`cancelOperation:` rather than keycodes | T2.4 | ⌃N/⌃P **and** ↑/↓ both move the selection |
| T2.6 | A click outside **Dismisses** the bar | T2.4 | click another window and the bar goes; a **Script**'s **Open** with the bar still up and it stays |

T2.1 removed half of its own function rather than implementing it. The chord registers and fires,
and it registers *before* the **Toolchain** resolution that costs 510 ms, which is visible in the
launch log — but "red when it can't hold the chord" turned out to have no signal behind it. Three
measurements, in the order they were taken: two processes both asking Carbon for ⌃⌘K are both
given it, neither told about the other; asking twice within one process is the only thing that
returns `eventHotKeyExistsErr`, so that branch guards a bug of ours rather than a conflict; and
with Script Kit running, ⌃⌘K opened Script Kit while Starkit's handler never ran at all — its
`uiohook` tap sees the key before Carbon dispatches it and consumes it. So the swallowing runs the
opposite way to the one the criterion feared, and the application being swallowed is Starkit.

Nothing was built to work around it. A tap of our own would cost the Accessibility grant F8 chose
`RegisterEventHotKey` to avoid, and would still lose to a tap inserted earlier; going red because
`CGGetEventTapList` reports *some* tap would be red on most machines, since text expanders and
window managers all keep one. What C10 reports is now the failures that are Starkit's own, and
`SPEC.md` slice 2 carries the withdrawal.

C10 grew a **Concern** in the process. C3 and C12 fail independently and at the same moment — no
`bun` on a machine where Script Kit also holds the chord — and a single `reason` meant whichever
was written second erased the first, which is the silence F8 exists to prevent.

T2.2 met F1 twice over and found that the criterion under it was the wrong shape. "The first ⌃⌘K is
no slower than the tenth" was written to force the panel to be built at launch, and building it at
launch does not achieve it: the first **Summon** cost 25.3 ms on screen and 60.9 ms to become key
against medians of 7.4 and 13.6, because the window server, the material and the first activation
charge once each and none of them are construction. A transparent off-screen `orderFront` at launch
pays all three where nothing is waiting, and the first **Summon** then lands on its own median. The
second number is the one that mattered: 60.9 ms is long enough to type into, and keys pressed before
the panel is key go to the application you came from.

The bar was designed here rather than at T2.4, because the panel had to hold something to be shown
at all: 680 × 64, radius 16, the carambola on a periwinkle chip leading the field, and a hairline
that will separate the header from T2.4's list. Colours are one four-colour palette
(`colorhunt.co/palette/fff2c6fff8deaac4f58ca9ff`), resolved per appearance rather than fixed —
a `CALayer` resolves its colours once, and this window is built at launch and never rebuilt, which
is precisely the case that keeps the wrong appearance's cream after the machine switches. Two
alignment defects were found by looking: an unbezeled `NSTextField` draws its text at the top of its
frame, and Tabler's fruit does not sit centred in the box it was authored in, so both are now
centred on their own ink.

Focus hand-back on hide rides on `NSApp.hide`, which is the same debt C7 pays before a **Paste** —
it gets its real test at T5.3, where something depends on it landing in the right application.

T2.3 had to write `manifests.json` as well as read it. SPEC has it "generated after each successful
build" and C6 is the thing that generates it — but C6 is slice 6, so until then launch is the only
moment anything is known, and a **Catalogue** that only reads would have read a file nothing writes.
`describe` is the verb `entry.gleam` already answered for exactly this and C4 grew a second call
alongside `run`.

The cache is read *before* the **Toolchain** is resolved and replaced only if the build and the
`describe` both work, which is F2 rather than defensiveness. Watched rather than asserted: with
`youtube.gleam` not compiling, the menu bar carried the Gleam error and all five **Scripts** stayed
listed — including the broken one, which is the case F2 exists for. Repairing the file put the
list back with no other step.

Two things settled in passing. `describe` answers a bare array while `run` answers an object, and
`entry.gleam` claimed both were objects — the code was right and the comment was wrong, because
listing cannot **Refuse**. And **Needs** cross as the strings `entry.gleam` names them rather than
as a Swift mirror of the `Need` type: nothing reads them until C8 gathers **Context** at T4.2, and
that is where a name that does not match has to be caught.

T2.4 is the first task where a **Script** runs because someone asked for it rather than because a
command was typed, and the number that matters is the one that says so: `↩ work — 4 Effects in
498.4 ms`, with every application already running. F4 and F5 account for about 50 ms of that and the
four **Opens** for the rest, which is T1.5's warning arriving — half a second of blocking on the
main thread would have frozen the menu bar along with the bar. So the whole ↩ path runs off it, and
the only thing that comes back is the sentence C10 shows.

F1 and F3 both hold with the list attached: **16.5, 11.0 and 7.1 ms** on screen across three
**Summons** against 50, and **2.0 ms** to narrow against 16 — where the 2.0 is the keystroke that
resizes the window and reveals a row, and a keystroke that changes neither costs 0.1. The rows are
built at launch and reused for that reason, which is F1's own argument one level down.

Three things were decided by looking rather than by taste. The panel grows **downwards** with the
match count and its top edge does not move, because a bar whose field jumps while you type into it
is a bar you cannot type into. Layout is set explicitly rather than by `autoresizingMask`: the head
keeping its distance from the top and the list absorbing the change are both flexible in the same
direction, and autoresizing splits a delta between everything flexible instead of giving it to the
one that asked. And `hide` empties the field only *after* the panel is off screen — clearing it
narrows back to the whole **Catalogue**, which shrinks the panel, which would have been a bar
collapsing on its way out.

Two things settled that were not asked for and are worth having. `ensureCurrent` moved from
`main.swift` onto **C5**, because the bar and the debug CLI would otherwise be two places deciding
whether a **Script** may run. And C10 grew its third **Concern**: ↩ hides the bar before the run
starts, so a **Refusal** from that run has nowhere on screen to land, and F12 asks that the message
survive the bar closing. It is the transient one — cleared by the next run that works — and T5.4 is
what takes it back into the bar, where a spinner gives the bar a reason to still be there.

Two things handed forward. **T2.5 is smaller than it looks and still worth doing**: ↩ could not be
built without handling a key, so it arrives as `insertNewline:` through the field's delegate rather
than as a keycode, which is F13's shape already — what is left is `moveUp:`/`moveDown:`, the
selection actually moving, and verifying that ⌃N/⌃P come free rather than assuming it. **The
eight-row cap needs the selection to catch up with it**: past the eighth match the way on is to type,
which is fine while nothing can select a row that is not shown, and stops being fine at T2.5.

One inconsistency spotted and left alone. F7's target is "≤ 10 ms otherwise", and its own §4 entry
has contradicted that since T1.5 measured **Open** at ~35 ms warm and seconds cold; four warm
**Opens** at ~440 ms of the 498 confirm it a second way. Moving a budget is a design decision rather
than bookkeeping, so it is recorded here for T8.1 to settle — either the target moves or the row
admits that **Open** is not a function call.

T2.5 spent nothing on either key. ⌃N and ⌃P are `moveDown:` and `moveUp:` in macOS's own bindings,
so the two selectors added for ↑/↓ answered all four ways of asking, and pressing them was the check
rather than the documentation: the band moved, and the log recorded no narrowing at all, which is the
other half of it — a ⌃N the field editor had kept would have arrived as a character typed into the
**Keyword**. F13 is now the reason this task was two `case`s instead of a keycode table.

The selection is bounded by the rows **shown** rather than by the matches, which is the eight-row cap
being answered rather than worked around: a selection free to travel past the eighth row would make
↩ run a **Script** whose name is not on screen, and a bar that lists rather than guesses cannot do
that. With five **Scripts** only the `matches.count` half of that bound is exercised; the `mostRows`
half waits for a **Catalogue** bigger than the bar. And it stops at both ends rather than wrapping —
with at most eight rows in front of you, wrapping saves a keystroke that was never expensive and
costs knowing where the band went.

F1 held a third time on the way past: **15.9 ms** on screen and **23.3 ms** to become key. The
selection moving is not measured, because it is not on a budget — F3's frame is the keystroke that
changes the *list*, and a moved band is two rows redrawing.

T2.6 was added after T2.4 rather than designed with it, because using the bar is what showed the
gap: click into another window and it stays on top of your work — `.floating`, on every space —
until you come back and press Escape. G2 asks for it to be there every time you reach for it, not
for it to be there when you did not.

The mechanism is the whole task. `hidesOnDeactivate` is the one-line version and it is wrong: at
T5.4 a **Script** runs with the bar up and an **Open** it performs activates another application,
which is the same loss of focus as a click and must not put the bar away. A mouse-down monitor
responds to the person instead, so a launch cannot be mistaken for a **Dismissal** and T5.4 needs no
"is a run in flight" flag. What has to be measured rather than assumed is the permission: a global
`NSEvent` monitor needs Accessibility for *keyboard* events and is believed not to for mouse-down,
and "one grant" is a SPEC boundary rather than a preference — if it does need one, the task is
withdrawn, not worked around.

No new function in `DESIGN.md` §2. Escape and ⌃⌘K put the bar away without one, and a third way to
do the same thing is not a fourteenth thing the design does.

The permission came back the way the task needed it to: the monitor **fired with
`AXIsProcessTrusted()` reporting `false`**, printed beside it in the same log rather than inferred
from the two facts separately. So mouse-down is outside the grant, T2.6 stands, and C7's line in
`DESIGN.md` §4 — that **Paste** is *the one thing* needing Accessibility — survives a task that could
have broken it. That check was temporary and is gone, for a reason worth keeping: the call is an IPC to
the accessibility subsystem and it sat on the **Summon** path, where it cost **46.3 ms of F1's 50** —
an instrument three times more expensive than everything it was measuring. With it removed, **10.7 ms
on screen and 16.3 ms to key**, which is where the previous three **Summons** were, so installing the
monitor costs nothing anyone can see.

The monitor lives only while the bar is up. A global monitor is Starkit in the path of every click on
the machine, and it would hold that position for the ~99% of the time the bar is not on screen, which
G4 is a promise about. Installing it in `summon` and removing it in `dismiss` is also what makes
"outside" free: a *global* monitor never sees events going to Starkit itself, so a click on the bar
is excluded by the window server rather than by hit-testing a frame — and the menu bar item is inside
for the same reason, which a frame test would have got wrong.

Both halves were verified, and the negative one is the half that matters. A click into another window
**Dismisses** the bar. Another application taking activation with no mouse-down does *not*: driven by
watching the log for a **Summon** and activating Calculator the moment one appeared, so no hand was
near the mouse, and the bar was still there over it. That is T5.4's hazard answered before T5.4
exists, and it is the case a focus-based implementation gets wrong.

**Checkpoint C** — reached. ⌃⌘K **Summons** the bar in 10.7 ms, `wo` narrows to Work, ↩ runs it, and
↑/↓/⌃N/⌃P move between the five. Three ways to put it away, and one that only looks like a fourth
and is refused. Starkit is usable for 2 of 5 **Scripts** (Work, Personal) — everything Phase 3 added
is how you *reach* a **Script**, not how many there are.

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

**Taken before Phase 4**, which the dependency column permits without a single edit: T5.1 needs T2.4,
T5.2 needs T1.1, and the rest need each other. Being the hard slice is the argument for moving it
rather than against — a Paste or a grant that behaves worse than T0.5's spike promised is cheap to
find now and expensive to find last. It also lands T5.4 while T2.4 and T2.6 are still warm, and T5.4
rewrites what they built: ↩ dismisses before running today, and a spinner is a reason to stay. What
moving it spends is Checkpoint D's "nothing needs Accessibility yet", so T5.5 starts mattering to
every rebuild in Phases 4, 6 and 7 rather than only to the last of them.

**T5.2 was taken before T5.1**, which the plan had the other way round. It needs no UI and it makes
`Starkit run youtube <url> --dry-run` print a **Paste** from a terminal, so the slice is proven on the
spine before any surface — Checkpoint B's own argument. T5.1 blocks nothing.

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T5.1 | **Input** stage in the bar + **Seed** from clipboard, selected | T2.4 | **Seed** arrives selected; typing replaces it without clearing |
| T5.2 | `youtube` **Script** + tests + `gleam_fetch` | T1.1 | `gleam test` — 6 URL shapes plus a bare 11-char ID; `run youtube --dry-run` prints a **Paste** |
| T5.3 | C7 **Paste** — restore focus, `CGEvent` ⌘V, leave the pasted text on the clipboard | T0.5, T5.2 | pastes into the app frontmost *before* the bar; ⌘V afterwards repeats it |
| T5.4 | **Notify** in the bar, spinner while running, 5 s kill | T5.3 | offline → **Notify**, no paste; a hung request dies at 5 s with a spinner until then |
| T5.5 | Accessibility grant survives a rebuild | T5.3 | rebuild, reinstall, paste still works with no new prompt |

T5.2 spent its decision before its code. `DESIGN.md` §9 had carried the asynchronous **Script** as an
open tension since T1.1 with T5.2 as its trigger, and *Ask first* covers both halves of it — a
**Vocabulary** word and a `gleam.toml` dependency. Both were asked. `Fetching` won over one uniform
promise-returning `run` on an argument that only appears once there is an installed machine to think
about: `install.sh` never overwrites `src/scripts/`, so the uniform version would have broken every
**Script** already written in `~/.starkit` on upgrade, with no migration possible, for the benefit of
code that never fetches. `gleam_fetch` won over hand-rolled `@external` because the ban on `@external`
in a **Script** is what makes the **Vocabulary** the whole interface, and widening it to smuggle in
HTTP trades a dependency for the one boundary the design has.

The tests are the pure half and nothing else: the ID and the markdown, 23 cases. The fetch is
untested on purpose — a test that reaches YouTube fails on a train, and what it would check is
oEmbed's behaviour rather than this **Script**'s. Two of those cases are the ones worth having.
`?sv=nonsense&v=<id>` is what catches a **Script** that searches the query for `v=` as text: `sv=`
ends in `v=`, so a text search pastes a working link to the wrong video, which is the failure that
never looks like one. And `hello world` is eleven characters that are not an ID, which is what stops
prose from being read as a video. The suite was checked by breaking the code rather than by passing:
one mutation to the query parser, four failures.

Verified end to end from a terminal against the real endpoint — all six shapes and a bare ID
canonicalise to the same watch URL, a non-YouTube host declines, and an ID-shaped string that is not a
video **Notifies**. Three things came out of running it that reading it did not give:

- **oEmbed answers 400, not 404, for an ID that belongs to nothing.** The first pass printed "YouTube
  answered 400." at a person who cannot act on a status code, so 400 joined 401, 403 and 404 in the
  one sentence that fits all four.
- **The canonical URL drops a timestamp.** `?t=42` belongs to the moment someone shared a video rather
  than to the video, and canonicalising is the whole reason for extracting an ID — three spellings of
  one video is a note you cannot search. Recorded as the known limit it is, in the same spirit as
  `link`'s wrong `h1`s.
- **`rsync -a` restores mtimes, and Gleam's incremental build trusts them.** Restoring a mutated
  scratch source from `seed/` left the *mutated* artefact in place, and the run that followed measured
  code that no longer existed. The reading of that run was wrong for one turn. Any scratch build for
  a measurement gets its `build/` deleted first, not its sources restored.

**A seeded Script cannot be upgraded, and that is now load-bearing.** `install.sh`'s rule — vendor the
**Shelf**'s half, write `src/scripts/` only when absent — is what keeps an employer's app list out of
this repo, and it also means every stub shipped is frozen on the machine it landed on. So `youtube`
working in `seed/` does not make it work in `~/.starkit`, whose copy is still the T5.2 stub. It is not
a bug in the rule and the rule should not change; it is a gap with no answer yet, and it will arrive
again for `clean` at T4.1 and `link` at T6.1. **Trigger:** the first stub a person has actually edited,
where replacing it is no longer obviously safe. Until then the answer is one `cp` and knowing it is
needed.

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
- **T5.2 cannot return `List(Effect)`** → it can't, and this is now known rather than pending.
  `gleam_fetch` is asynchronous on this target, so the **Vocabulary**'s `run` type has to admit a
  `Promise` one way or another. Surfaced at T1.1; the options and the reason for not choosing yet
  are in `DESIGN.md` §9. It costs a **Vocabulary** decision at T5.2, not a redesign.
- **T2.2 misses 50 ms** → drop the panel's blur/material before dropping anything behavioural.
- **Gleam moves its build output path** → C4 and C5 both hardcode
  `build/dev/javascript/<pkg>/<mod>.mjs`, which is not a documented interface. Narrowed at T0.3 to
  a single reference inside our own `run.mjs`, so a move is one line rather than a redesign.
  Recorded as a watched tension in `DESIGN.md` §9.
