//// Turns a URL into `[Title](url)` by reading the page's h1, and pastes it.
////
//// There is no oEmbed for the general web, so the title is found by **scanning** HTML rather than
//// parsing it — a stand-in for a DOM selector that gets some pages wrong. Those pages are in the
//// test suite, pinned rather than fixed: fixing them means an HTML parser, which is a dependency
//// and a decision (SPEC, Ask first).

import gleam/fetch
import gleam/http/request
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/list
import gleam/result
import gleam/string
import starkit.{type Effect, type Script, Asks, Fetching, Notify, Paste}
import text

pub fn script() -> Script {
  Fetching(
    keyword: "link",
    name: "Link from url",
    other_keywords: [],
    needs: [],
    asks: Asks(for: "URL"),
    run: fn(input, _context) { decide(input) },
  )
}

fn decide(input: String) -> Promise(List(Effect)) {
  case string.trim(input) {
    "" ->
      promise.resolve([Notify("Paste a URL, or type one after the Keyword.")])
    typed ->
      case fetchable(typed) {
        Error(why) -> promise.resolve([Notify(why)])
        Ok(url) -> {
          use fetched <- promise.map(page_at(url))
          case fetched {
            Error(why) -> [Notify(why)]
            Ok(html) ->
              case title_in(html) {
                Ok(title) -> [Paste(markdown(title, url))]
                Error(_) -> [Notify("That page has no h1 for Starkit to read.")]
              }
          }
        }
      }
  }
}

/// The URL this Script will fetch, or the sentence saying why it will not.
///
/// **https and nothing else.** A title read over cleartext is a title anything between you and the
/// server can choose, and it is written into a note verbatim and trusted from then on — nothing
/// downstream can tell a page's own heading from one inserted on the way.
///
/// The URL comes back exactly as typed, uppercase scheme and all: `HTTPS://` is judged the same as
/// `https://`, but what goes into the note is what was copied.
pub fn fetchable(input: String) -> Result(String, String) {
  let url = string.trim(input)

  case scheme_of(url) {
    Ok("https") -> Ok(url)
    Ok(other) ->
      Error("Starkit reads https links only, and that one is " <> other <> ".")
    Error(_) ->
      Error("That does not start with https://: " <> string.inspect(url))
  }
}

/// The scheme, lowercased, when there is one and it is spelled like a scheme.
///
/// Letters, digits and `+-.` only, so `hello world://x` has no scheme rather than one named after
/// the sentence. Something must follow the `://` too: `https://` alone is a scheme and no page.
fn scheme_of(url: String) -> Result(String, Nil) {
  use #(scheme, rest) <- result.try(string.split_once(url, "://"))
  let scheme = string.lowercase(scheme)

  case scheme != "" && rest != "" && spelled_like_a_scheme(scheme) {
    True -> Ok(scheme)
    False -> Error(Nil)
  }
}

fn spelled_like_a_scheme(scheme: String) -> Bool {
  scheme
  |> string.to_graphemes
  |> list.all(fn(character) { string.contains(scheme_characters, character) })
}

const scheme_characters = "abcdefghijklmnopqrstuvwxyz0123456789+-."

/// The link a page is written down as.
///
/// The URL goes in as it was given, not as the server finally answered it — a redirect is followed
/// by the runtime and never surfaces here, so a shortened link pastes short.
///
/// Brackets in a title are left alone: `[Guide] How to` pastes as `[[Guide] How to](url)`, which
/// Markdown readers accept while they are balanced and an unbalanced one breaks. A known limit, not
/// escaped, because a backslash is a cost paid by every title to protect a rare one.
pub fn markdown(title: String, url: String) -> String {
  "[" <> text.normalise(title) <> "](" <> url <> ")"
}

/// The text of the page's first h1, cleaned up the way a browser would show it.
///
/// Nothing here is a parser: it finds `<h1`, takes what is between that tag and its closer, drops
/// tags inside, decodes a handful of entities, and squeezes whitespace.
pub fn title_in(html: String) -> Result(String, Nil) {
  use inside <- result.try(first_h1(html))

  case
    inside
    |> without_tags
    |> decoded
    |> squeezed
  {
    // A h1 holding only a logo, or nothing at all — the same news as there being no h1.
    "" -> Error(Nil)
    title -> Ok(title)
  }
}

/// What sits between the first `<h1…>` and its `</h1`.
///
/// The first, not the best: a page whose masthead is a h1 and whose article title is the second one
/// pastes the site's name and looks like a success. A known limit, pinned in the tests.
fn first_h1(html: String) -> Result(String, Nil) {
  use #(_, after_name) <- result.try(string.split_once(html, "<h1"))

  case ends_the_name(after_name) {
    // `<h1group` and friends — keep looking, from just past the false start.
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

/// The entities a page title actually contains, and no more. Anything else — `&mdash;`, `&eacute;`,
/// a numeric escape — survives raw and is visible in the note.
///
/// **`&amp;` must be decoded last.** Doing it first turns `&amp;lt;` into `&lt;` and then into a
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

/// The whitespace a browser collapses, collapsed — a title written across three indented lines is
/// one line on the page and has to be one line in the note.
///
/// A literal non-breaking space goes with them: it looks like a space and is not one, so a title
/// pasted with it is a title you later fail to find by typing a space.
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

/// Ask the page for itself. Every failure arrives as a sentence rather than a code, because the
/// only place it can be shown is a Notify in the bar.
fn page_at(url: String) -> Promise(Result(String, String)) {
  case request.to(url) {
    // Nearly unreachable — `fetchable` has already refused anything without an https scheme. What
    // is left is a URL with an https scheme and something wrong further along: a space in the host,
    // a port that is not a number.
    Error(_) -> promise.resolve(Error("Starkit could not read that as a URL."))
    Ok(asked) -> {
      use sent <- promise.await(fetch.send(asked))
      case sent {
        // Offline, DNS, TLS, a captive portal, a server refusing a request with no browser behind
        // it — indistinguishable from here.
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
