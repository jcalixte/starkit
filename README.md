<!-- Drawn by `Starkit icon`, from the same path the bar's mark uses. Regenerate it rather than edit
it: `Starkit icon <dir>.iconset` writes every size, and this is the 256 px one. -->
<p align="center">
  <img src="./docs/starkit.png" alt="Starkit" width="128" height="128">
</p>

# Starkit

[![CI](https://github.com/jcalixte/starkit/actions/workflows/ci.yml/badge.svg)](https://github.com/jcalixte/starkit/actions/workflows/ci.yml)

A keyboard-summoned launcher for a handful of personal automations, written in Gleam. Starkit
exists to replace the parts of Script Kit that get used, and nothing else.

⌃⌘K summons it, the same chord Script Kit used, so the muscle memory carries over. Script Kit must
be quit first: whichever app registers the chord first keeps it, and the loser fails silently.
Scripts live in `~/.starkit`; this repo is only the Shelf.

## What a Script is

One Gleam module in `~/.starkit/src/scripts/`. It turns an **Input** and a **Context** into a list
of **Effects** (`Open`, `Kill`, `Paste`, `Notify`) and Starkit performs them. A Script decides what
should happen; it never touches the machine itself, which is why it is a pure function you can
unit-test with `gleam test`.

Five are seeded on install:

| Keyword | Does |
| ------- | ---- |
| `link` | Reads a URL's `h1` and pastes `[Title](url)` |
| `youtube`, `yt` | Turns a YouTube link into the note a video gets written down as |
| `clean` | Kills every running application except the ones on your keep list |
| `work` | Opens your working day — **ships empty, fill it in yourself** |
| `personal` | The same, for everything else |

`work` and `personal` are stubs on purpose. This repo carries no app lists, so nothing about your
employer's tooling ends up in it. See [seed/src/scripts/work.gleam](./seed/src/scripts/work.gleam).

## Requirements

- macOS 14 or later
- `gleam` and `bun` on your `PATH`
- Xcode Command Line Tools (`xcode-select --install`), only to build it yourself
- `just` and `gh`, only to cut a release

Starkit borrows the toolchain from your machine instead of shipping one, and resolves it at every
launch. `brew upgrade gleam` is a non-event; there is no pinned version to bump. If your login shell
hides either tool, `~/.starkit/starkit.toml` takes an explicit path.

## Install

From the tap, which installs a notarized build and needs nothing else run:

```sh
brew install --cask jcalixte/tap/starkit
```

Or [download the zip](https://github.com/jcalixte/starkit/releases/latest) and drag it to
`/Applications`. Either way the app sets `~/.starkit` up the first time it launches: it seeds the
**Scripts**, builds them, and turns on Start at Login. The first build resolves dependencies, so it
is slow, and the menu bar says so while it runs.

Or from source:

```sh
git clone https://github.com/jcalixte/starkit.git
cd starkit
./scripts/setup-signing.sh   # once per machine
./scripts/install.sh
```

`setup-signing.sh` creates a self-signed code-signing identity in your login keychain. It matters:
macOS ties the Accessibility grant to an app's signature, and an ad-hoc signature changes on every
build, so without it every rebuild silently drops the grant and `Paste` stops working.

`install.sh` is meant to be run again and again. Shelf-owned files in `~/.starkit` are re-vendored
each time so the vocabulary upgrades without a hand merge, and `src/scripts/`, the half you write,
is only ever written when a file is absent. An install never touches a Script you have edited — and
it is the same rule the app applies to itself on a first launch, in Swift rather than in bash.

Releases are signed with a Developer ID and notarized, so a download opens without the
right-click-open dance. Building your own copy is signed by `setup-signing.sh` instead, which is
what keeps *that* signature stable across rebuilds; the trades are T8 and T15 in
[DESIGN.md](./DESIGN.md).

## First launch

Starkit has no Dock icon. It lives in the menu bar, and the icon turns red when something is wrong.

- **Accessibility** is requested the first time a Script uses `Paste`, because synthesising ⌘V needs
  it. Nothing else does. System Settings → Privacy & Security → Accessibility → Starkit.
- **Start at Login** is turned on once — by `install.sh`, or by the app itself on a first launch —
  and can be toggled from the menu afterwards. Nothing turns it back on behind you.

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

No install puts `Starkit` on your `PATH`: the binary lives inside the bundle, at
`/Applications/Starkit.app/Contents/MacOS/Starkit`, so alias it or symlink it yourself. `Paste` from
a terminal needs the *terminal* to hold the Accessibility grant, not Starkit.

## Writing a Script

[seed/SCRIPTING.md](./seed/SCRIPTING.md) is the guide, and it is vendored to
`~/.starkit/SCRIPTING.md` so it sits beside the Scripts it describes. The loop is short: save a file
in `src/scripts/`, and the keyword works at the next summon with nothing else run. A file that does
not compile turns the menu bar icon red and leaves every other Script working.

## Releasing

The author's runbook. `just` is the front door, and `just` on its own lists the rest.

Bump `CFBundleShortVersionString` in `Resources/Info.plist`, commit it, push it. One command does
the rest:

```sh
just publish 0.4.0
```

It builds, signs with the Developer ID, notarizes, staples, tags, creates the GitHub Release with
the zip attached, and points the cask at the sha256 GitHub is really serving rather than the one
sitting on this disk. The notes are written from the commit subjects since the last tag, since the
subjects here are sentences already; hand it a file when a release has more to say than a list.

```sh
just publish 0.4.0 notes.md
```

Nothing is built, tagged or uploaded until every refusal has been made: the branch has to be `main`,
the tree clean, the tag free, `HEAD` pushed, and `Info.plist` already carrying the version you asked
for. That last one is checked and never edited, because the version bump is a commit somebody
writes.

Apple's notary queue has no SLA, and the first submission from this repo waited seven hours. If the
wait ends before the answer does, the accepted build is still in `build/` and must not be rebuilt —
a rebuild re-signs with a new timestamp, which is no longer the app the ticket was issued against.

```sh
just staple      # attach the ticket to build/Starkit.app
just ship 0.4.0  # tag, release, cask
```

The cask lives in [jcalixte/homebrew-tap](https://github.com/jcalixte/homebrew-tap), expected as a
sibling checkout at `../homebrew-tap`, or wherever `STARKIT_TAP` points.

## By design

Limits, all of them deliberate:

- The chord is ⌃⌘K and cannot be changed. It races Script Kit, Raycast and Alfred, and the loser
  registers nothing without saying so. Quit the other one.
- There is no preferences window, no theming, and no per-Script configuration outside its own
  manifest.
- Effects go out and nothing comes back, so no Script can stop and offer you a list to choose
  from. `clean` kills its whole list or none of it.
- A Script cannot run another Script, use `@external`, or outlive a 5 s deadline.

<!-- docs:start -->

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

<!-- docs:end -->

`SPEC.md`, `DESIGN.md`, `CONTEXT.md` and `tasks/` are the author's own working record, kept current
because the project is built from them. `SCRIPTING.md` is the one written for you.

## Licence

MIT — see [LICENSE](./LICENSE).
