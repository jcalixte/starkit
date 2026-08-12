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

**T4.1's first run was a compile error**, which is the only honest shape "tests first" can take:
`clean.kills` did not exist when the sixteen assertions asking about it were written. The one that
matters was then confirmed by breaking the code rather than by reading it — emptying the untouchable
list turns four of them red — so the suite is known to catch the bug that has no undo, rather than
assumed to.

**The keep list is an argument, and that is what made the destructive half testable.** It is edited
per machine, so a suite asserting its contents would pass on exactly one computer; `kills` takes it
instead, the tests pass their own, and what is asserted about the *shipped* **Script** is only what
must hold everywhere: Starkit survives, and **Running Apps** is declared. The **Script**'s whole body
is that one call, so there is no step between what the tests pin and what the **Shelf** performs.

**Two lists, because they are two different promises.** `keep` is a preference and sits at the top of
a file the installer never overwrites. `untouchable` is a rule that holds whatever `keep` says, and
Starkit is in it for a reason that outlives the current code: **Effects** are performed in order, so
a **Kill** aimed at Starkit would end the run partway down its own list and leave the rest of the
screen open. C8 already makes that unreachable — it hands over `.regular` applications and Starkit is
an accessory — so the line is a second lock on a shut door, kept because the two locks are on
opposite sides of the wire and only one of them has tests. Finder went in the other list, and the
difference is the point: killing Finder is not dangerous, it is pointless, because macOS starts it
again.

**Names match whole, without case or surrounding spaces.** Both allowances lean the same way — they
make keeping more likely, never less — which is the only direction an irreversible **Effect** should
be forgiving in. Prefix matching leans that way too and much further, and costs the thing worth more
here than kindness to a typo: with it, nobody can say in advance what a keep list keeps. The price is
paid in the obvious place, and it is written down where the list is: `Chrome` does not keep
`Google Chrome`.

**Nothing dies yet, by construction rather than by luck.** `running_apps` arrives empty until C8
exists at T4.2, and a **Kill** is a **Refusal** naming itself until T4.3. So Clean is complete and
inert, which is the order this phase asked for and the reason the tests are the only evidence T4.1
could have produced.

**The seeded-Script gap arrived again, exactly where this file predicted it.** `~/.starkit`'s
`clean.gleam` is still the stub and no install will replace it, because `src/scripts/` is yours. It
has never been edited, so the copy is safe and known to be safe — which is the whole of the answer
from T5.1: per file, and you have to know which.

**T4.2 is the smallest component in the system and it beat its budget by three orders of
magnitude**: one `NSWorkspace` property, filtered to `.regular`, at **0.006–0.016 ms** against F6's
5 ms — where the `osascript` it replaces cost 463 ms and an Automation grant. `Starkit run clean
--dry-run` prints the **Context** above the **Effects** it produced, which is the verify line this
table asked for, and no `osascript` was spawned while it ran.

**The one number that misses the budget is the first one.** The first read of
`runningApplications` in a process costs 2.8–7.8 ms and every read after it costs a hundredth of a
millisecond, so what is expensive is connecting to the workspace and not asking it anything. Left
alone, the first Clean of a session would be the single gather that misses F6, on the main thread.
It is paid at launch instead — the same trade C1 makes by building its window there (T2.2), and in
the same place, which is already spending 510 ms on the **Toolchain** with nobody waiting.

**Declared is what makes the cost free rather than merely small.** `Starkit run work --dry-run`
gathers nothing and measures 0.00 ms, because Work's `needs` is empty. F6 says *only* the declared
**Context** and this is the half of that sentence a benchmark can show.

**An unknown Need is refused rather than skipped, which is the same call `Effect` makes in the
other direction.** A **Script** declaring a slice this binary cannot gather would otherwise run and decide
from an empty **Context**, and nothing downstream can tell that apart from an empty machine — Clean
would read it as "nothing is running". So `Need.all` refuses, naming the word and the **Script**,
and blaming the half that is actually ahead: the **Vocabulary** vendored in `~/.starkit`. The
**Manifest** keeps its **Needs** as strings for the same reason it always did, and now there is a
sharper one — decoding them at *listing* time would empty the bar of every **Script** on a cache
that names one unknown slice, which is precisely the collapse F2 exists to prevent.

**Where the gather happens was the one open question, and it is the main actor.** `NSWorkspace`'s
list is AppKit's own, and `focus.previous` is already read there for a reason that applies twice
over: both answers should describe the machine as ↩ was pressed, rather than as a `gleam build`
left it several hundred milliseconds later. The bar path pays 0.01 ms on the main thread for that,
which is what the warming at launch is for.

**T4.3 was verified at a scale that could be undone.** The acceptance line is "Clean **Kills** every
regular app but the untouchables", and on this machine performing it literally closes the terminal
the verification is running in. So the whole path was exercised against a scratch `STARKIT_HOME`
whose keep list spared everything except one expendable application: **Context** gathered, filter
applied, `Kill` decided, `forceTerminate` performed, Calculator gone, Ghostty, Zed, Firefox and
Starkit still standing. Same code, same wire, one name. The full-screen version is a person's to
run, not a verification's.

**The first real Kill matched nothing, and the reason was the machine's language.**
`localizedName`
is what an application calls itself *here*, and here that is `Calculatrice` — so `Kill("Calculator")`
found nothing to kill and said so, while `Open("Calculator")` would have launched it, because
LaunchServices answers to either spelling. One string that opens an application and then cannot close
it is a seam in the **Vocabulary**, not a quirk of one **Effect**, and it is closed by asking
LaunchServices the same question for a **Kill** that **Open** already asks. Recorded in `CONTEXT.md`
as the ambiguity it is: "the name of an application" was two names all along, and only a machine that
is not in English can tell you. A keep list has no such help — it is compared against the displayed
name, because that is what a **Running Apps** **Context** is made of.

**Three decisions about what a Kill does when it cannot do exactly what it was told.**

- **Nothing running by that name is done, not refused.** The **Effect** asks that an application not
  be running, and one that quit between the gather and the **Kill** has answered it. Refusing would
  abandon the rest of the list over a race in the machine — and Clean's list is aimed at a
  **Context** sampled milliseconds earlier, so that race is the normal case rather than the exotic
  one. The cost is a misspelt name passing in silence where **Open** would be loud, and it is
  unavoidable: from C7, "already gone" and "never existed" are the same absence. The log says so.
- **A **Kill** aimed at Starkit is a **Refusal**.** `clean.gleam` keeps Starkit off its own list and
  C8 never gathers it, but both of those are about a name arriving *from* a **Context**, and any
  **Script** can write the word itself. Starkit ending mid-run would leave every **Effect** after it
  as a decision nobody carried out. Matched by the names Starkit answers to rather than by process,
  which is what also stops a terminal run from killing the Starkit holding ⌃⌘K — and neither name is
  written down, because a guard that hard-codes the product's name stops being true the day it
  changes.
- **Every instance answering to the name dies.** Two copies of one application are the same answer
  to "that should not be running".

**Checkpoint D** — reached. 3 of 5 **Scripts**, and the destructive one behaves as designed: it
closes what it was told to and nothing else, and it cannot close the thing performing it. "Nothing
needs Accessibility yet" is the half of this checkpoint that Phase 5 already spent.

## Phase 5 — Youtube (slice 4)

The hard slice. Everything permission-, timing- and ordering-sensitive lives here.

**Taken before Phase 4**, which the dependency column permits without a single edit: T5.1 needs T2.4,
T5.2 needs T1.1, and the rest need each other. Being the hard slice is the argument for moving it
rather than against — a Paste or a grant that behaves worse than T0.5's spike promised is cheap to
find now and expensive to find last. It also lands T5.4 while T2.4 and T2.6 are still warm, and T5.4
rewrites what they built: ↩ dismisses before running today, and a spinner is a reason to stay. What
moving it spends is Checkpoint D's "nothing needs Accessibility yet", so T5.5 starts mattering to
every rebuild in Phases 4, 6 and 7 rather than only to the last of them.

**T5.1 spent its decision before its code too, and it was a word the design already used.**
`CONTEXT.md` has said since before slice 0 that a **Script** which declares an **Input** has it
**Seeded** and one that declares none never is — and nothing declared anything: `starkit.gleam`
handed every **Script** a `String` whether it wanted one or not. An **Input** stage that *appears*
cannot be decided by a return value, so the bar needed the answer before the **Script** ran, which
is what made T5.1 the task where the sentence had to become a type. **Asks** / **Decides**, as a
field on both constructors, over the cheaper `Need` variant: a **Need** is a slice of the machine
the **Shelf** gathers into a **Context**, and C8 arrives at T4.2 to read exactly that list.
Recorded as T13.

Adding a field is the one change to this type that every **Script** already written must be edited
for, so **the gap below stopped being hypothetical at T5.1** and its trigger fired exactly as
written: four of the five **Scripts** in `~/.starkit` were still byte-identical to their stubs and
were replaced wholesale, and `work.gleam` — the one with a real app list in it — took one line by
hand. So the answer is not "one `cp`" after all; it is *per file, and you have to know which*. That
is cheap at five and would not be at fifty. `~/.starkit/test/youtube_test.gleam` was stale from
before T5.2 as well and failed the build until the install vendored the current one, which is the
same lesson from the other side: the **Shelf**-owned half upgrades itself, and only the half that is
yours cannot.

**The stage is second, not always.** ↩ on a **Script** that **Asks** with nothing typed after the
**Keyword** puts its question up, **Seeded** from the clipboard and selected; ↩ again runs it. But
`youtube <url>` typed on one line still runs on the first ↩ — a question already answered is not
asked, and that path is what ↩ did before the stage existed, so the stage removes nothing. Escape is
one stage back before it is a **Dismissal**, which is what makes ↩ on the wrong **Script** cost a
keystroke instead of a re-**Summon**.

Measured over six **Summons** with the stage in place: **on screen in 9.2–15.8 ms, ready to type in
14.8–21.5 ms**, both unchanged against T2.2's numbers and inside F1 — the second stage is a chip and
a placeholder on a panel that was already built. Narrowing stayed 0.0–3.4 ms. Three full round trips
each **Seeded** with 43 characters and each decided the same correct `Paste`, which is the whole path
from clipboard to **Script** proven before C7 can perform the last step of it.

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
again for `clean` at T4.1 and `link` at T6.1. ~~**Trigger:** the first stub a person has actually
edited, where replacing it is no longer obviously safe.~~ **Fired at T5.1**, and by the harder
version of itself: not a **Script** wanting a better implementation but the **Vocabulary** gaining a
field, which every **Script** on the machine must be edited for at once. `work.gleam` was the edited
one and took a hand-written line while the other four were replaced from `seed/`. The answer is
per-file surgery and knowing which file is whose — tolerable at five **Scripts**, and the reason to
have taken the field now rather than at fifty.

**T5.3 pastes into the application the bar took the keyboard from**, end to end from ⌃⌘K: `yt`, ↩,
↩, and the note is in the editor that was in front before any of it, with the markdown still on the
clipboard for the ⌘V that repeats it. Four things it settled, none of which the spike could:

- **Where a **Paste** goes cannot be looked up when it fires.** By then the frontmost application is
  Starkit, so C7 samples it as it happens — and *pins* it when the **Shelf** becomes active, which
  the spike had no reason to do. Without the pin, an **Open** among the same run's **Effects** would
  move the target, and a **Script** that **Opens** and then **Pastes** would paste into what it just
  launched rather than into "whatever was frontmost before the **Shelf** appeared", which is what
  the **Vocabulary** promises in as many words. No **Script** does both today; the pin is where that
  sentence stays true when one does.
- **Starkit becoming active is the moment the bar appeared**, so C7 needs nothing from C1 to know
  when to pin. An `.accessory` application with one window has no other way to become active. The
  two components are joined by the fact rather than by a call, which is the cheapest form the C1/C7
  coupling `DESIGN.md` §9 records could take.
- **The hand-back is usually already done.** C1 hides on **Dismissal** and the **Script** then spends
  a build check, a `bun` spawn and a fetch, so the target is active again long before its **Effects**
  arrive and the wait costs nothing. The spike's 19.4 ms was the price of pressing ↩ and pasting in
  the same breath. The wait stays because it is the difference between an observation and an
  assumption, and T8.1 owns the number.
- **Accessibility is asked for at the first **Paste**, not at launch.** Most sessions never paste, and
  a permission dialog at login for something nobody has asked for is how an application gets denied
  on principle. A **Paste** that finds itself untrusted **Refuses** and says where to grant it, with
  the text on the clipboard either way — the grant reaches a running process (T0.5), so the fix from
  there is ↩ again rather than a relaunch. T5.5 therefore has a real first grant to check a rebuild
  against, which is what it was written to check.

It hands one thing to **T5.4**, and it is the same order this task depended on. A spinner is a reason
for the bar to stay, so C1 will no longer have hidden by the time **Effects** are performed — which
turns C7's hand-back from the second of two into the only one, and makes the wait above the thing
that is actually paid rather than the thing that is skipped. The wait is written for that already;
what T5.4 has to decide is when the bar goes, not whether the paste can find its way home.

**T5.4 answered that with: when the run has nothing left to say.** ↩ has hidden the bar since T2.4,
and it now stays with the mark turned spinner until the last **Effect** is performed — then goes on
its own if the run was silent, and stays holding one sentence if it was not. What it decided:

- **The spinner is the mark, not a new element.** A run is Starkit working and the mark is the one
  thing in the bar that is already Starkit, so the carambola chip becomes a spinner in place. A
  spinner anywhere else would be a second thing to look at, and the head would have to make room for
  it in a layout whose whole discipline is that the field does not move.
- **A **Refusal** shows in the bar as well as in the menu bar, and the deadline is what forced it.**
  F12 asks that the message survive the bar closing, which C10 answers and still does — but a run
  killed at 5 s would otherwise be a spinner that stops, a bar that vanishes, and the reason left in
  a tooltip nobody has cause to open. So both, one per question: the bar says what just happened,
  C10 says what is still wrong. Whose voice it is cannot be read off the words — "there is no
  network" from a **Script** and "killed after 5 seconds" from Starkit are the same sentence at a
  glance — so it is marked instead, with C10's own symbol, in the mark's column.
- **A run that said nothing takes the bar with it.** Watched by accident rather than by design:
  `↩ clean — 0 Effects in 79.2 ms` and the bar was gone, which is ↩ still reading as finished for
  every **Script** that has nothing to report. Only a **Notify** or a **Refusal** keeps it.
- **Escape abandons a run rather than cancelling one.** The `bun` already spawned is not something a
  keystroke can unspawn, so it runs to its own end and reaches its deadline — it simply loses the bar
  it was going to speak into. Each run carries the number of the bar it was started from, and a
  **Notify** or **Refusal** arriving for a bar that has gone is reported and dropped. Without that,
  a **Script** hung against its 5 s deadline could speak into a bar **Summoned** afterwards for
  something else.

Measured across the four paths, driven by hand with the log open. `link` **Notifies** in **238.6 ms**
cold and **74–86 ms** after, which is the spinner's whole life on a **Script** that does no work.
`spin` — a scratch **Script** that loops forever, in a scratch `STARKIT_HOME` so nothing of the
person's was touched — spun for five seconds and was killed, with the sentence landing in the bar and
the menu bar going red. Escaping the same run left the bar away and the deadline unheard. **Summons**
stayed inside F1 throughout, 4.5–14.4 ms on screen and 9.1–18.6 ms to key, with one outlier at
33.3/44.1 recorded rather than explained.

**The paste is the number that mattered**, because it is the one T5.4 could have broken: `Paste — 124
characters into Zed in 18.9 ms`, with the bar on screen for the whole run. C7 asks another
application to come forward while Starkit is active and holding a key panel, which no earlier task
had ever done — a `previous.activate()` macOS declined would have put the note in the bar's own text
field. It did not, so the hand-back is C7's alone and does not lean on a **Dismissal** having
happened first (`DESIGN.md` §9).

Two things worth having watched, neither of them asked for. **The Accessibility **Refusal** arrived
in the bar unprompted** — the test rig runs the executable directly rather than the bundle, so TCC
treated it as a different process and asked again — and being able to read *"System Settings →
Privacy & Security → Accessibility"* on screen and press ↩ again, with no relaunch, is the argument
for **Refusals** in the bar arriving before anyone made it. **T5.5 is untouched by that**: a grant
re-asked because a raw executable was launched from a shell says nothing about whether the grant
survives a rebuild, which is what that task has to check against a bundle.

Two costs, both taken deliberately. The field is **locked while a run is in flight** — narrowing
under a spinner would be the bar answering a question nobody asked — and a locked field beeps at a
keystroke, which is macOS saying "not now" in the only voice it has. And a second ↩ during a run is
ignored rather than queued, because there is one spinner and one line for a message, and a bar that
can hold two runs would need to be able to show two.

**T5.5 had to be made into a test before it could be run.** "Rebuild, reinstall, paste still works
with no new prompt" passes trivially, because **a rebuild of unchanged source is byte-identical** —
`CDHash=f23cc16b…` before and after `build.sh`, Swift's build being reproducible here. A grant keyed
to the code hash would have survived that too, so the criterion as written was checking nothing. The
test needs a bundle that genuinely differs, and `install.sh debug` is one that costs no invented
edit: the same source and the same certificate through a documented path of the script.

Run that way it is the real thing, and it held. `CDHash` moved `f23cc16b…` → `00c46078…`, the bundle
at `/Applications` was deleted and re-`ditto`'d rather than copied over, and **no dialog appeared**:
`Paste — 124 characters into Zed in 14.5 ms`. The mechanism is visible rather than inferred —

```
designated => identifier "dev.apoena.starkit" and certificate leaf = H"e2c66dd6…"
```

— and what it *omits* is the whole of T0.2's argument arriving four slices later. No code hash and no
path, so the two things every install changes are both outside what TCC matches on. The fragile term
is the leaf: a second certificate would end the grant, which is why `setup-signing.sh` refuses to
regenerate one that exists, and why `build.sh`'s ad-hoc fallback prints a warning rather than
signing quietly. Neither was written for this task; both are what it was checking.

**The false alarm at T5.4 is worth keeping**, because it will happen again. Running
`/Applications/Starkit.app/Contents/MacOS/Starkit` from a shell re-prompted for Accessibility on a
machine that had already granted it: TCC attributes to the *responsible* process, and a binary
launched from a terminal is the terminal's responsibility rather than its own. So a rig that runs the
executable directly is not testing the installed application, which is why this task was run through
`open` with the parent process checked (PID 1) before anything was concluded. The same fact bounds
the debug CLI permanently: `Starkit run youtube <url>` from a terminal can only ever paste if the
*terminal* holds the grant, and that is a property of the path rather than a bug in it.

One measurement fell out of the debug bundle, and it is for T8.1 rather than for here: **25.7 ms on
screen and 36.4 ms to key**, against release's 10.8 and 16.4 in the same session. Inside F1 either
way, and the reason F1's numbers are quoted from release builds.

**Checkpoint E — reached.** 4 of 5 **Scripts**, and the only permission-gated path in the system
works and stays working across a rebuild, a re-signing and a delete-and-reinstall of the bundle.

## Phase 6 — Link from url (slice 5)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T6.1 | `link` **Script** + tests, including pages where the `h1` scan is wrong | T5.3 | `gleam test`; a real URL pastes `[Title](url)` with quotes and dashes normalised |
| T6.2 | Non-`https` **Input** → **Notify** | T6.1 | typing a non-URL produces a **Notify** and no paste |

The known-wrong pages are recorded as the limit of a scan standing in for a DOM selector, not
fixed. Fixing them means an HTML parser, which is a **Vocabulary** decision (`Ask first`).

**T6.1 spent two decisions the earlier slices left it, and neither was the one the table names.**

The first was `normalise`. T5.2 wrote it into `youtube.gleam` with a comment saying the decision
belonged to the second caller rather than the first, and `link` is that caller — SPEC asks for
quotes and dashes normalised there in the same words. It moved to `seed/src/text.gleam`, vendored
and overwritten on install exactly like `starkit.gleam` and deliberately not part of it: that module
is the interface between a **Script** and the **Shelf**, and `normalise` crosses no boundary and
touches no machine. The alternative was a copy in each **Script**, which keeps isolation total and
puts two versions of a mapping whose entire purpose is that every note agrees — an em dash becoming
two hyphens in one file and one hyphen in the other is the exact split it exists to prevent, and
nothing would have caught it. What it costs is the isolation itself, and that is a real loss:
T1.6's property was that a **Script** which does not compile takes only itself down, and every
**Script** importing `text.gleam` now shares its fate. Affordable for a module nobody edits and the
installer replaces wholesale; recorded as T14 so the next shared module has to argue for itself.

The second was the regexp, which SPEC, this plan and `todo.md` all named three times. Gleam's
stdlib has none, so the word was a sixth dependency resolved on every install in exchange for three
calls to `string.split_once` — and the pages that come out wrong are identical either way, because
the limit is *not a DOM parser* rather than *not a regexp*. Scanned instead, the same technique
`youtube` already uses to read six URL shapes, and the docs corrected to say so.

**The suite is 26 cases and two thirds of it is the limit.** Sixteen say what a browser would say —
tags inside the heading dropped and their text kept, whitespace collapsed, six entities decoded, and
`&amp;` decoded last because doing it first turns `&amp;lt;` into a literal `<` and quietly makes
markup out of a page's escaped text. Six assert the wrong answer on purpose: the first `h1` wins
even when the masthead got there first, a heading left in an HTML comment is read as the title, an
`h1` inside a script template is read as the title, an uppercase `<H1>` is not seen at all, and a
`>` inside an attribute value ends the tag early. A test there starting to fail means the scan
changed and the change had better be deliberate.

**Verified against the real web** through `--dry-run`, which is the debug path answering "what did
this **Script** decide" without a **Paste** touching anything. `gleam.run` and `example.com` come
back as `[Title](url)`; a 404 is a **Notify** naming it; text that is not a URL is a **Notify**
saying so. Two real pages are worth keeping. MDN's `h1` is
`<code>&lt;h1&gt;–&lt;h6&gt;</code> HTML section heading elements` and pastes as
`[<h1>-<h6> HTML section heading elements](…)` — the tag stripped, the entities decoded, the en dash
normalised, which is the whole pipeline proved on one page nobody wrote a fixture for. And
`blog.rust-lang.org` serves no `h1` at all, so a real, current, popular page lands on the
**Notify** — the known limit is not hypothetical, and the one place it will be felt is a site that
renders its heading in the browser rather than in the response.

`http://example.com` still pastes, which is T6.2's job and not a gap here.

**T6.2 is a refusal with a reason, and the reason is worth writing down.** This **Script**'s entire
output is a page's own heading, written into a note verbatim and trusted from then on; over
cleartext that heading is whatever anything between you and the server decided it should be, and
nothing downstream can tell the difference, because nobody re-reads a note against its source. So
the check has to be here or nowhere.

Where there is a scheme it is named back — `http`, `ftp`, `file` each get a sentence saying what
they are, since "no" without the reason is a bar you argue with. Where there is none, the message
names the fix instead, because a bare `example.com` is the common case and the answer is almost
always the missing `https://`. That branch is also what catches `data:` and `javascript:`, which
have no `://` at all: refused, and by the message that reads oddly for them and correctly for the
hundred bare hosts. Measured through `--dry-run` across all eight shapes.

Two details are deliberate. `HTTPS://example.com` is fetched, because schemes are case-insensitive,
and it pastes with its uppercase scheme intact — a URL is not tidied on its way into a note, and
what was copied is what gets written down. And a scheme has to be *spelled* like one, so
`hello world://x` has none rather than one named after the sentence, which is a refusal quoting the
wrong problem back.

**Slice 5 lands the fifth Script, and the MVP's Script set is complete.** What is left is Phase 7's
boot and Phase 8's numbers — no new **Vocabulary**, no new permission, nothing a **Script** has not
already done.

## Phase 7 — Boot (slice 7)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T7.1 | C9 LoginItem — `SMAppService`, lifted from `cmd-tab`; menu toggle reflects reported state | T0.4 | reboot: menu bar item present, ⌃⌘K works within 3 s |
| T7.2 | Bundle moved out of `/Applications` and back does not silently unregister | T7.1 | the menu shows what `SMAppService` reports, never a cached assumption |

**C9 was lifted from `cmd-tab` and then lost its `isEnabled: Bool`.** What the copy answered was
"are we registered", cached in whatever asked it; what T7.2 needs answered is "what does macOS say
*now*", and the difference is a menu item. So the menu is built when it opens and at no other time
— not as a saving, but because building it on a state change would show whatever was true at the
last **Refusal**. One status read costs **1.3–1.7 ms**, on the one path in this system with no
budget on it: a person's hand is on the mouse.

The four states macOS reports are four different sentences and three different repairs. Registered
and on is a tick; never registered, or turned off from here, is the same line without one; a
registration macOS cannot find a bundle for says so and re-registers when clicked. The fourth,
`requiresApproval`, is macOS holding the registration and waiting on a person — clicking it opens
System Settings, because registering again is not what it is waiting for. **That branch is the one
thing here written and not exercised**: producing it means turning the switch off in System
Settings, and the state this machine was left in is on.

**`SMAppService` answers about a bundle, not a path**, which is most of T7.2 before the experiment
is run. The `swift build` binary reports `notFound` and cannot register at all — it is not an app —
so `install.sh` asks the *installed* copy, never `build/`'s. And `Starkit login [on|off]` exists for
that call: the registration belongs to the bundle the executable sits in, so it cannot be done by
the running instance from the outside, and a `login` that prints the state macOS reports afterwards
is also how T7.2 is checked without a person squinting at a tick.

**T7.2, measured against `sfltool dumpbtm`** rather than against our own report, since the question
is whether the report is honest. Moved to `/tmp`, the record follows the bundle — the URL is the new
one, the generation counts up, the disposition stays `enabled`, and the status still reads on. Moved
back, it follows again. Deleted outright and restored by `ditto`, which is what every `install.sh`
does, the record does not move at all: same URL, same generation, still enabled. So a reinstall
never loses the registration, and the `login on` in `install.sh` is the first install's job and a
no-op afterwards. `unregister()` leaves the record and flips the disposition to `disabled`, which is
reported as `notRegistered` and shown as an unticked line.

Then the same thing through the running app: turned **off from a terminal behind its back**, the
menu came up unticked; clicking that line turned it back on and the terminal agreed. Read out of the
menu itself over the Accessibility API, which is the only way to see what a menu bar item actually
says.

**What is not measured here is the reboot.** From an empty environment — `env -i`, which is the
nearest thing to what launchd hands a login item — ⌃⌘K is live at **82 ms** and all five **Scripts**
are listed at **734 ms**, against F9's 3 s. That is the budget answered; it is not the criterion,
which is a machine restarting and the item being there. Owed.

## Phase 8 — Close the budget

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T8.1 | `--bench` flag; measure every row of [DESIGN.md](../DESIGN.md) §8 and record actuals | T7.1 | all 7 budget rows carry a measured number, not a target |
| T8.2 | Idle cost measurement for G4 | T7.1 | idle RSS and idle CPU recorded in `DESIGN.md` §3, next to Script Kit's |

T8.2 fills the one blank in the competitive assessment: Script Kit's idle RSS was never measured
because it wasn't running. Starkit's should not be a blank too.

**Four of the seven rows are the flag's; three were never going to be.** `--bench` repeats what a
process can repeat — F4, F5, F6, and the resolve and `describe` that F9's launch is mostly made of —
and it performs no **Effects**, because twenty iterations of `work` would otherwise open eighty
applications. F1 starts at a keypress and C1 already prints itself on every **Summon**, so its numbers
come from the slices that pressed the key; asking for ⌃⌘K from a CLI would have succeeded and proved
nothing, since Carbon does not arbitrate (T2.1). F8 is not a duration. F9's whole number is a launch.

**F14 came free, which is the argument for putting the flag on the debug CLI rather than in a
harness.** A **Script** that hangs is `spin`, three lines of Gleam in a scratch `STARKIT_HOME`, and
`--bench=3` against it reports 5004–5007 ms with the **Refusal** naming the deadline. The 4–7 ms of
overshoot is the semaphore wait before `SIGKILL`, and it is the same number three times, so the
deadline is a deadline rather than a hope.

**Numbers are ranges because one run's median is not a fact.** Five runs of 20 samples, and F5's median
moved between 27.2 and 29.3 ms depending on what else the machine was doing; F6's *cold* read moved
from 4.2 to 5.7 ms, which crosses its own 5 ms budget. So what is recorded in §8 is the spread of
medians rather than whichever run read best. F6's overrun needs nothing done: `warm()` at launch pays
that read where nobody is waiting, and this is the measurement that makes it load-bearing rather than
tidy.

**F5 has drifted ~5 ms since T1.4, and it is not the spawn.** 27–29 ms against 22.7 for the same cold
`bun`, so the difference was hunted rather than assumed: `registry.gleam` imports every **Script**
statically, `youtube` and `link` import `gleam_fetch` and `gleam_http`, and therefore `work` loads the
whole HTTP stack in order to open four applications. Confirmed by taking those two out of a scratch
registry — F5 falls to 23.1 ms, `describe` from 26.4 to 22.7 — which makes ~4.7 ms of every run
modules the run cannot use, growing with each **Script** that fetches. **Not fixed here.** A lazy
import per **Keyword** moves the **Keyword**-to-module mapping out of Gleam and into the vendored
shim, which is a C4 decision and not a measurement.

**Two parked numbers settled and one target withdrawn.** The `starkit.toml` override does not reduce
C12's cost, it removes it: resolve goes from 324–354 ms to **0.063 ms**, since the spawn is skipped
when nothing is left to ask about. **F7's "≤ 10 ms otherwise" is gone** — it had contradicted T1.5's
~35 ms warm **Open** since T1.5, and the target was the wrong half, because an **Open** returns when
LaunchServices has the launch under way and a budget over something Starkit does not control can be
neither met nor missed. What is left of F7 is order and the **Kill** guarantee, neither a duration.
The third, the **Paste** hand-back wait, needed no new measurement: T0.5's 23.1 ms with 19.4 of it
waiting and T5.4's 18.9 ms total are the same wait with the hand-back already done, which is what that
note predicted.

**T8.2 is a zero, and the zero is the point.** 0.47 s of CPU across a 22-minute life, none of it in a
300 s window — below what `ps` resolves — because after launch nothing runs until the chord arrives.
Memory is two figures on purpose: 86 MB resident, most of it AppKit pages shared with every
application on the machine, and 21 MB phys footprint, which is the part that is Starkit's alone. G4 is
about the second. Script Kit's side stays blank deliberately: measuring it means launching it, and its
event tap would take ⌃⌘K away from the system being compared.

## Phase 9 — Authoring (slice 6, taken after MVP)

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T9.1 | The registry rule moves into Swift — pure + tested, `Starkit registry`, `gen-registry.sh` retired | T0.3 | the ported rule's output diffs against the shell script's on the same directory; `gleam format --check` passes on what it writes |
| T9.2 | C6 Watcher — `FSEvents` on `src/` → regenerate, build, rewrite **Manifests**, set menu bar state | T9.1 | saving in Zed makes a new **Keyword** work at the next **Summon** with nothing else run, inside F10's 500 ms; a save that does not compile goes red and the other **Scripts** keep working |
| T9.3 | C11 Scaffolder — `Create "<keyword>"`, template, open in Zed | T9.2 | ↩ on a typo does nothing at all; choosing it writes a compiling `pub fn script()` and Zed opens it |

**The registry had two implementations the moment C6 was specified, and only one could stay.**
`gen-registry.sh` lives in this repo; the Watcher runs inside an installed bundle that has no repo
beside it, so C6 could not have called it. Both writing the same file is the worse half of the problem:
the output has to be byte-identical or `registry.gleam`'s mtime moves, and moving it marks **every**
**Script** **Stale**, because it is one of C5's shared modules. Two implementations of a rule whose
failure mode is silent is not a duplication worth keeping, so the rule moved to `StarkitCore` where it
is tested without a filesystem, the filesystem half went to C6, and the script is gone. `install.sh`
now asks the *installed bundle* for the registry — `Starkit registry`, the same verb a person can run —
because a fresh `~/.starkit` has no registry at all and `gleam build` would fail on the missing module.

**The port was diffed rather than reasoned about.** Both versions were run against the same scratch
`src/scripts/`, including a `link_check`/`linkedin` pair to exercise the ordering, and the output
differs in exactly the two header lines that were changed on purpose — the file no longer names a
script that does not exist. `gleam format --check` passes on what it writes, for five **Scripts** and
for none, which turns "already format-clean" from a claim in a comment into something checked: a file
Gleam would reformat is a file something else rewrites later, and that is the mtime again.

**A home with no Scripts still compiles**, checked by building one. `[]` on its own does not typecheck
— Gleam cannot infer an empty list's element type, and the annotation only goes on a binding — so the
generated module binds `let scripts: List(starkit.Script) = []`. Deleting your last **Script** should
leave a bar with nothing in it, not a menu bar going red about a home that is merely empty.

**A launch and a save now run one sequence, not two.** C6 could have owned regenerate-build-describe
itself, and then the order — the registry *before* the build, since the build compiles what the registry
imports — would have existed in two places with the second one failing silently. So the sequence is one
`nonisolated` function both callers run: the main actor calls it directly at launch, where the chord and
the bar are already up, and the stream's queue calls it on a save. What the delegate keeps is the half
that must happen on the main actor — hand the list to the bar, set the menu bar — and the **Refusal**
path leaves the previous list where it was, which is F2 and F10 turning out to be one mechanism seen
from two sides.

**FSEvents' latency window cost more than the budget it was meant to protect.** Set to 100 ms it
delivered the first event of a quiet period up to **509 ms** late, so F10's whole 500 ms was gone before
Starkit had been told anything — and `kFSEventStreamCreateFlagNoDefer` is documented to prevent exactly
that. Asking for a zero window fixed the latency and broke the coalescing instead: an editor save is
several events, because Zed writes a sibling temporary and renames it, and that measured as **two
rebuilds**, the second compiling bytes the first had already compiled. So the window is 0 and the
coalescing is a 50 ms timer of our own, which is a number that can be reasoned about rather than a hint
the framework is free to interpret. **201–238 ms save to rebuilt** after that, across six saves and three
restarts, of which 73–87 ms is Starkit's work; two outliers at 594 and 628 ms were recorded under load,
and in both the excess was delivery and not work.

**Writing the registry is a change inside the watched tree**, so adding a **Script** costs one extra
pass. Left to converge rather than filtered by path: the second pass finds the file already correct and
writes nothing, whereas a filter would have to name an editor's temporary files, which is guessing.

**The verifications were run by moving files, not by using Zed** — a sixth **Script** copied in was
listed 143 ms later with nothing else run, a broken save reached the menu bar in 169 ms with the other
five still running from the last good build, and fixing it brought it back. The temp-and-rename shape
Zed actually uses was simulated directly, because that shape is what produced the double rebuild.

**T8.2's open row is closed.** Idle CPU did not move across 60 s with the stream running, and neither
did RSS. The subscription costs nothing because it is a subscription; the poll that would have shown up
there is not in this design.

**"Never the default selection" turned out to be a type.** The bar's selection is `Int?` now: with no
match there is nothing selected, ↩ has nothing to act on, and the offer is reached by a deliberate ↓.
Written as a guard against index zero it would have been a rule to remember in three places — `accept`,
`move`, `narrow` — and the failure would have been silent and fast, because it makes misspelling a
**Keyword** the quickest way to write a file. ↑ from nothing selected does nothing either: the offer is
below the field, and reaching it by pressing *up* is the same accident wearing another key.

**A row became a case rather than a **Manifest** with a flag.** `.script(Manifest)` or
`.create(String)` — because a **Manifest** describes a **Script** that exists, and the bug worth making
unwriteable is a made-up one reaching `run`. That change found a real one on the way in: `ask` emptied
`matches` but the panel's height now comes from `choices`, so the **Input** stage would have kept the
list's height under a question with no list in it. Pre-existing in shape and newly reachable in
practice, since C6 makes the **Catalogue** change while the bar is open.

**C11 writes one file and stops.** No build, no registry, nothing handed to the bar — C6 is watching, so
the file appearing *is* the **Script** appearing. That is what makes F11's "0 registry edits" true, and
what makes the bar's flow and writing the same file in Zed the same event, which SPEC asks for. It also
**never overwrites**: a file can exist while its **Keyword** matches nothing, because a **Script** that
has never compiled is missing from `manifests.json` and therefore from the list, so the existing file is
opened instead — almost certainly the one that would not compile.

**The template was checked by letting C6 build it**, with the exact bytes `Scaffold` emits rather than a
retyped copy: listed 174 ms later and it runs. `gleam format --check` passes on it too — the first
attempt appeared to fail, and the extra newline was in the extraction rather than the template, which is
the sort of thing that becomes a wrong fix if the check is trusted over the reading. The offer is
**withheld rather than repaired** for anything Gleam would not take as a module name: `My Notes` is not
offered, because quietly writing `my_notes` is a **Keyword** nobody can find again.

**Verified once more against the installed app**, because every number above came from a scratch home:
a file appearing in the real `~/.starkit` was listed **360 ms** later and removing it took it back out,
with the registry returning to five imports. Slower than the scratch home's 201–238 ms over a larger
tree, and 72 % of F10's budget — the row to watch as **Scripts** accumulate.

**It crashed on the first ↩, and the reason it reached anyone is the interesting part.**
`Data.write(to:options:)` was given `[.atomic, .withoutOverwriting]`, and Foundation traps on that
combination unconditionally — *"withoutOverwriting is not supported with atomic"*, a `fatalError` rather
than a thrown error, so the `do/catch` around it was decoration and **every** press of that row killed
the app on the main thread. Of the two options, `.withoutOverwriting` is the one that was kept:
clobbering a **Script** someone wrote is the only outcome here that loses work, while a half-written
*new* file announces itself by not compiling within 200 ms.

**The verb `Starkit create <keyword>` is the actual fix.** Every other component is reachable from the
debug CLI — that is what it is for, and it is why C5, C4, C7 and C8 were all exercised before they were
ever pressed. C11 was reachable only through a keystroke in the bar, so its one filesystem call was
never run, and no test could have caught it either: the write is in the app module, and a mock of
`Data.write` would have passed while the app trapped. A path that cannot be run without a keypress is a
path that does not get run.

**Now exercised end to end**: `create` writes the template, a second `create` over an edited file leaves
the edit alone, an invalid **Keyword** is refused with the reason, and with C6 running the new **Script**
is listed 238 ms later and runs.

**What is still not verified by running: the three bar interactions.** The offer appearing for a
**Keyword** that matches nothing, ↩ on it doing nothing, and ↓ then ↩ reaching it. Those are selection
behaviour rather than filesystem behaviour, they need a keypress, and SPEC already puts C1 under "not
tested — verified by running it".

## Phase 10 — Taking a Script away

| ID | Task | Depends | Verify with |
| -- | ---- | ------- | ----------- |
| T9.4 | F16 — ⌃D twice on a selected **Script** moves it to the Trash; `Starkit delete <keyword>` | T9.3 | the **Keyword** leaves the list with nothing else run, the build stays clean, and both files are recoverable |
| T9.6 | F17 — ⌥↩ opens the selected **Script** in Zed; `Starkit edit <keyword>` | T9.3 | one keystroke from the bar to the editor, and a **Refusal** when there is no file |
| T9.7 | F18 — a **Script** declares `other_keywords`, and the bar matches them | T2.3 | `yt` finds `youtube`, and a **Keyword** typed in full is never pushed below a shorthand |
| T9.5 | `login` → `start-at-login` | T7.1 | `install.sh` and the menu agree on one name for one thing |

**Asked for as "a way to delete a Script from the home row", and the home row is the hard part.** Every
candidate is already a text-editing binding — ⌃H is `deleteBackward:`, ⌃K is `deleteToEndOfParagraph:`,
⌃D is `deleteForward:` — so there is no free key, only a choice about which one to spend. ⌃D was chosen
knowing it stops deleting a character in the **Keyword** field, and the **Input** stage hands it back,
because there the field holds an answer rather than a **Keyword**. It arrives as the selector Cocoa
names for the key, so T2.5's rule survives: still no keycodes anywhere in the bar.

**The friction is a question in the list's place, not a label on the row.** The first version dimmed the
row and wrote *⌃D again to Trash it* into it — then the confirm moved into the message view, which is
where it belongs, because the list and a message are already exclusive (`under`) and a warning that
shares the screen with eight other rows is a warning that gets skipped. The row rendering was removed
rather than left: `message != nil` hides the list, so it was a state that could not be reached.

**The armed **Keyword** is held, never the row index.** Narrowing, moving the selection and a new
**Catalogue** from C6 all disarm, and the second press has to find the same **Script** under the cursor.
Deleting the wrong file is the only mistake here that pressing something else cannot undo, so the state
is written to be lost easily rather than held onto.

**A **Script**'s test is part of the **Script**, and deleting one proved it.** `gleam build` typechecks
`test/`, so trashing `youtube.gleam` while `youtube_test.gleam` still imported it broke the whole
project 200 ms later: the menu bar went red, and the other four **Scripts** kept working only because
ADR 0002's isolation was already there. Both files move now, both are named in the question, and both
are recoverable. A suite under another name still breaks the build, and that surfaces as Gleam naming
the missing module — which is the failure this cannot prevent without reading every import.

**The Trash rather than `unlink`**, because `~/.starkit` is not a repository and a **Script** may have
existed only there. It also puts the undo somewhere a person already knows to look, which no message in
a bar can do.

**"A shortcut like yt for youtube" was a **Vocabulary** change, and the glossary said no.**
`CONTEXT.md` bans the word "alias" outright and asserted *exactly one **Keyword** per **Script***, which
is the thing being asked for. Reversing that ban was the obvious move and the wrong one: by the
glossary's own definition — "a space-free word that selects a **Script**" — a shorthand typed into the
same field *is* a **Keyword**, so what was wrong was the **cardinality**, not the vocabulary. The
invariant moved to "exactly one *canonical* **Keyword**, which is its module name, and any number more";
the ban holds, because it was written to stop a **Keyword** being called something else rather than to
forbid a second one; and the field is `other_keywords`, in the **Vocabulary**'s own word. It was named
`aliases` for about twenty minutes first, which is exactly the drift `CONTEXT.md` exists to catch.

**Matching is four bands, and the ordering is the whole feature.** Canonical **Keyword** exactly, another
exactly, canonical by prefix, another by prefix — because two letters is the fastest thing to type here,
and without an ordering `yt` would sit behind any **Script** whose name merely begins with those letters.
A **Keyword** typed in full still wins outright, so no name added later can shadow one that already
worked. A **Script** is ranked once however many of its names match, which is what keeps one **Script**
from being listed twice.

**The cost was a breaking constructor change, for the second time in this design.** T5.1 spent it on
`asks` and recorded it as "the one upgrade this design cannot migrate for you" — Gleam has no default
field values, so every **Script** gains a line or nothing compiles, and `install.sh` is forbidden from
touching `src/scripts/`. It is also the only place the declaration could live: `SPEC.md` forbids
per-**Script** configuration outside its **Manifest**, which rules out a config file, and `starkit.toml`
belongs to the **Toolchain**. The five **Scripts** on this machine were migrated by hand with the diff
shown — one line each, nothing else touched — and the wire name is pinned by a test, because a Swift
property renamed without its `CodingKey` would decode to none and `yt` would quietly stop finding
anything.

**F17 was the cheapest key in the bar.** ⌥↩ *and* ⌃O both arrive as
`insertNewlineIgnoringFieldEditor:`, which is the same free pair T2.5 found when ⌃N and ⌃P turned out to
be `moveDown:` and `moveUp:` — and unlike ⌃D, taking it costs nothing, because inserting a newline
*ignoring the field editor* has no meaning in a field that holds one line. Read out of macOS's
`StandardKeyBinding.dict` rather than guessed at, which is also how it turned out that ⌘↩ is not in
there at all: Command chords are not text bindings, so a ⌘↩ version would have needed the keycodes
T2.5 spent a slice avoiding.

**`login` became `start-at-login`** on the same reading: `Starkit login on` is a sentence about an
account, and Starkit has no account. The menu item has said **Start at Login** since T7.1, so the verb
now says it too — one thing, one name, which is the whole argument of `CONTEXT.md` applied to a CLI.

## Deferred

Nothing. Slice 6 is built, and F16 was added on top of it.

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
