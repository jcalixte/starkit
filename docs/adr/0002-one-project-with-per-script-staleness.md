# One Gleam Project, With Per-Script Staleness Checks

All **Scripts** live in a single Gleam project, one module each. The obvious alternative, a project
per **Script**, buys true isolation but costs five dependency trees, five ~2 s cold builds, ~14 MB
of build output against 2.8 MB, and turns "create a **Script**" from writing one file into
scaffolding a project. Against the footprint goal, that is the wrong trade.

The problem with one project is that `gleam build` fails as a whole, so a single broken **Script**
would stop every other one from running. That is unacceptable: the failure would surface at the
moment of summoning, when there is no time to fix it.

Two measurements make it avoidable. Gleam emits **no** artefacts when any module fails, so an
artefact on disk is never partially updated. And an unedited **Script**'s artefact is not stale,
having been built from exactly the source still on disk. So comparing source against artefact
identifies the culprit precisely.

The **Shelf** therefore records, after every successful build, the SHA-256 of each **Script** source
and each shared module: the state in which "every artefact matches the source beside it" is known to
be true. Against that record it applies, per **Script**:

- source unchanged since the last successful build, so run it, even if the project as a whole does
  not build
- source changed, so refuse and show the compile error
- any shared module changed, so refuse everything, because all **Scripts** depend on the vocabulary

The guarantee that follows is that a **Script** you have not edited always runs.

## Content, not mtime (corrected at T1.4)

The first version of this compared mtimes: source newer than artefact meant stale. That is wrong,
and the first real `Starkit run work` proved it. Gleam's incremental build compares *content*, so
`touch work.gleam && gleam build` correctly recompiles nothing and correctly leaves the artefact's
mtime where it was, while the mtime rule read that as an edit and refused the **Script**
permanently, since no rebuild would ever move the artefact again. Any editor that rewrites a file on
save without changing a byte reaches it, and the machine this was found on was already in that
state.

The lesson generalises past the fix. The **Shelf** and Gleam have to mean the same thing by
"changed", and where they differ Gleam wins, because Gleam is the one that decides what gets
compiled. Hashing asks the same question Gleam asks, in the same way.

Costs, taken knowingly: one file of Starkit's own bookkeeping (`~/.starkit/built.json`), which the
next successful build rewrites and which failing to read means refusing **Scripts** that would have
run, the safe direction. Five SHA-256s over about a kilobyte each, per check.

An mtime stamp of the last successful build was considered and would have fixed this case too, at
less state. Hashing was chosen because it eliminates the whole class: a `git checkout`, a restore
from backup, or an install that vendors a *changed* file with an older mtime all defeat a timestamp,
and none of them defeat a hash.

## Consequences

The guarantee covers **Scripts** you have not touched, not **Scripts** you touched during someone
else's breakage. Edit `clean.gleam` validly while `youtube.gleam` is broken and Clean refuses too,
because it cannot be compiled. This is accepted: it only happens while actively editing, and the
alternative is running code that is not what is on disk.

The **Shelf** compares hashes instead of simply running `gleam build && bun`, which will look like
superstition to a future reader. It is the whole isolation mechanism.
