// The shim the Shelf actually executes: `bun run.mjs`. The node: imports below are not a leftover —
// bun implements them, and keeping them leaves this file runtime-agnostic
// (docs/adr/0003-run-artefacts-on-bun.md).
//
// Why this file exists. Gleam's JavaScript output is a plain ES module: entry.mjs ends in
// `export function main() {...}` and nothing calls it, so running entry.mjs directly loads the
// module and exits silently. `gleam run` works only by generating a second file to do the calling:
//
//     build/dev/javascript/starkit/gleam@@private_main_v1.18.1.mjs
//
// That path is marked private and carries the Gleam version in its name, so every upgrade renames
// it — depending on it would mean `brew upgrade gleam` silently breaking every Script (G7).
// Shelling out to `gleam run` re-resolves and re-checks the project on every Summon, which costs
// far more than the latency budget allows. So the Shelf depends on this file instead, and the only
// assumption left is that entry.mjs exports a function.
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

switch (verb) {
  case "describe":
    console.log(await module.describe());
    break;

  case "run": {
    if (keyword === undefined) {
      fail("run needs a Keyword: run <keyword> [payload]");
    }
    // Passed through verbatim rather than parsed here: entry.gleam owns the protocol, and a shim
    // that understood it would be a second place to change.
    const answer = await module.run(keyword, payload ?? "{}");
    console.log(answer);
    // A Refusal reported twice on purpose: the Shelf reads the answer it already decodes, and the
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
