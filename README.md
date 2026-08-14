<!-- Drawn by `Starkit icon`, from the same path the bar's mark uses. Regenerate it rather than edit
it: `Starkit icon <dir>.iconset` writes every size, and this is the 256 px one. -->
<p align="center">
  <img src="./docs/starkit.png" alt="Starkit" width="128" height="128">
</p>

# Starkit

[![CI](https://github.com/jcalixte/starkit/actions/workflows/ci.yml/badge.svg)](https://github.com/jcalixte/starkit/actions/workflows/ci.yml)

I really like [Script Kit](https://www.scriptkit.com), but I wanted faster, with less features and being able to learn [Gleam](https://gleam.run). Introducing **Starkit** a desktop bar for running your own Gleam scripts. ⌃⌘K summons it.

Scripts live in `~/.starkit`.

## What a Script is

One Gleam module in `~/.starkit/src/scripts/`. It turns an **Input** and a **Context** into a list
of **Effects** (`Open`, `Kill`, `Paste`, `Notify`).

Five are seeded on install:

| Keyword | Does |
| ------- | ---- |
| `link` | Reads a URL's `h1` and pastes `[Title](url)` |
| `youtube`, `yt` | Turns a YouTube link into the note a video gets written down as |
| `clean` | Kills every running application except the ones on your keep list |
| `work` | Opens your working day — **ships empty, fill it in yourself** |
| `personal` | The same, for everything else |

## Requirements

- macOS 14 or later
- `gleam` and `bun` on your `PATH`
- Xcode Command Line Tools (`xcode-select --install`), only to build it yourself
- `just` and `gh`, only to cut a release

## Install

From the tap, which installs a notarized build and needs nothing else run:

```sh
brew install --cask jcalixte/tap/starkit
```

Or [download the zip](https://github.com/jcalixte/starkit/releases/latest) and drag it to
`/Applications`. Either way the app sets `~/.starkit` up the first time it launches: it seeds the
**Scripts**, builds them, and turns on Start at Login.

## First launch

Starkit lives in the menu bar, and the icon turns red when something is wrong.

- **Accessibility** is requested the first time a Script uses `Paste`, because synthesising ⌘V needs
  it. Nothing else does. System Settings → Privacy & Security → Accessibility → Starkit.
- **Start at Login** is turned on once by the app itself on a first launch
  and can be toggled from the menu afterwards.

## Using it

⌃⌘K, type a keyword, press ↩.

| Key | Does |
| --- | ---- |
| ↩ | Runs the selected Script, or creates one when nothing matches |
| ⌥↩ or ⌃O | Opens the selected Script in your editor, or writes the one nothing matched |
| ⌃D, then ⌃D again | Moves a Script and its test to the Trash, naming the files first |
| Escape or ⌃⌘K | Dismisses the bar. A Script already running still finishes and performs its Effects |

From a terminal, where only exact keywords resolve and `Starkit run c` will not reach `clean`:

```sh
Starkit run youtube "https://youtu.be/…"
Starkit run clean --dry-run    # prints the Effects, performs none
```

## By design

Limits, all of them deliberate:

- The chord is ⌃⌘K and cannot be changed. It races Script Kit, Raycast and Alfred, and the loser
  registers nothing without saying so. Quit the other one.
- There is no preferences window, no theming, and no per-Script configuration outside its own
  manifest.
- Effects go out and nothing comes back, so no Script can stop and offer you a list to choose
  from. `clean` kills its whole list or none of it.
- A Script cannot run another Script, use `@external`, or outlive a 5 s deadline.

## Documentation

- [seed/SCRIPTING.md](./seed/SCRIPTING.md) — what a **Script** may do and may not, the four
  **Effects**, and the save-to-**Keyword** loop. Vendored to `~/.starkit/SCRIPTING.md`, beside the
  **Scripts** it describes
- [tasks/todo.md](./tasks/todo.md) — the ordered task list, with checkpoints
- [tasks/plan.md](./tasks/plan.md) — dependency graph, verification per task, and what would change the plan
- [SPEC.md](./SPEC.md) — build order, acceptance criteria, commands, and boundaries
- [DESIGN.md](./DESIGN.md) — goals, measurable functions, and the trade-offs taken
- [docs/houses/house-1-goals-functions.md](./docs/houses/house-1-goals-functions.md) — the whole
  design on one page: what Starkit is for, what it must do to deliver that, and where the engineering
  weight lands. First of four cascaded houses, each one's weights derived from the one above; the
  other three carry them down into **Components**, the commands that build them, and the gates that
  catch a regression
- [CONTEXT.md](./CONTEXT.md) — the ubiquitous language: **Shelf**, **Script**, **Input**,
  **Context**, **Effect**, and the closed vocabularies of each
- [docs/adr/0001-compile-gleam-to-javascript.md](./docs/adr/0001-compile-gleam-to-javascript.md)
  — why **Scripts** target JavaScript rather than Erlang
- [docs/adr/0002-one-project-with-per-script-staleness.md](./docs/adr/0002-one-project-with-per-script-staleness.md)
  — why one project, and how a broken **Script** avoids taking the others down
- [docs/adr/0003-run-artefacts-on-bun.md](./docs/adr/0003-run-artefacts-on-bun.md) — why **Artefacts**
  run on bun, and why the node fallback was rejected

`SPEC.md`, `DESIGN.md`, `CONTEXT.md` and `tasks/` are the author's own working record, kept current
because the project is built from them. `SCRIPTING.md` is the one written for you.

## Licence

MIT — see [LICENSE](./LICENSE).
