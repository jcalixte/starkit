# Run Artefacts on bun, not node

[ADR 0001](./0001-compile-gleam-to-javascript.md) chose the JavaScript target and named `node` as
the runtime that would execute the output. That second half was never measured. Node was simply the
obvious JavaScript runtime, and at the time nothing depended on which one it was.

F5 gives a run a ≤ 20 ms budget. Measured over 60 cold spawns of `run.mjs` against the real seed
(5 **Scripts**, `gleam_json`) with the benchmark harness's own fork/exec subtracted:

|                     | min     | median  | p90     |
| ------------------- | ------- | ------- | ------- |
| bun 1.3.14          | 16.0 ms | 17.6 ms | 21.9 ms |
| deno 2.7.4          | 23.6 ms | 26.9 ms | 29.5 ms |
| node 24.19.0 (shim) | 41.0 ms | 54.9 ms | 59.1 ms |

Output is byte-identical on all three and `run.mjs` needs no edit, since its `node:url` and
`node:path` imports resolve under bun and deno alike, so this cost one string in C12 instead of a
migration.

What matters is that a cold spawn per run fits F5 on bun and does not on node; the three-times
figure is incidental. Node's 54.9 ms is 2.7× over budget, which is the entire reason T3 exists:
spawn speculatively at **Summon** so the process is warm by the time you press Enter, and pay for it
with a process lifecycle in C4. On bun that machinery buys about 11 ms.

## Alternatives

### deno

Its permission sandbox looked like a fit for typed **Manifests**: a **Script** that declares no
network could run without `--allow-net`, enforcing at the process level what T5 enforces at the type
level. It is unreachable from this architecture. The process is spawned before a **Keyword** is
known, so permissions would have to be the union of every **Script**, which enforces nothing.
Tailoring them per **Script** means spawning after Enter, at 27 ms against a 20 ms budget. It also
needs `[javascript.deno] allow_read = true` in `gleam.toml` or gleeunit cannot read `gleam.toml` and
every test dies.

### bun with a fallback to node

Rejected, and worth recording. Node's cold-spawn-per-run is 2.7× over F5, so falling back to node
means running a different design and not a slower version of this one. Supporting both means keeping
all of T3's resident-process machinery alive for a path exercised approximately never, buying bun's
speed and node's complexity at once, and the divergence stays hidden until the day it fires. A
missing runtime is what F15 and C10 already handle: red before it is needed, the same treatment
`gleam` gets.

## Consequences

`bun` becomes the hard runtime dependency of the **Shelf**, replacing `node`. This supersedes the
last paragraph of ADR 0001. Nothing else in that decision changes, because the compilation target is
still JavaScript and every **Script** written against it is unaffected.

G7 takes on a faster-moving runtime. bun ships patch releases weekly where node ships monthly, and
G7 promises an upgrade is never an event. Measured instead of assumed: 1.3.8 and 1.3.14 spawn within
noise of each other. That is one data point and not a guarantee, and the risk is knowingly accepted
here.

`gleam.toml` needs `runtime = "bun"` under `[javascript]` so `gleam test` runs gleeunit on the same
runtime the **Shelf** uses. Verified against the real seed.

bun ignores `NO_COLOR` and writes ANSI escapes into its error output, so C4 must strip them from
stderr before F12 puts the message in the bar.

Whether T3 survives is left open deliberately. The median fits F5 outright, which would delete the
speculative spawn, the kill-on-dismiss and the whole process lifecycle from C4, the component
`DESIGN.md` §7 names as riskiest. Against it, p90 is 21.9 ms, 10 % over a budget whose purpose is
imperceptibility. Decided at T1.4, where C4 is built and where keeping T3 costs real code.
