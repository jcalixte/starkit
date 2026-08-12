//// Kills every running application except the ones worth keeping.
////
//// The only destructive path in the system. Kill never asks and never prompts, so a name missing
//// from `keep` is an application closed with whatever was unsaved in it.
////
//// Clean is all or nothing — Effects go out and nothing comes back (DESIGN.md §9), so it cannot
//// offer a list to pick from. The keep list is how you say "not that one", in advance.

import gleam/list
import gleam/string
import starkit.{type Effect, type Script, Decides, Kill, RunningApps, Script}

pub fn script() -> Script {
  Script(
    keyword: "clean",
    name: "Clean",
    needs: [RunningApps],
    asks: Decides,
    run: fn(_input, context) { kills(context.running_apps, keep) },
  )
}

/// The applications you want left running. Yours to edit — this file is seeded once and never
/// overwritten by an install.
///
/// Write the name macOS shows, spelled in full: `Google Chrome`, not `Chrome`. Case and surrounding
/// spaces do not matter; anything else does, **including the language**. The list the Shelf hands
/// over is what each application calls itself on *this* machine, so on a French one it says
/// `Calculatrice` and a keep list saying `Calculator` spares nothing (T4.3).
///
/// Finder is here rather than in `untouchable` because sparing it is a preference, not a rule:
/// force-terminating it only makes macOS start it again.
const keep = ["Finder"]

/// Never Killed, whatever `keep` says.
///
/// Clean has to survive its own run — the Shelf performs Effects in order, so a Kill aimed at
/// Starkit would end the process partway down its own list. The ContextGatherer already makes this
/// unreachable (DESIGN.md §4, F6); this is a deliberate second lock, because the two are on
/// opposite sides of the wire and only one of them is tested.
const untouchable = ["Starkit"]

/// The Kills for a Running Apps list and a keep list.
///
/// Takes its keep list as an argument so the destructive decision can be tested away from anyone's
/// actual preferences — `keep` above is edited per machine.
pub fn kills(running_apps: List(String), keep: List(String)) -> List(Effect) {
  running_apps
  |> list.filter(fn(app) { !is_spared(app, keep) })
  |> list.map(Kill)
}

fn is_spared(app: String, keep: List(String)) -> Bool {
  list.append(untouchable, keep)
  |> list.any(same_application(_, app))
}

/// Whole names, compared without case or surrounding spaces. Both allowances lean the same way —
/// they make keeping more likely, never less — which is the only direction an irreversible Effect
/// may be forgiving in. Prefix or substring matching would also mean nobody can say in advance
/// what a keep list keeps.
fn same_application(one: String, other: String) -> Bool {
  normalise(one) == normalise(other)
}

fn normalise(name: String) -> String {
  name |> string.trim |> string.lowercase
}
