# Starkit — MVP task list

Ordered. Rationale, dependencies and verification steps are in [plan.md](./plan.md); acceptance
criteria per slice are in [SPEC.md](../SPEC.md).

## Phase 1 — Foundations

- [x] **T0.1** `Package.swift`, `Info.plist` (`LSUIElement`), `main.swift` with a menu bar item
- [ ] **T0.2** `setup-signing.sh` + signing in `build.sh` — adapt from `cmd-tab`
- [ ] **T0.3** `~/.starkit` skeleton: `gleam.toml`, `starkit.gleam`, `entry.gleam`, 5 stubs, `gen-registry.sh`
- [ ] **T0.4** `install.sh` — `/Applications`, idempotent seed, first `gleam build`
- [ ] **T0.5** Paste spike (throwaway) — ⌘V into the previously frontmost app from a signed bundle

> **Checkpoint A** — installs, keeps its signature, Paste proven possible.
> If T0.5 fails, stop and redesign the **Paste** **Effect** before phase 2.

## Phase 2 — The spine, no UI

- [ ] **T1.1** **Vocabulary** types + `work` **Script** + `entry.gleam` (`describe` / `run`)
- [ ] **T1.2** C12 Toolchain — login-shell resolution, `starkit.toml` override, named error
- [ ] **T1.3** C5 Builder + `Staleness` pure rule **+ its 4 tests**
- [ ] **T1.4** C4 Runner — spawn `node`, feed a run, decode **Effects**, 5 s deadline
- [ ] **T1.5** C7 Effector — **Open** only
- [ ] **T1.6** Isolation check — break `youtube.gleam`, confirm `work` still runs

> **Checkpoint B** — the architecture is proven end to end. Everything after this is surface.

## Phase 3 — The bar

- [ ] **T2.1** C3 HotKey ⌃⌘K + C10 MenuBarStatus red when the chord can't be held
- [ ] **T2.2** C1 SummonPanel — built once at launch, shown/hidden, Escape
- [ ] **T2.3** C2 Catalogue + `Keyword` pure parsing **+ its 3 tests**
- [ ] **T2.4** Bar view — list, filter, selection, ↩ runs
- [ ] **T2.5** F13 — Cocoa action selectors, not keycodes (⌃N/⌃P come free)

> **Checkpoint C** — ⌃⌘K runs Work. 2 of 5 **Scripts** usable.

## Phase 4 — Clean

- [ ] **T4.1** `clean` **Script** — **tests first**, before it runs for real
- [ ] **T4.2** C8 ContextGatherer + the `needs` → gather → payload path
- [ ] **T4.3** C7 **Kill** — `forceTerminate`

> **Checkpoint D** — 3 of 5. Nothing needs Accessibility yet.

## Phase 5 — Youtube

- [ ] **T5.1** **Input** stage + **Seed** from clipboard, arriving selected
- [ ] **T5.2** `youtube` **Script** + tests (6 URL shapes) + `gleam_fetch`
- [ ] **T5.3** C7 **Paste** — restore focus, ⌘V, leave the pasted text on the clipboard
- [ ] **T5.4** **Notify** in the bar, spinner, 5 s kill
- [ ] **T5.5** Accessibility grant survives a rebuild

> **Checkpoint E** — 4 of 5, and the only permission-gated path is stable across rebuilds.

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
