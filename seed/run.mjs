// The shim the Shelf actually executes: `node run.mjs`.
//
// Why this file exists. Gleam's JavaScript output is a plain ES module — entry.mjs ends in
// `export function main() {...}` and nothing calls it, so `node entry.mjs` loads the module and
// exits silently. `gleam run` works only because it generates a second file to do the calling,
// and that file is named:
//
//     build/dev/javascript/starkit/gleam@@private_main_v1.18.1.mjs
//
// It is marked private and it carries the Gleam version in its name, so every Gleam upgrade
// renames it. Depending on that path would mean `brew upgrade gleam` silently breaking every
// Script, which is exactly what goal G7 rules out. Shelling out to `gleam run` instead would work,
// but it re-resolves and re-checks the project on every Summon and costs far more than the latency
// budget allows.
//
// So the Shelf depends on this file rather than on anything Gleam generates. The only assumption
// left is that entry.mjs exports a function — the weakest one available, and one that breaks loudly
// at import time rather than silently.
//
// This file is Shelf-owned: vendored into ~/.starkit and overwritten on every install. The ban on
// @external applies to Scripts, not to this shim; reaching process.argv is precisely its job.

import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
// Gleam's build layout. Not a documented interface — recorded as a watched tension in DESIGN.md §9.
const entry = join(here, "build", "dev", "javascript", "starkit", "entry.mjs");

const module = await import(entry);

// T1.1 replaces this with the two-verb protocol: `describe` prints every manifest as JSON, and
// `run <keyword> <payload>` prints the Effects. Both need process.argv, which is why the shim and
// not Gleam owns the argument handling.
await module.main();
