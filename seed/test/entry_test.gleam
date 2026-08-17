//// The wire, from this side of it.
////
//// The Shelf decodes what this module writes, and nothing generates either half from the other. The
//// string below is therefore the contract: it is character for character the reply
//// `EffectTests.everyKind` decodes in the Swift half, and a change to one of them that is not made
//// to the other is a Script that Refuses at the moment somebody presses ↩.

import entry
import gleam/string
import starkit.{Browse, Copy, Kill, Notify, Open, Paste}

/// Every word of the Effect vocabulary, each under the field name the Vocabulary gave it. `Open` and
/// `Browse` both carry one string, so the field name is the second lock behind the kind.
pub fn every_effect_crosses_the_wire_under_its_own_field_name_test() {
  assert entry.encode([
      Open("Slack"),
      Browse("https://gleam.run"),
      Kill("Notion"),
      Copy("kept"),
      Paste("hello"),
      Notify("nothing to do"),
    ])
    == "{\"effects\":[{\"kind\":\"open\",\"app\":\"Slack\"},{\"kind\":\"browse\",\"url\":\"https://gleam.run\"},{\"kind\":\"kill\",\"app\":\"Notion\"},{\"kind\":\"copy\",\"text\":\"kept\"},{\"kind\":\"paste\",\"text\":\"hello\"},{\"kind\":\"notify\",\"message\":\"nothing to do\"}]}"
}

/// A Script that decided on nothing is not a Script that Refused, and the two shapes are told apart
/// by which key is there.
pub fn deciding_on_nothing_is_an_empty_list_and_not_a_refusal_test() {
  assert entry.encode([]) == "{\"effects\":[]}"
}

/// Arbitrary text crosses in both directions — a page title into Paste, a compiler's words into
/// Notify — so escaping is a correctness problem rather than a formatting one.
pub fn text_that_would_break_the_json_is_escaped_test() {
  assert entry.encode([Notify("she said \"go\"\nthen left")])
    == "{\"effects\":[{\"kind\":\"notify\",\"message\":\"she said \\\"go\\\"\\nthen left\"}]}"
}

/// The Manifest half of the same contract, checked by field name rather than whole: adding a Script
/// to the seed must not be a failing test, but renaming a field must be.
pub fn a_manifest_carries_the_field_names_the_shelf_reads_test() {
  let manifests = entry.describe()

  assert string.contains(manifests, "\"keyword\":\"youtube\"")
  assert string.contains(manifests, "\"other_keywords\":[\"yt\"]")
  assert string.contains(manifests, "\"needs\":[\"running_apps\"]")
  // Null and not "", which is a question a Script could plausibly have meant.
  assert string.contains(manifests, "\"asks\":null")
}
