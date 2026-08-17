# Ranked-list pass

From the review of 2026-08-16. Ranked as reported.

## Correctness

- [x] 1. `Watcher.Stream` teardown — `deinit` that stops, invalidates and releases the stream, and a
      comment that names a method that exists.
- [x] 2. Deadline on `gleam build` — the only unbounded wait in the run path.
- [x] 3. `Effector`'s AppKit reads on the main actor, so the rule `AppDelegate` states is true.
- [ ] 4. Swift 6 language mode — **left out**, see the note at the bottom.

## Coverage

- [x] 5. Contract between the two halves: `entry.encode`, a Gleam test pinning every **Effect**
      spelling to the string the Swift `EffectTests` decodes, and `Starkit describe` run in CI so the
      real reply goes through the real decoder.
- [x] 6. `Toolchain`'s hand-rolled TOML subset into `StarkitCore` as `Overrides`, with tests.

## CI

- [x] 7. `.swift-format` and a lint step, to match the `gleam format --check` on the other half.
- [x] 8. `swift build -c release`.

## Product

- [x] 9. `editor` in `starkit.toml`, so ⌥↩ is not Zed-or-nothing.
- [x] 10. Accessibility roles and labels on the bar's hand-drawn views.

## Small

- [x] 11. `SummonPanel.stopAsking`'s duplicated doc line.
- [x] 12. One `note(_:as:)` in `AppDelegate` and one `refused(_:)` in `main.swift`.
- [x] 13. `patientBuild` captures `self` weakly like everything else in the file.
- [x] 14. `warm()`'s `hidden` holds the alpha it restores, not a hidden one.

## Left out

**4 — Swift 6 language mode.** All three targets set `.swiftLanguageMode(.v5)` under
`swift-tools-version: 6.0`, so strict concurrency is off. Turning it on is the structural version of
1 and 3 and is worth doing, but it is an iterative compile loop against AppKit: this machine is Linux
and has no Swift toolchain, so the diagnostics cannot be read, let alone answered. It needs a macOS
session.

## Review

All but 4 done. Marked boxes above.

**Verified.** The Gleam half only: `gleam format --check src test` clean, and `gleam test` 86 passed,
no failures — the 4 new `entry_test` cases among them, which is what proves the contract string in
`entry_test.gleam` is character for character what `gleam_json` emits and therefore what
`EffectTests.everyKind` decodes. Run on node rather than bun, which this machine has and bun it does
not; the runtime does not touch what `json.to_string` writes.

**Not verified.** Everything in Swift. This machine is Linux with no toolchain, so nothing was
compiled and `swift test` was not run. The changes were made to read as if they had been. Two
specific places to look at first on a machine that can build:

- `Effector.onMain` deliberately avoids `MainActor.assumeIsolated`, whose result must be `Sendable`
  and `[NSRunningApplication]` is not. It is `DispatchQueue.main.sync`, which constrains nothing.
- The `swift format lint` step in CI is the one change that could be red on arrival: 190 lines in
  `Sources/` and `Tests/` are 101–124 characters, nearly all of them comments, and whether
  swift-format reports a comment it cannot reflow was not testable here. One pass fixes it either
  way: `swift format --in-place --recursive Sources Tests Package.swift`.
