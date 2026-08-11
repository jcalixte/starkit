//// Turns a YouTube URL on the clipboard into a markdown link and pastes it.
////
//// Implemented in T5.2, which adds gleam_fetch and the tests for all six URL shapes. Until then
//// this stub reports itself rather than failing silently, so the Keyword resolves and the
//// Notify path gets exercised end to end.

import starkit.{type Script, Notify, Script}

pub fn script() -> Script {
  Script(
    keyword: "youtube",
    name: "Youtube",
    needs: [],
    run: fn(_input, _context) {
      [Notify("Youtube is not implemented yet (T5.2).")]
    },
  )
}
