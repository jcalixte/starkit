//// Opens everything you need for a working day.
////
//// The app list is deliberately empty here. This file is a stub shipped by the installer; fill it
//// in on your own machine. Nothing in ~/.starkit is ever committed back to the Starkit repo, so
//// the names of your employer's tools stay yours.

import starkit.{type Script, Decides, Script}

pub fn script() -> Script {
  Script(
    keyword: "work",
    name: "Work",
    needs: [],
    asks: Decides,
    run: fn(_input, _context) {
      // One starkit.Open per application, in the order you want them opened — the last one ends up
      // frontmost. For example:
      //
      //   [starkit.Open("Ghostty"), starkit.Open("Slack")]
      []
    },
  )
}
