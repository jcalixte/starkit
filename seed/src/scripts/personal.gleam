//// Opens everything you need outside work.
////
//// Empty for the same reason as work.gleam: this is a stub, and your app list is yours.

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
