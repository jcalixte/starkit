//// Text on its way into a note, spelled the way the notes already spell it.
////
//// Vendored into ~/.starkit and overwritten on every install, exactly like starkit.gleam — and not
//// the Vocabulary. Nothing here crosses the boundary or touches the machine: these are functions a
//// Script may call while it is deciding, and the Shelf never learns that it did. Kept out of
//// starkit.gleam for that reason, so that module can go on being only the interface between a
//// Script and the Shelf.
////
//// It exists because `normalise` acquired a second caller. It was youtube's alone at T5.2, where
//// the comment above it said this decision was worth making with the second caller in hand rather
//// than on a guess; `link` is that caller. The alternative was a copy in each Script, which puts
//// two versions of a mapping whose entire purpose is that every note agrees — an em dash becoming
//// two hyphens in one file and one hyphen in the other is precisely the split it exists to prevent.
////
//// What it costs is Script isolation, which is otherwise total: a Script that does not compile
//// takes only itself down (T1.6). Every Script importing this one shares its fate. That is
//// acceptable here and would not be for a module anyone edits — this one is the Shelf's, replaced
//// wholesale on install, and it is seven string replacements with no dependencies of its own.

import gleam/string

/// Typographic punctuation, flattened to what a keyboard types.
///
/// A title arrives however the page spells it, and one pasted with curly quotes is a title you
/// later fail to find by typing the straight ones. The mapping is the Script Kit lib's, character
/// for character, including an em dash becoming two hyphens rather than one — that is what the
/// existing notes contain, and a normaliser that disagreed with them would split the set it exists
/// to unify.
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
