//// Kills every running application except the ones worth keeping.
////
//// This stub declares the Need but returns no Kills, so installing Starkit cannot close your
//// windows before you have read what it does. The filter is implemented in T4.1, tests first:
//// Kill never asks and never prompts, so a mistake in the untouchable list is irreversible. It is
//// the one place in this project where the tests come before the code.

import starkit.{type Script, Decides, RunningApps, Script}

pub fn script() -> Script {
  Script(
    keyword: "clean",
    name: "Clean",
    needs: [RunningApps],
    asks: Decides,
    run: fn(_input, _context) {
      // T4.1: filter context.running_apps against the untouchable list and map to starkit.Kill.
      // Starkit itself must never appear in the result.
      []
    },
  )
}
