//// Normalisation, character for character as the Script Kit lib had it. These pin the seven
//// replacements for every Script that calls `text.normalise`, not just one.

import text

pub fn curly_single_quotes_become_straight_test() {
  assert text.normalise("\u{2018}quoted\u{2019}") == "'quoted'"
}

pub fn curly_double_quotes_become_straight_test() {
  assert text.normalise("\u{201C}quoted\u{201D}") == "\"quoted\""
}

pub fn an_en_dash_becomes_one_hyphen_test() {
  assert text.normalise("a \u{2013} b") == "a - b"
}

/// Two hyphens, not one. That is what the existing notes contain, and a normaliser that disagreed
/// with them would split the set it exists to unify.
pub fn an_em_dash_becomes_two_hyphens_test() {
  assert text.normalise("a \u{2014} b") == "a -- b"
}

pub fn an_ellipsis_becomes_three_dots_test() {
  assert text.normalise("wait\u{2026}") == "wait..."
}

pub fn plain_text_is_untouched_test() {
  assert text.normalise("Rick Astley - Never Gonna Give You Up (4K)")
    == "Rick Astley - Never Gonna Give You Up (4K)"
}
