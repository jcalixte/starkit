# Starkit

A keyboard-summoned launcher for a handful of personal automations, written in Gleam. Starkit
exists to replace the parts of Script Kit that get used, and nothing else.

⌃⌘K summons it — the same chord Script Kit used, so the muscle memory carries over. Script Kit
must be quit first: whichever app registers the chord first keeps it, and the loser fails
silently. Scripts live in `~/.starkit`; this repo is only the Shelf.

## What a Script is

One Gleam module in `~/.starkit/src/scripts/`. It turns an **Input** and a **Context** into a list
of **Effects** — `Open`, `Kill`, `Paste`, `Notify` — and Starkit performs them. A Script decides
what should happen; it never touches the machine itself, which is why it is a pure function you can
unit-test with `gleam test`.

Five are seeded on install:

| Keyword | Does |
| ------- | ---- |
| `link` | Reads a URL's `h1` and pastes `[Title](url)` |
| `youtube`, `yt` | Turns a YouTube link into the note a video gets written down as |
| `clean` | Kills every running application except the ones worth keeping |
| `work` | Opens your working day — **ships empty, fill it in yourself** |
| `personal` | The same, for everything else |

`work` and `personal` are stubs on purpose. This repo carries no app lists, so nothing about your
employer's tooling ends up in it — see [seed/src/scripts/work.gleam](./seed/src/scripts/work.gleam).

## Requirements

- macOS 14 or later
- Xcode Command Line Tools (`xcode-select --install`) — Starkit builds from source
- `gleam` and `bun` on your `PATH`

Starkit borrows the toolchain from your machine rather than shipping one, and resolves it at every
launch. `brew upgrade gleam` is a non-event; there is no pinned version to bump. If your login shell
hides either tool, `~/.starkit/starkit.toml` takes an explicit path.

## Install

From the tap:

```sh
brew install jcalixte/tap/starkit
starkit-install
```

Or from source:

```sh
git clone https://github.com/jcalixte/starkit.git
cd starkit
./scripts/setup-signing.sh   # once per machine
./scripts/install.sh
```

`setup-signing.sh` creates a self-signed code-signing identity in your login keychain. It is not
cosmetic: macOS ties the Accessibility grant to an app's signature, and an ad-hoc signature changes
on every build — so without it, every rebuild silently drops the grant and `Paste` stops working.

`install.sh` is meant to be run again and again. Shelf-owned files in `~/.starkit` are re-vendored
each time so the vocabulary upgrades without a hand merge, and `src/scripts/` — the half you write —
is only ever written when a file is absent. **An install never touches a Script you have edited.**

There is no notarized download. Building locally is what keeps the signature stable and the app out
of quarantine; the trade is recorded as T8 in [DESIGN.md](./DESIGN.md).

## First launch

Starkit has no Dock icon — it lives in the menu bar, and the icon turns red when something is wrong.

- **Accessibility** is requested the first time a Script uses `Paste`, because synthesising ⌘V needs
  it. Nothing else does. System Settings → Privacy & Security → Accessibility → Starkit.
- **Start at Login** is turned on by `install.sh` and can be toggled from the menu.

## Using it

⌃⌘K, type a keyword, press ↩.

| Key | Does |
| --- | ---- |
| ↩ | Runs the selected Script, or creates one when nothing matches |
| ⌥↩ or ⌃O | Opens the selected Script in your editor |
| ⌃D, then ⌃D again | Moves a Script and its test to the Trash, naming the files first |
| Escape or ⌃⌘K | Dismisses the bar. A Script already running still finishes and performs its Effects |

From a terminal, where only exact keywords resolve — a prefix that reaches the wrong Script shows
you nothing before it runs, so `Starkit run c` meaning `clean` is not a risk worth taking:

```sh
Starkit run youtube "https://youtu.be/…"
Starkit run clean --dry-run    # prints the Effects, performs none
```

The tap puts `Starkit` on your `PATH`. A source install does not: the binary lives inside the
bundle, at `/Applications/Starkit.app/Contents/MacOS/Starkit`, so alias it or symlink it yourself.
`Paste` from a terminal needs the *terminal* to hold the Accessibility grant, not Starkit.

## Writing a Script

[seed/SCRIPTING.md](./seed/SCRIPTING.md) is the guide, and it is vendored to
`~/.starkit/SCRIPTING.md` so it sits beside the Scripts it describes. The loop is short: save a file
in `src/scripts/`, and the keyword works at the next summon with nothing else run. A file that does
not compile turns the menu bar icon red and leaves every other Script working.

## By design

Things people ask for that Starkit will not do:

- **The chord is ⌃⌘K and cannot be changed.** It races Script Kit, Raycast and Alfred, and the loser
  registers nothing without saying so. Quit the other one.
- **No preferences window, no themes, no per-Script configuration** outside its own manifest.
- **No dynamic pick-lists.** Effects go out and nothing comes back, so `clean` is all or nothing.
- **A Script cannot run another Script**, use `@external`, or outlive a 5 s deadline.

<!-- docs:start -->

## Documentation

- [seed/SCRIPTING.md](./seed/SCRIPTING.md) — what a **Script** may do and may not, the four
  **Effects**, and the save-to-**Keyword** loop. Vendored to `~/.starkit/SCRIPTING.md`, beside the
  **Scripts** it describes
- [tasks/todo.md](./tasks/todo.md) — the ordered task list, with checkpoints
- [tasks/plan.md](./tasks/plan.md) — dependency graph, verification per task, and what would change the plan
- [SPEC.md](./SPEC.md) — build order, acceptance criteria, commands, and boundaries
- [DESIGN.md](./DESIGN.md) — goals, measurable functions, and the trade-offs taken
- [CONTEXT.md](./CONTEXT.md) — the ubiquitous language: **Shelf**, **Script**, **Input**,
  **Context**, **Effect**, and the closed vocabularies of each
- [docs/adr/0001-compile-gleam-to-javascript.md](./docs/adr/0001-compile-gleam-to-javascript.md)
  — why **Scripts** target JavaScript rather than Erlang
- [docs/adr/0002-one-project-with-per-script-staleness.md](./docs/adr/0002-one-project-with-per-script-staleness.md)
  — why one project, and how a broken **Script** avoids taking the others down

<!-- docs:end -->

`SPEC.md`, `DESIGN.md`, `CONTEXT.md` and `tasks/` are the author's own working record, kept current
because the project is built from them. `SCRIPTING.md` is the one written for you.

## Licence

MIT — see [LICENSE](./LICENSE).
