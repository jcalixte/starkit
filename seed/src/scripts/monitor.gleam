//// Puts the second screen where it physically stands, so the pointer leaves by the edge it looks
//// like it should.
////
//// macOS remembers an arrangement per set of screens, so this is wanted the first time a screen is
//// plugged in rather than every time: run it once at a new desk and that desk stays right.

import gleam/string
import starkit.{
  type Effect, type Script, Bottom, Decides, Left, Notify, Right, Script, Seat,
  Top,
}

pub fn script() -> Script {
  Script(
    keyword: "monitor",
    name: "Monitor arrangement",
    other_keywords: ["mon"],
    needs: [],
    asks: Decides,
    run: fn(input, _context) { seats(input) },
  )
}

/// `monitor left` seats the screen on the left. A word that is not a side is a Notify rather than a
/// guess: a Seat is remembered, so the wrong one is an arrangement to drag back by hand.
///
/// Which screen moves is the Shelf's to decide and not this Script's — there is one screen that is
/// not the main one, or there is a Refusal saying why not.
pub fn seats(input: String) -> List(Effect) {
  case string.lowercase(string.trim(input)) {
    "left" | "l" -> [Seat(Left)]
    "top" | "t" | "above" -> [Seat(Top)]
    "right" | "r" -> [Seat(Right)]
    "bottom" | "b" | "below" -> [Seat(Bottom)]
    "" -> [Notify("monitor takes a side: left, top, right or bottom.")]
    typed -> [
      Notify(
        "\"" <> typed <> "\" is not a side. Try left, top, right or bottom.",
      ),
    ]
  }
}
