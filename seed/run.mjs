// The shim the Shelf actually executes: `bun run.mjs`. The node: imports below are not a leftover —
// bun implements them, and keeping them means this file is runtime-agnostic if that ever changes
// back (docs/adr/0003-run-artefacts-on-bun.md).
//
// Why this file exists. Gleam's JavaScript output is a plain ES module — entry.mjs ends in
// `export function main() {...}` and nothing calls it, so running entry.mjs directly loads the
// module and exits silently. `gleam run` works only because it generates a second file to do the
// calling,
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

const [verb, keyword, payload] = process.argv.slice(2);

// Every answer is awaited. Nothing entry.gleam exports is asynchronous today, but a Script that
// reaches the network is a Promise on this target, and awaiting a plain string costs nothing —
// so the shim is already right whichever way that lands. See DESIGN.md §9.
switch (verb) {
  case "describe":
    console.log(await module.describe());
    break;

  case "run": {
    if (keyword === undefined) {
      fail("run needs a Keyword: run <keyword> [payload]");
    }
    // The payload is passed through verbatim rather than parsed here: entry.gleam owns the
    // protocol, and a shim that understood it would be a second place to change.
    const answer = await module.run(keyword, payload ?? "{}");
    console.log(answer);
    // A Refusal reported twice, on purpose. The Shelf reads the answer it already decodes; the
    // exit code is for a person running this by hand.
    if (JSON.parse(answer).refusal !== undefined) process.exitCode = 1;
    break;
  }

  default:
    fail(`unknown verb ${JSON.stringify(verb ?? "")} — expected describe or run`);
}

function fail(message) {
  console.error(`run.mjs: ${message}`);
  process.exit(1);
}
