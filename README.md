# Starkit

A keyboard-summoned launcher for a handful of personal automations, written in Gleam. Starkit
exists to replace the parts of Script Kit that get used, and nothing else.

⌃⌘K summons it — the same chord Script Kit used, so the muscle memory carries over. Script Kit
must be quit first: whichever app registers the chord first keeps it, and the loser fails
silently. Scripts live in `~/.starkit`; this repo is only the Shelf.

<!-- docs:start -->

## Documentation

- [seed/SCRIPTING.md](./seed/SCRIPTING.md) — what a **Script** may do and may not, the four
  **Effects**, and the save-to-**Keyword** loop. Vendored to `~/.starkit/SCRIPTING.md`, beside the
  **Scripts** it describes
- [tasks/todo.md](./tasks/todo.md) — the ordered task list, with checkpoints
- [tasks/plan.md](./tasks/plan.md) — dependency graph, verification per task, and what would change the plan
- [SPEC.md](./SPEC.md) — build order, acceptance criteria, commands, and boundaries
- [DESIGN.md](./DESIGN.md) — goals, measurable functions, and the trade-offs taken
- [CONTEXT.md](./CONTEXT.md) — the ubiquitous language: **Shelf**, **Script**, **Input**,
  **Context**, **Effect**, and the closed vocabularies of each
- [docs/adr/0001-compile-gleam-to-javascript.md](./docs/adr/0001-compile-gleam-to-javascript.md)
  — why **Scripts** target JavaScript rather than Erlang
- [docs/adr/0002-one-project-with-per-script-staleness.md](./docs/adr/0002-one-project-with-per-script-staleness.md)
  — why one project, and how a broken **Script** avoids taking the others down

<!-- docs:end -->
