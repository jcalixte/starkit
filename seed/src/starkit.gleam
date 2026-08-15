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

import gleam/javascript/promise.{type Promise}

/// Something a Script asks the Shelf to do.
pub type Effect {
  /// Bring an application to the front, launching it if it is not running.
  Open(app: String)

  /// Hand a URL to the machine, which opens it with whatever registered the scheme: a browser for
  /// `https://`, an application for its own, like `obsidian://`. The url must be a full one,
  /// scheme and all — this is a click on a link, not a search.
  Browse(url: String)

  /// Terminate an application without asking it first. Never prompts, never lets the app refuse
  /// or put up a save dialog. This is chosen, not accidental: speed is worth the risk.
  Kill(app: String)

  /// Put text on the clipboard and stop there. Nothing is typed anywhere, so nothing depends on
  /// what was in front — which is what Paste cannot promise. Needs no Accessibility grant.
  Copy(text: String)

  /// Put text on the clipboard, give focus back to whatever was frontmost before the Shelf
  /// appeared, and synthesise the paste keystroke. The text is deliberately left on the clipboard
  /// afterwards, so it can be pasted again by hand. Copy is this without the keystroke.
  Paste(text: String)

  /// Show a message in the bar. The only way a Script reports anything, including failure.
  Notify(message: String)
}

/// A slice of machine state a Script needs in order to decide. Scripts cannot read the machine
/// themselves, so anything they need has to be declared up front and gathered by the Shelf.
pub type Need {
  /// The applications currently running, as their names.
  RunningApps
}

/// What the Shelf gathered, for the Needs a Script declared.
///
/// Fields for undeclared Needs hold their empty value rather than being absent, so a Script that
/// forgot to declare a Need sees nothing rather than failing to compile — which is why the Kill
/// list is tested (SPEC.md § Testing strategy).
pub type Context {
  Context(running_apps: List(String))
}

/// Whether a Script asks the person for something before it can decide.
///
/// Declared rather than inferred, because the Shelf has to know before the Script runs: a Script
/// that Asks gets an Input stage in the bar, Seeded from the clipboard and arriving selected, and
/// one that Decides never does.
pub type Asking {
  /// Decides from the Context and nothing else. Never Seeded. `run` still receives an Input, and
  /// it is always empty unless someone typed one after the Keyword anyway.
  Decides

  /// Asks for one line. The label is what the empty field shows — a question in the bar's own
  /// voice, so `Asks(for: "YouTube URL")` reads as one in the place a person is about to answer it.
  Asks(for: String)
}

/// One Script: a Keyword to summon it by, the other Keywords it answers to, a name to show, the Needs it
/// declares, whether it Asks, and the decision itself.
///
/// `run` receives the Input typed after the Keyword — empty when nothing was typed — and returns
/// the Effects to perform. It may reach the network on its own; it may never touch the machine.
///
/// Two constructors because there is no synchronous HTTP on this target. Write `Script` unless you
/// reach the network.
pub type Script {
  Script(
    keyword: String,
    name: String,
    /// Further Keywords this Script answers to, like `["yt"]` for `youtube` — shorthand, not a key
    /// binding. The `keyword` above stays the canonical one because it is the module name; these are
    /// not file names, so they may be anything you would type, and an empty list is the normal case.
    /// Matching prefers an exact `keyword`, then an exact one of these, then a `keyword` prefix, then
    /// a prefix of these — so a two-letter shorthand cannot shadow a Keyword someone typed in full.
    other_keywords: List(String),
    needs: List(Need),
    asks: Asking,
    run: fn(String, Context) -> List(Effect),
  )

  /// A Script that reaches the network before it can decide. The Shelf awaits it and is otherwise
  /// indifferent: the same Effects arrive, and a Fetching Script is under the same 5 s deadline as
  /// any other, because a fetch that never returns is what that deadline is for.
  Fetching(
    keyword: String,
    name: String,
    other_keywords: List(String),
    needs: List(Need),
    asks: Asking,
    run: fn(String, Context) -> Promise(List(Effect)),
  )
}

/// The Context a Script sees when it declared no Needs.
pub fn empty_context() -> Context {
  Context(running_apps: [])
}
