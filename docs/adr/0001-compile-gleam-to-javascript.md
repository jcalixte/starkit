# Compile Scripts to JavaScript, not Erlang

Starkit is summoned by a keystroke, so the whole cost of a **Script** — build check plus
execution — has to disappear into the gap before a person notices. Measured on this machine
with equivalent hello-world projects:

|                          | Erlang target | JavaScript target |
| ------------------------ | ------------- | ----------------- |
| `gleam build`, no change | 300 ms        | 26 ms             |
| `gleam build` after edit | 280 ms        | 33 ms             |
| build + run, end to end  | 450 ms        | 93 ms             |

The gap is structural rather than something to tune: the Erlang target boots a BEAM to run
`erlc`, then boots another to run the code. The JavaScript target is Rust codegen straight to
`.mjs`, executed by `node`. We chose JavaScript.

It also happens to solve the two **Scripts** that need the network. `gleam_fetch` plus
`gleam_json` fetched and decoded the real YouTube oembed response in 204 ms including the
round trip, with no FFI — so a **Script** owning the network costs nothing extra.

## Consequences

This is not BEAM Gleam, and it is not meant to be. No `gleam_erlang`, no actors, no OTP, and
any Erlang-only Hex package is unavailable. Every **Script** written against this decision
assumes a JavaScript runtime, so reversing it later means revisiting all of them — that is
what makes this worth writing down rather than the ~350 ms.

`node` becomes a hard runtime dependency of the **Shelf**. Accepted knowingly: it is already
on this machine, and the alternative dependency was Erlang/OTP, which is larger.
