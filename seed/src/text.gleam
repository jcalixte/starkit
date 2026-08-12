//// Text on its way into a note, spelled the way the notes already spell it.
////
//// Vendored into ~/.starkit and overwritten on every install, like starkit.gleam — but not the
//// Vocabulary. Nothing here crosses the boundary or touches the machine, which is why it is kept
//// out of starkit.gleam: that module is only the interface between a Script and the Shelf.
////
//// The cost is Script isolation, which is otherwise total (T1.6): every Script importing this one
//// shares its fate. Acceptable only because this module is the Shelf's, replaced wholesale on
//// install, and has no dependencies of its own.

import gleam/string

/// Typographic punctuation, flattened to what a keyboard types. A title pasted with curly quotes is
/// a title you later fail to find by typing the straight ones.
///
/// **Must stay character-for-character the Script Kit lib's mapping**, including an em dash becoming
/// two hyphens rather than one: that is what the existing notes contain, and a normaliser that
/// disagreed with them would split the set it exists to unify.
pub fn normalise(text: String) -> String {
  text
  |> string.replace("\u{2018}", "'")
  |> string.replace("\u{2019}", "'")
  |> string.replace("\u{201C}", "\"")
  |> string.replace("\u{201D}", "\"")
  |> string.replace("\u{2013}", "-")
  |> string.replace("\u{2014}", "--")
  |> string.replace("\u{2026}", "...")
}
