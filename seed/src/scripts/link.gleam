//// Turns a URL into `[Title](url)` by reading the page's h1, and pastes it.
////
//// The second Fetching Script, and the one that has to guess. Youtube asks oEmbed a question and
//// is told the answer; there is no such endpoint for the rest of the web, so the title here is
//// found by scanning HTML for the tag it is usually in — which is a stand-in for a DOM selector
//// and gets some pages wrong. The pages it gets wrong are in the test suite, pinned rather than
//// fixed: fixing them means an HTML parser, which is a dependency and a decision (SPEC, Ask
//// first), and knowing exactly where the limit sits is worth more than pretending it is elsewhere.
////
//// Scanned rather than matched with a regexp, which is the word SPEC and plan both used. Gleam's
//// stdlib has no regexp, so that word was a sixth dependency resolved on every install for three
//// calls to `string.split_once` — and the pages that come out wrong are the same either way,
//// because the limit is "not a DOM parser" rather than "not a regexp". Same technique youtube
//// already uses to read six URL shapes.

import gleam/fetch
import gleam/http/request
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/result
import gleam/string
import starkit.{type Effect, type Script, Asks, Fetching, Notify, Paste}
import text

pub fn script() -> Script {
  Fetching(
    keyword: "link",
    name: "Link from url",
    needs: [],
    // Answered from the clipboard nearly always: a URL is the one thing that is already there when
    // you reach for this Script, which is what the Seed arriving selected is for.
    asks: Asks(for: "URL"),
    run: fn(input, _context) { decide(input) },
  )
}

fn decide(input: String) -> Promise(List(Effect)) {
  case string.trim(input) {
    "" ->
      promise.resolve([Notify("Paste a URL, or type one after the Keyword.")])
    url -> {
      use fetched <- promise.map(page_at(url))
      case fetched {
        Error(why) -> [Notify(why)]
        Ok(html) ->
          case title_in(html) {
            Ok(title) -> [Paste(markdown(title, url))]
            Error(_) -> [
              Notify("That page has no h1 for Starkit to read."),
            ]
          }
      }
    }
  }
}

/// The link a page is written down as.
///
/// The URL goes in as it was given, not as the server finally answered it: a redirect is followed
/// by the runtime and never surfaces here, so a shortened link pastes short. That is the honest
/// answer anyway — what was copied is what gets pasted — and it is the only URL this Script is ever
/// certain of.
///
/// Brackets in a title are left alone, as they are in youtube's note. `[Guide] How to` pastes as
/// `[[Guide] How to](url)`, which every Markdown reader takes as link text containing brackets so
/// long as they are balanced; an unbalanced one breaks the link. Recorded as a limit rather than
/// escaped, because a backslash in a note is a cost paid by every title to protect a rare one.
pub fn markdown(title: String, url: String) -> String {
  "[" <> text.normalise(title) <> "](" <> url <> ")"
}

/// The text of the page's first h1, cleaned up the way a browser would show it.
///
/// Public because this is the half worth testing, and the half that guesses. Nothing here is a
/// parser: it finds `<h1`, takes what is between that tag and its closer, drops any tags inside,
/// turns the handful of entities a title actually contains back into characters, and squeezes the
/// whitespace HTML would have collapsed anyway.
pub fn title_in(html: String) -> Result(String, Nil) {
  use inside <- result.try(first_h1(html))

  case
    inside
    |> without_tags
    |> decoded
    |> squeezed
  {
    // A h1 holding only a logo, or nothing at all. There is no title on this page, which is the
    // same news as there being no h1 and gets the same answer.
    "" -> Error(Nil)
    title -> Ok(title)
  }
}

/// What sits between the first `<h1…>` and its `</h1`.
///
/// The first, not the best: a page whose masthead is a h1 and whose article title is the second one
/// pastes the site's name, and it looks like a success. That is the known limit of a scan standing
/// in for a selector, and it is in the tests.
fn first_h1(html: String) -> Result(String, Nil) {
  use #(_, after_name) <- result.try(string.split_once(html, "<h1"))

  case ends_the_name(after_name) {
    // `<h1group` and friends. Not this tag — keep looking, from just past the false start.
    False -> first_h1(after_name)
    True -> {
      use #(_attributes, inside) <- result.try(string.split_once(
        after_name,
        ">",
      ))
      use #(title, _) <- result.try(string.split_once(inside, "</h1"))
      Ok(title)
    }
  }
}

/// Whether a tag name has ended, given what follows it. `<h1>`, `<h1 class=…>` and `<h1/>` are the
/// tag; anything else is a longer name that merely starts the same way.
fn ends_the_name(rest: String) -> Bool {
  case string.first(rest) {
    Ok(">") | Ok(" ") | Ok("\n") | Ok("\r") | Ok("\t") | Ok("/") -> True
    _ -> False
  }
}

/// Every `<…>` removed and everything between them kept, which is what a title with a `<span>`
/// around half of it needs. An unclosed tag takes the rest of the text with it, on the grounds that
/// the alternative is pasting markup.
fn without_tags(html: String) -> String {
  case string.split_once(html, "<") {
    Error(_) -> html
    Ok(#(before, rest)) ->
      case string.split_once(rest, ">") {
        Error(_) -> before
        Ok(#(_tag, after)) -> before <> without_tags(after)
      }
  }
}

/// The entities a page title actually contains, and no more.
///
/// Six of them, because a title is a sentence rather than a document: an ampersand, the two angle
/// brackets, two spellings of an apostrophe, a quote and a non-breaking space. Anything else —
/// `&mdash;`, `&eacute;`, a numeric escape — survives raw and is visible in the note, which is the
/// tell that this is a scan rather than a parser.
///
/// `&amp;` is decoded last on purpose. Doing it first turns `&amp;lt;` into `&lt;` and then into a
/// literal `<`, which is a page's escaped text quietly becoming markup.
fn decoded(text: String) -> String {
  text
  |> string.replace("&lt;", "<")
  |> string.replace("&gt;", ">")
  |> string.replace("&quot;", "\"")
  |> string.replace("&apos;", "'")
  |> string.replace("&#39;", "'")
  |> string.replace("&nbsp;", " ")
  |> string.replace("&amp;", "&")
}

/// The whitespace a browser collapses, collapsed. A title written across three indented lines is
/// one line on the page and has to be one line in the note.
///
/// A literal non-breaking space goes with them. It looks like a space in the note and is not one,
/// so a title pasted with it is a title you later fail to find by typing a space.
fn squeezed(text: String) -> String {
  text
  |> string.replace("\n", " ")
  |> string.replace("\r", " ")
  |> string.replace("\t", " ")
  |> string.replace("\u{00A0}", " ")
  |> single_spaced
  |> string.trim
}

fn single_spaced(text: String) -> String {
  case string.contains(text, "  ") {
    False -> text
    True -> single_spaced(string.replace(text, "  ", " "))
  }
}

/// Ask the page for itself.
///
/// Every failure arrives as a sentence rather than a code, because the only place it can be shown
/// is a Notify in the bar and there is nowhere to look anything up from there.
fn page_at(url: String) -> Promise(Result(String, String)) {
  case request.to(url) {
    Error(_) -> promise.resolve(Error("Starkit could not read that as a URL."))
    Ok(asked) -> {
      use sent <- promise.await(fetch.send(asked))
      case sent {
        // Offline, DNS, TLS, a captive portal, a server refusing a request with no browser behind
        // it — indistinguishable from here, and the answer is the same in all of them.
        Error(_) -> promise.resolve(Error("That page is not reachable."))
        Ok(response) -> {
          use read <- promise.await(fetch.read_text_body(response))
          promise.resolve(case read {
            Error(_) -> Error("That page could not be read as text.")
            Ok(body) ->
              case body.status {
                status if status >= 200 && status < 300 -> Ok(body.body)
                404 -> Error("There is no page at that URL.")
                401 | 403 -> Error("That page will not answer Starkit.")
                other ->
                  Error("That site answered " <> int.to_string(other) <> ".")
              }
          })
        }
      }
    }
  }
}
