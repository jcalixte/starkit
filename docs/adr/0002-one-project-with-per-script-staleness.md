# One Gleam Project, With Per-Script Staleness Checks

All **Scripts** live in a single Gleam project, one module each. The obvious alternative — a
project per **Script** — buys true isolation but costs five dependency trees, five ~2 s cold
builds, ~14 MB of build output against 2.8 MB, and turns "create a **Script**" from writing one
file into scaffolding a project. Against the footprint goal, that is the wrong trade.

The problem with one project is that `gleam build` fails as a whole, so a single broken
**Script** would stop every other one from running. That is unacceptable: the failure would
surface at the moment of summoning, which is always the worst moment.

Two measurements make it avoidable. Gleam emits **no** artefacts when any module fails, so an
artefact on disk is never partially updated. And an untouched **Script**'s artefact is not
stale — it was built from exactly the source still on disk. So mtime identifies the culprit
precisely: source newer than artefact means stale, otherwise the artefact is current.

The **Shelf** therefore applies, per **Script**:

- artefact newer than source → run it, even if the project as a whole does not build
- source newer than artefact → refuse, and show the compile error
- any shared module newer than its artefact → refuse everything, because all **Scripts**
  depend on the vocabulary

Which yields the guarantee worth stating plainly: **a Script you have not edited always runs.**

## Consequences

The guarantee covers **Scripts** you have not touched, not **Scripts** you touched during
someone else's breakage. Edit `clean.gleam` validly while `youtube.gleam` is broken and Clean
refuses too, because it cannot be compiled. This is accepted: it only happens while actively
editing, and the alternative is running code that is not what is on disk.

The **Shelf** compares mtimes rather than simply running `gleam build && node`, which will look
like superstition to a future reader. It is not — it is the whole isolation mechanism.
