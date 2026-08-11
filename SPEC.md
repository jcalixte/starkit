# Starkit — Specification

What to build, in what order, and how to know each part works. The vocabulary is in
[CONTEXT.md](./CONTEXT.md); the goals, measured targets and trade-offs are in
[DESIGN.md](./DESIGN.md). Neither is repeated here — this document is the build order and the
acceptance criteria.

MVP is slices 0–5 plus 7 — the five existing **Scripts**, working from the bar, starting at login.

Slice 6 is outside MVP only because those five are seeded at install and need no authoring flow to
exist. It is not comfortably deferrable beyond that: **Scripts** are always written in Zed, and the
Watcher is the only thing that makes a new one visible, so until slice 6 lands every new **Script**
costs a manual `scripts/gen-registry.sh`. Expect to want it the day you write a sixth.

## Objective

Replace the five Script Kit scripts actually in use with a menu-bar app that compiles and runs
Gleam. Success is the whole of Script Kit's ~1.86 GB and 356 injected globals being replaced by
~4 MB and 10 names, without any of the five workflows getting slower or less reliable.

One user. No preferences window, no themes, no per-**Script** configuration beyond its **Manifest**.

## Commands

| Command | Does |
| ------- | ---- |
| `./scripts/setup-signing.sh` | Creates the self-signed certificate, once per machine. Run before anything else — Accessibility grants are bound to the signature, and an ad-hoc signature changes on every build. Asks for the login keychain password once, so that signing never waits on a dialog afterwards. |
| `./scripts/build.sh [debug\|release]` | Compiles and assembles `build/Starkit.app`. |
| `./scripts/install.sh` | Builds, copies to `/Applications`, seeds `$STARKIT_HOME` (default `~/.starkit`) without clobbering edited **Scripts**, runs the first `gleam build`, launches. A **Script** that does not compile still installs and launches — it reports the error and exits non-zero, because a menu bar app **Refusing** one **Script** beats no app at all. |
| `./scripts/gen-registry.sh` | Regenerates `$STARKIT_HOME/src/registry.gleam` (default `~/.starkit`) from `src/scripts/*.gleam`. Output is sorted and already `gleam format`-clean, and the file is left untouched when unchanged — so the mtime only moves when the contents do. Graduates into the Watcher in slice 6. |
| `Starkit run <keyword> [input]` | Runs one **Script** from a terminal, printing its **Effects** instead of performing them with `--dry-run`. The debugging path; kept permanently. |
| `swift test` | The two pure Swift test suites. |
| `cd ~/.starkit && gleam test` | The **Script** test suites. |

## Project structure

```
starkit/                          # this repo — the Shelf, plus what it seeds
├── Package.swift                 # SwiftPM executable, no Xcode project
├── Resources/Info.plist          # LSUIElement: true — menu bar, no Dock icon
├── scripts/                      # the four commands above
├── seed/                         # vendored into ~/.starkit by install.sh
│   ├── gleam.toml                #   Shelf-owned — always overwritten
│   ├── run.mjs                   #   Shelf-owned — always overwritten
│   ├── src/starkit.gleam         #   Shelf-owned — always overwritten
│   ├── src/entry.gleam           #   Shelf-owned — always overwritten
│   ├── src/scripts/*.gleam       #   yours — seeded once, never overwritten
│   └── test/starkit_test.gleam   #   Shelf-owned — the gleeunit runner; your suites sit beside it
├── Sources/Starkit/
│   ├── main.swift                # GUI, or `run <keyword>` when given arguments
│   ├── AppDelegate.swift         # wiring
│   ├── HotKey.swift              # C3  RegisterEventHotKey
│   ├── SummonPanel.swift         # C1  the NSPanel, built once at launch
│   ├── Bar.swift                 # C1  the SwiftUI view and its key handling
│   ├── Catalogue.swift           # C2  manifests.json, Keyword resolution
│   ├── Keyword.swift             # C2  parsing — pure, tested
│   ├── Runner.swift              # C4  spawn bun per run, 5 s deadline, Effect decoding
│   ├── Effect.swift              # C4  the Effect vocabulary, Swift side — decoded off the wire
│   ├── Refusal.swift             #     Starkit declining, in its own voice
│   ├── Builder.swift             # C5  gleam build, hashing what it built
│   ├── Staleness.swift           # C5  the Stale rule — pure, tested
│   ├── Effector.swift            # C7  Open / Kill / Paste / Notify
│   ├── ContextGatherer.swift     # C8  Running Apps
│   ├── LoginItem.swift           # C9  SMAppService — lift from cmd-tab verbatim
│   ├── MenuBarStatus.swift       # C10 normal / red
│   ├── Toolchain.swift           # C12 login-shell resolution
│   ├── Watcher.swift             # C6  slice 6
│   └── Scaffolder.swift          # C11 slice 6
└── Tests/StarkitTests/
    ├── StalenessTests.swift
    └── KeywordTests.swift
```

```
~/.starkit/                       # your Scripts, plus the vendored Shelf side
├── gleam.toml                    # name = "starkit", target = "javascript"
├── starkit.toml                  # optional Toolchain override; absent by default
├── run.mjs                       # the shim the Shelf executes — see below
├── manifests.json                # generated after each successful build
├── built.json                    # what that build compiled, by hash — ADR 0002's isolation record
├── src/
│   ├── starkit.gleam             # the vendored Vocabulary — `import starkit`
│   ├── entry.gleam               # answers `describe` and `run <name>`
│   ├── registry.gleam            # generated from src/scripts/
│   └── scripts/{work,personal,clean,youtube,link}.gleam
└── build/                        # Gleam's, measured at 2.4 MB
```

Only `src/scripts/` is yours; everything else is vendored from `seed/` and replaced on every
install, so the **Vocabulary** can be upgraded without asking you to merge it by hand.

The **Shelf** runs `bun run.mjs`, never `gleam run`. Gleam's `entry.mjs` exports `main` without
calling it, and the file that does the calling is named `gleam@@private_main_v<version>.mjs` — it is
private and it is renamed by every Gleam upgrade, which G7 rules out depending on. `run.mjs` is
ours, so the only assumption left is that `entry.mjs` exports a function, and it fails at import
rather than silently. This is also why `entry.gleam` need not match the package name: nothing
resolves it as a package entry point.

`src/starkit.gleam` is the **Vocabulary**, not the entry point, so a **Script** reads
`import starkit.{type Effect, Open, Paste}`. The entry point is `entry.gleam`, which the **Shelf**
invokes as a built `.mjs` directly — so its module name is free and need not match the package.

## Code style

Match `cmd-tab`, which is the house style for this kind of app:

- SwiftPM executable, `swiftLanguageMode(.v5)`, no Xcode project, no third-party dependencies.
- Doc comments explain **why**, not what. `cmd-tab`'s `Config.swift` is the reference: every
  non-obvious default carries the reasoning that produced it. Comments that restate the code are
  worse than none.
- One component per file, named after the component in [DESIGN.md](./DESIGN.md) §7.
- The **Vocabulary** appears verbatim in type and function names. A `Script`, an `Effect`, a
  `Keyword`. If code needs a word that `CONTEXT.md` does not define, either the word is wrong or
  the glossary is incomplete — resolve it, don't invent a synonym locally.
- Gleam: standard `gleam format`. **Scripts** contain no `@external` — zero FFI is a measured
  property of the design (G5), not an aspiration.

## Testing strategy

Concentrated where a bug is silent or irreversible, absent everywhere else. `cmd-tab` ships 1342
lines with no tests and that is the right call for framework-facing code; the difference here is
that this design made the risky decisions pure.

**Tested — Gleam, via `gleeunit`:**

- `clean` — which apps it **Kills**, given a **Running Apps** list. The only destructive path in
  the system, and **Kill** never asks. Written before Clean runs for real, not after.
- `youtube` — ID extraction across all six URL shapes, plus a bare 11-character ID.
- `link` — `h1` extraction, including the pages where the regex standing in for a DOM selector
  gives the wrong answer. Those cases are recorded as the known limit, not fixed.

**Tested — Swift, via `swift test`:**

- `Staleness` — source changed since the last successful build, source unchanged, a shared module
  changed, **Artefact** missing entirely. Plus the case that caught the mtime version out at T1.4: a
  source *touched* but not changed is **Current**.
- `Keyword` — first token splits from **Input**; no match; a **Keyword** that is a prefix of
  another.

**Not tested:** HotKey, Effector, SummonPanel, Watcher, LoginItem, ContextGatherer. Each is a thin
call into a framework, and a mock would pass while the app was broken. Verified by running it.

**Not tested — measured:** every target in [DESIGN.md](./DESIGN.md) §8, by hand, against a
`--bench` flag on the debug CLI. Latency assertions in CI would be flaky and would not be trusted.

## Boundaries

**Always**

- Perform every **Effect** in the **Shelf**. A **Script** that needs a new capability gets a new
  **Effect**, never an escape hatch.
- Keep the **Vocabulary** in `CONTEXT.md` current in the same change that adds to it.
- Refuse a **Stale** **Script** and say which one and why. Never run source you cannot compile.
- Report a **Toolchain** or build failure in the menu bar the moment it is known, not at
  **Summon** time.

**Ask first**

- Adding a word to the **Effect** or **Context** vocabulary. It is a design decision (G6), and
  two **Scripts** wanting the same one is coincidence; three is a signal.
- Anything requiring a permission beyond Accessibility. One grant is a property worth keeping.
- Adding a dependency to `gleam.toml`, or any Swift dependency at all.
- Turning on notarization or Homebrew distribution — that decides whether the repo goes public.
  **Scripts** live in `~/.starkit`, not here, so this repo carries no personal app lists; keep it
  that way. Anything naming an employer, a client or a private hostname belongs in a **Script**,
  which is never committed to this repo.

**Never**

- Ship a preferences window, a theme, or per-**Script** configuration outside its **Manifest**.
- Add `@external` to a **Script**.
- Let a **Script** run another **Script**, or outlive the 5 s deadline.
- Overwrite a **Script** in `~/.starkit` during install.
- Make `Create "<keyword>"` the default selection in the bar.

## Slices and acceptance criteria

### Slice 0 — it builds, installs, and keeps its signature

- `setup-signing.sh` creates the certificate; running it twice is harmless.
- `install.sh` produces `/Applications/Starkit.app` with no Dock icon and a menu bar item.
- `install.sh` seeds `~/.starkit` on a machine that has never had it, and on a second run leaves
  an edited **Script** byte-identical.
- `codesign -dv` reports the same signing identity before and after a rebuild.

### Slice 1 — the spine, without any UI

The seeded `work.gleam` opens nothing, because the repo carries no app lists — so the first two
criteria are met by filling in your own `~/.starkit/src/scripts/work.gleam`, not by the seed. That
is the boundary working, not a gap in it.

- `Starkit run work` opens ghostty, Slack, Notion and Zen.
- `Starkit run work --dry-run` prints four `Open` **Effects** and opens nothing.
- Breaking `youtube.gleam` and running `Starkit run work` still works; running
  `Starkit run youtube` **Refuses** and prints the compile error. This is [ADR 0002](./docs/adr/0002-one-project-with-per-script-staleness.md) working.
- Deleting `bun` from the shell's `PATH` makes `Starkit run work` fail with a message naming
  the **Toolchain**, not a crash.

### Slice 2 — the bar

- ⌃⌘K shows the bar in ≤ 50 ms; ⌃⌘K again hides it; Escape hides it.
- Typing `wo` selects Work; ↩ runs it and the bar disappears.
- ⌃N and ⌃P move the selection, as do ↓ and ↑.
- With Script Kit running, Starkit's menu bar icon is red and ⌃⌘K reaches Script Kit — the chord
  is never swallowed silently.
- The first ⌃⌘K after launch is no slower than the tenth.

### Slice 3 — Clean

- `gleam test` covers the **Kill** list before Clean is ever run for real.
- Clean **Kills** every regular app except the untouchable list, and Starkit survives.
- Clean gathers **Running Apps** in ≤ 5 ms, with no `osascript` process spawned — verifiable by
  watching for one.

### Slice 4 — Youtube

- With a YouTube URL on the clipboard, ⌃⌘K → `yt` → ↩ → ↩ pastes the markdown into the app that
  was frontmost before the bar appeared.
- The **Input** arrives **Seeded** and selected: typing replaces it without clearing first.
- After the paste, the clipboard holds the markdown, so ⌘V again repeats it.
- An unreachable network produces a **Notify** in the bar and no paste.
- A hung request is killed at 5 s, with a spinner until then.
- Rebuilding and reinstalling does not re-prompt for Accessibility.

### Slice 5 — Link from url

- A URL with an `h1` pastes `[Title](url)` with smart quotes and dashes normalised.
- A non-`https` **Input** produces a **Notify** and no paste.

### Slice 6 — authoring _(not MVP, but wanted the day you write a sixth Script)_

- Typing a **Keyword** that matches nothing offers `Create "<keyword>"`, never as the default
  selection: pressing ↩ on a typo does nothing at all.
- Choosing it writes `src/scripts/<keyword>.gleam` with a compiling `pub fn script()` and opens it
  in Zed. All typing happens in the editor; the bar only scaffolds.
- Saving a **Script** in Zed regenerates the registry, rebuilds, and rewrites `manifests.json`
  within 500 ms — so the new **Keyword** works at the next **Summon** with nothing else run.
- Creating a file in Zed *without* going through the bar registers it identically.
- A save that does not compile turns the menu bar icon red within 500 ms, and the previously built
  **Scripts** keep working.

### Slice 7 — boot

- Starkit is in the menu bar after a reboot with no login, and ⌃⌘K works within 3 s.
- Moving the bundle out of `/Applications` and back does not silently unregister it — the state
  shown in the menu is the state `SMAppService` reports, never a cached assumption.

## Out of scope

Dynamic pick-lists, a second key chord, notarized distribution, notifications outside the bar,
running a **Script** on a schedule, and syncing `~/.starkit` between machines. Each is recorded
with its revisit trigger in [DESIGN.md](./DESIGN.md) §9 where a decision was actually taken.
