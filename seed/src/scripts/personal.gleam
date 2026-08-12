//// Opens everything you need outside work.
////
//// A stub, like work.gleam — fill in your own app list on your own machine.

import starkit.{type Script, Decides, Script}

pub fn script() -> Script {
  Script(
    keyword: "personal",
    name: "Personal",
    needs: [],
    asks: Decides,
    run: fn(_input, _context) {
      // See work.gleam for the shape.
      []
    },
  )
}
