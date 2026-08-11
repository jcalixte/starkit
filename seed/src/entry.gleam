//// The entry point the Shelf invokes.
////
//// The Shelf runs the built artefact directly — `node build/dev/javascript/starkit/entry.mjs` —
//// so this module's name is free and need not match the package. `starkit` is the Vocabulary
//// instead, which is what makes `import starkit.{type Effect}` read the way it does in a Script.
////
//// T1.1 replaces `main` with the real two-verb protocol: `describe`, which prints every manifest
//// as JSON for the Catalogue to read, and `run <keyword> <payload>`, which prints the Effects.
//// For now it lists what the registry contains, which is enough to prove the registry generated
//// by scripts/gen-registry.sh is wired up and every Script compiles.

import gleam/io
import gleam/list
import registry
import starkit

pub fn main() {
  list.each(registry.all(), fn(script: starkit.Script) {
    io.println(script.keyword <> "\t" <> script.name)
  })
}
