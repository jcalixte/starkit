//// The Vocabulary.
////
//// This module is the whole interface between a Script and the Shelf. A Script decides *what*
//// should happen by returning Effects; the Shelf decides *how*, and is the only side that may
//// touch the machine. Nothing else crosses the boundary — there is no escape hatch, by design,
//// because every capability the Shelf holds is a permission the user had to grant once.
////
//// It is vendored into ~/.starkit and overwritten on every install. Do not edit it there; edit
//// seed/src/starkit.gleam in the Starkit repo. Your own Scripts live in src/scripts/ and are
//// never overwritten.

/// Something a Script asks the Shelf to do.
///
/// The Vocabulary is closed but not frozen: it may grow, and each addition is a decision rather
/// than a convenience. Two Scripts wanting the same new Effect is coincidence; three is a signal.
pub type Effect {
  /// Bring an application to the front, launching it if it is not running.
  Open(app: String)

  /// Terminate an application without asking it first. Never prompts, never lets the app refuse
  /// or put up a save dialog. This is chosen, not accidental: speed is worth the risk.
  Kill(app: String)

  /// Put text on the clipboard, give focus back to whatever was frontmost before the Shelf
  /// appeared, and synthesise the paste keystroke. The text is deliberately left on the clipboard
  /// afterwards, so it can be pasted again by hand.
  Paste(text: String)

  /// Show a message in the bar. The only way a Script reports anything, including failure.
  Notify(message: String)
}

/// A slice of machine state a Script needs in order to decide.
///
/// Scripts cannot read the machine themselves, so anything they need to know has to be declared
/// up front and gathered by the Shelf. Declaring it also means the Shelf can skip the work when
/// nothing asks for it.
pub type Need {
  /// The applications currently running, as their names.
  RunningApps
}

/// What the Shelf gathered, for the Needs a Script declared.
///
/// Fields for undeclared Needs hold their empty value rather than being absent — a Script that
/// forgot to declare a Need sees nothing rather than failing to compile, which is why the Kill
/// list is tested (SPEC.md § Testing strategy).
pub type Context {
  Context(running_apps: List(String))
}

/// One Script: a Keyword to summon it by, a name to show, the Needs it declares, and the
/// decision itself.
///
/// `run` receives the Input typed after the Keyword — empty when nothing was typed — and returns
/// the Effects to perform. It may reach the network on its own; it may never touch the machine.
pub type Script {
  Script(
    keyword: String,
    name: String,
    needs: List(Need),
    run: fn(String, Context) -> List(Effect),
  )
}

/// The Context a Script sees when it declared no Needs.
pub fn empty_context() -> Context {
  Context(running_apps: [])
}
