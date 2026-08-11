//// Turns a URL into `[Title](url)` by reading the page's h1, and pastes it.
////
//// Implemented in T6.1. Same stub shape as youtube.gleam.

import starkit.{type Script, Notify, Script}

pub fn script() -> Script {
  Script(
    keyword: "link",
    name: "Link from url",
    needs: [],
    run: fn(_input, _context) {
      [Notify("Link is not implemented yet (T6.1).")]
    },
  )
}
