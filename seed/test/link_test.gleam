//// What `link` gets right about a page, and — the point of this file — where it stops.
////
//// Only the pure half is tested: finding the title in HTML and building the markdown. A test that
//// reaches the web fails on a train, and would check a server's behaviour rather than this one's.
////
//// **The last section pins pages it gets wrong, as they behave rather than as they should.** Fixing
//// them means an HTML parser, which SPEC puts behind Ask first; until then this file is the answer
//// to "how wrong is it".

import scripts/link

// The h1 as pages actually write it.

pub fn a_plain_h1_test() {
  assert link.title_in("<html><body><h1>Getting Started</h1></body></html>")
    == Ok("Getting Started")
}

pub fn attributes_are_not_the_title_test() {
  assert link.title_in("<h1 class=\"title\" id=\"top\">Getting Started</h1>")
    == Ok("Getting Started")
}

pub fn a_closing_tag_with_a_space_in_it_test() {
  assert link.title_in("<h1>Getting Started</h1 >") == Ok("Getting Started")
}

/// Half a title in a `<span>` is the normal case, not an exotic one — every site that styles one
/// word of its heading differently produces this.
pub fn tags_inside_the_title_are_dropped_and_their_text_kept_test() {
  assert link.title_in("<h1><span class=\"a\">Getting</span> Started</h1>")
    == Ok("Getting Started")
}

/// A heading written across three indented lines is one line on the page, so it is one line in the
/// note.
pub fn whitespace_is_collapsed_the_way_a_browser_collapses_it_test() {
  assert link.title_in("<h1>\n    Getting\n    Started\n  </h1>")
    == Ok("Getting Started")
}

pub fn a_non_breaking_space_is_a_space_test() {
  assert link.title_in("<h1>Getting\u{00A0}Started</h1>")
    == Ok("Getting Started")
}

// The entities a title actually contains.

pub fn an_escaped_ampersand_is_an_ampersand_test() {
  assert link.title_in("<h1>Design &amp; Build</h1>") == Ok("Design & Build")
}

pub fn escaped_quotes_and_apostrophes_come_back_test() {
  assert link.title_in("<h1>&quot;Don&#39;t Stop&quot;</h1>")
    == Ok("\"Don't Stop\"")
}

pub fn an_escaped_entity_is_not_decoded_twice_test() {
  assert link.title_in("<h1>Write &amp;lt; in HTML</h1>")
    == Ok("Write &lt; in HTML")
}

pub fn escaped_angle_brackets_come_back_test() {
  assert link.title_in("<h1>Reading &lt;h1&gt; tags</h1>")
    == Ok("Reading <h1> tags")
}

// What it declines. Each of these is a Notify rather than a paste.

pub fn a_page_with_no_h1_test() {
  assert link.title_in("<html><head><title>Only a title</title></head></html>")
    == Error(Nil)
}

pub fn an_empty_h1_test() {
  assert link.title_in("<h1></h1>") == Error(Nil)
}

/// A masthead h1 holding the logo and nothing else. There is no title here, which is the same news
/// as there being no h1.
pub fn an_h1_holding_only_an_image_test() {
  assert link.title_in("<h1><img src=\"logo.svg\" alt=\"Acme\"></h1>")
    == Error(Nil)
}

pub fn an_h1_that_is_never_closed_test() {
  assert link.title_in("<h1>Getting Started") == Error(Nil)
}

/// `<h1group>` is not a h1, and a scan that thought otherwise would paste an attribute.
pub fn a_longer_tag_name_that_starts_the_same_way_test() {
  assert link.title_in("<h1group data-x=\"y\">Nope</h1group><h1>Real</h1>")
    == Ok("Real")
}

pub fn an_empty_page_test() {
  assert link.title_in("") == Error(Nil)
}

// The pages it gets wrong. **These assert the wrong answer on purpose** — if one starts failing,
// the scan has been changed and the change should be deliberate.

/// **The one that matters.** A site whose masthead is a h1 and whose article title is the second
/// one pastes the site's name, and nothing about the result looks like a failure — you find out
/// weeks later, in a note that says "Acme Blog".
pub fn the_first_h1_wins_even_when_the_second_is_the_title_test() {
  assert link.title_in(
      "<header><h1>Acme Blog</h1></header><h1>Getting Started</h1>",
    )
    == Ok("Acme Blog")
}

/// A heading left in a comment during a redesign. A browser never renders it; this reads it.
pub fn a_commented_out_h1_is_read_as_the_title_test() {
  assert link.title_in("<!-- <h1>Old draft</h1> --><h1>Getting Started</h1>")
    == Ok("Old draft")
}

/// Client-rendered sites ship their headings inside a script as data. The first h1 on the page is
/// then not on the page at all.
pub fn an_h1_inside_a_script_is_read_as_the_title_test() {
  assert link.title_in(
      "<script>var tpl = \"<h1>{{title}}</h1>\";</script><h1>Getting Started</h1>",
    )
    == Ok("{{title}}")
}

/// Uppercase tags are legal HTML and this scan does not see them. Rare enough on a modern page to
/// leave alone, and cheap to fix the day it bites: lowercase a copy to search in, and slice the
/// title out of the original.
pub fn an_uppercase_h1_is_not_found_test() {
  assert link.title_in("<H1>Getting Started</H1>") == Error(Nil)
}

/// Six entities are decoded, being the ones a sentence contains. An em dash written as an entity is
/// visible in the note, which is the tell that this is a scan rather than a parser.
pub fn an_entity_outside_the_table_survives_raw_test() {
  assert link.title_in("<h1>Design &mdash; Build</h1>")
    == Ok("Design &mdash; Build")
}

/// A `>` inside an attribute value ends the tag early, as far as a scan is concerned, and the rest
/// of the attribute becomes the front of the title.
pub fn a_greater_than_inside_an_attribute_ends_the_tag_early_test() {
  assert link.title_in("<h1 data-path=\"a>b\">Getting Started</h1>")
    == Ok("b\">Getting Started")
}

// What it will fetch. https and nothing else: this Script writes a page's own heading into a note
// verbatim, and over cleartext that heading is whatever sits between you and the server.

pub fn an_https_url_is_fetchable_test() {
  assert link.fetchable("https://example.com/start")
    == Ok("https://example.com/start")
}

/// Schemes are case-insensitive, so this is an https link and is judged as one. What comes back is
/// what was typed — a URL is not tidied on its way into a note.
pub fn an_uppercase_scheme_is_still_https_test() {
  assert link.fetchable("HTTPS://Example.com/Start")
    == Ok("HTTPS://Example.com/Start")
}

pub fn surrounding_whitespace_is_not_the_url_test() {
  assert link.fetchable("  https://example.com\n") == Ok("https://example.com")
}

pub fn http_is_refused_and_told_why_test() {
  assert link.fetchable("http://example.com")
    == Error("Starkit reads https links only, and that one is http.")
}

/// Every other scheme takes the same sentence, naming itself. `file://` and `data:` are the ones
/// worth thinking about: both would have this Script read something local and paste it.
pub fn another_scheme_is_refused_by_name_test() {
  assert link.fetchable("ftp://example.com/file.txt")
    == Error("Starkit reads https links only, and that one is ftp.")
}

pub fn a_file_url_is_refused_test() {
  assert link.fetchable("file:///Users/someone/notes.html")
    == Error("Starkit reads https links only, and that one is file.")
}

/// A host with no scheme in front of it. Common enough to deserve a message that says the fix
/// rather than one that says "no".
pub fn a_bare_host_is_refused_test() {
  assert link.fetchable("example.com/start")
    == Error("That does not start with https://: \"example.com/start\"")
}

pub fn a_scheme_with_nothing_after_it_is_refused_test() {
  assert link.fetchable("https://")
    == Error("That does not start with https://: \"https://\"")
}

/// `hello world://x` has no scheme rather than one named "hello world" — a refusal that quoted that
/// back would be reporting the wrong problem.
pub fn a_sentence_containing_a_separator_has_no_scheme_test() {
  assert link.fetchable("hello world://x")
    == Error("That does not start with https://: \"hello world://x\"")
}

pub fn prose_is_refused_test() {
  assert link.fetchable("what was that page called")
    == Error("That does not start with https://: \"what was that page called\"")
}

// The note. `[Title](url)`, which is what SPEC asks for and what every Markdown reader takes.

pub fn markdown_is_a_title_and_the_url_it_came_from_test() {
  assert link.markdown("Getting Started", "https://example.com/start")
    == "[Getting Started](https://example.com/start)"
}

/// The same normalisation youtube's titles get, from the same module — a title pasted with curly
/// quotes is a title you later fail to find by typing the straight ones.
pub fn a_title_is_normalised_on_its_way_into_the_note_test() {
  assert link.markdown("Don\u{2019}t Stop \u{2014} Ever", "https://example.com")
    == "[Don't Stop -- Ever](https://example.com)"
}

/// Balanced parentheses in a URL are the common case — every Wikipedia disambiguation has them —
/// and Markdown reads them correctly, so the URL goes in untouched.
pub fn a_url_with_parentheses_is_pasted_as_it_came_test() {
  assert link.markdown(
      "Mercury",
      "https://en.wikipedia.org/wiki/Mercury_(planet)",
    )
    == "[Mercury](https://en.wikipedia.org/wiki/Mercury_(planet))"
}

/// Brackets in a title are left alone. Balanced ones read as link text and an unbalanced one breaks
/// the link — recorded rather than escaped.
pub fn a_title_keeps_its_own_brackets_test() {
  assert link.markdown("[Guide] Getting Started", "https://example.com")
    == "[[Guide] Getting Started](https://example.com)"
}
