//// Turns a YouTube link into the note a video gets written down as, and pastes it.
////
//// The shape of the note is carried over from the Script Kit script this replaces, not designed
//// here: notes written before today and after it have to read as one set. `@[youtube](<id>)` is an
//// embed the note-taking side understands, which is why the ID appears alone rather than in a URL.
////
//// oEmbed rather than scraping the watch page — a documented endpoint answering JSON with no key,
//// so the title arrives decoded rather than extracted from HTML.

import gleam/dynamic/decode
import gleam/fetch
import gleam/http/request
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import starkit.{type Effect, type Script, Asks, Fetching, Notify, Paste}
import text

pub fn script() -> Script {
  Fetching(
    keyword: "youtube",
    name: "Youtube",
    other_keywords: ["yt"],
    needs: [],
    asks: Asks(for: "YouTube URL"),
    run: fn(input, _context) { decide(input) },
  )
}

/// The characters a YouTube ID is made of, and nothing else. Base64url, which is why `-` and `_`
/// are in and `+` and `/` are not.
const id_characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

/// How long a YouTube ID is. Eleven, always, and checking it is what stops a truncated paste from
/// becoming a link to nothing.
const id_length = 11

/// The one marker per URL shape. Order matters only in that the first to yield eleven valid
/// characters wins; no real URL carries two of these.
const path_markers = ["youtu.be/", "/shorts/", "/embed/", "/live/", "/v/"]

/// What oEmbed says a video is, which is all this Script asks it.
type Video {
  Video(title: String, channel: String)
}

fn decide(input: String) -> Promise(List(Effect)) {
  case video_id(input) {
    Error(_) -> promise.resolve([Notify(nothing_to_go_on(input))])
    Ok(id) -> {
      use found <- promise.map(video_of(id))
      case found {
        Ok(video) -> [Paste(markdown(video.title, video.channel, id))]
        Error(why) -> [Notify(why)]
      }
    }
  }
}

/// The video ID in whatever a person pasted, or nothing. A wrong ID is the failure that does not
/// look like one — it pastes a working link to the wrong video.
pub fn video_id(input: String) -> Result(String, Nil) {
  let trimmed = string.trim(input)
  case is_id(trimmed) {
    True -> Ok(trimmed)
    False -> from_url(trimmed)
  }
}

/// The note a video is written down as: an embed, a blank line, then the title and the channel.
///
/// Every URL shape collapses to an ID because three spellings of one video are three things to
/// search for. The cost is the timestamp — `?t=42` has nowhere to go in this shape.
///
/// The title is normalised and the channel is not, carried over rather than decided.
pub fn markdown(title: String, channel: String, id: String) -> String {
  "@[youtube](" <> id <> ")\n\n- " <> text.normalise(title) <> " | " <> channel
}

fn from_url(url: String) -> Result(String, Nil) {
  let #(path, query) =
    url
    |> before("#")
    |> split_at("?")

  let path = after_scheme(path)
  case is_youtube(host_of(path)) {
    False -> Error(Nil)
    True ->
      from_query(query)
      |> result.lazy_or(fn() { from_path(path) })
      |> result.try(confirm)
  }
}

/// The `v` parameter, read as a parameter rather than as text.
///
/// Looking for `v=` in the query as a string finds it inside `sv=` too, and pastes that value as a
/// video ID. Splitting on `&` first is what makes the name a name.
fn from_query(query: String) -> Result(String, Nil) {
  query
  |> string.split("&")
  |> list.find_map(fn(pair) {
    case string.split_once(pair, "=") {
      Ok(#("v", value)) -> Ok(value)
      _ -> Error(Nil)
    }
  })
}

fn from_path(path: String) -> Result(String, Nil) {
  list.find_map(path_markers, fn(marker) {
    case string.split_once(path, marker) {
      Ok(#(_, rest)) -> Ok(before(rest, "/"))
      Error(_) -> Error(Nil)
    }
  })
}

/// Only YouTube's own hosts, so `example.com/embed/<11 chars>` is not read as a video.
///
/// Matched loosely on purpose: `youtu.be`, `youtube.com`, `m.`, `www.` and `music.` are all real,
/// and enumerating them goes stale. The ID is validated either way, which is the check that
/// actually protects the paste.
fn is_youtube(host: String) -> Bool {
  string.contains(host, "youtu")
}

fn host_of(path: String) -> String {
  before(path, "/")
}

fn after_scheme(url: String) -> String {
  case string.split_once(url, "://") {
    Ok(#(_, rest)) -> rest
    Error(_) -> url
  }
}

fn before(text: String, separator: String) -> String {
  case string.split_once(text, separator) {
    Ok(#(start, _)) -> start
    Error(_) -> text
  }
}

fn split_at(text: String, separator: String) -> #(String, String) {
  case string.split_once(text, separator) {
    Ok(#(start, rest)) -> #(start, rest)
    Error(_) -> #(text, "")
  }
}

fn confirm(candidate: String) -> Result(String, Nil) {
  case is_id(candidate) {
    True -> Ok(candidate)
    False -> Error(Nil)
  }
}

fn is_id(candidate: String) -> Bool {
  string.length(candidate) == id_length
  && candidate
  |> string.to_graphemes
  |> list.all(fn(character) { string.contains(id_characters, character) })
}

/// Ask YouTube what the video is and who made it. Every failure arrives as a sentence rather than a
/// code, because the only place it can be shown is a Notify in the bar.
fn video_of(id: String) -> Promise(Result(Video, String)) {
  case request.to(oembed_url(id)) {
    Error(_) ->
      promise.resolve(Error("Starkit could not build a request for that ID."))
    Ok(asked) -> {
      use sent <- promise.await(fetch.send(asked))
      case sent {
        // Offline, DNS, TLS, a captive portal — indistinguishable from here.
        Error(_) -> promise.resolve(Error("YouTube is not reachable."))
        Ok(response) -> {
          use read <- promise.await(fetch.read_text_body(response))
          promise.resolve(case read {
            Error(_) -> Error("YouTube's answer could not be read.")
            Ok(body) -> video_in(body.status, body.body)
          })
        }
      }
    }
  }
}

/// `author_name` is oEmbed's word for the channel. Both fields are required rather than optional: a
/// note missing half its line is worse than a Notify saying so.
fn video_decoder() -> decode.Decoder(Video) {
  use title <- decode.field("title", decode.string)
  use channel <- decode.field("author_name", decode.string)
  decode.success(Video(title:, channel:))
}

/// oEmbed wants the watch URL as a parameter, so it arrives percent-encoded inside one.
fn oembed_url(id: String) -> String {
  "https://www.youtube.com/oembed?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D"
  <> id
  <> "&format=json"
}

fn video_in(status: Int, body: String) -> Result(Video, String) {
  case status {
    200 ->
      json.parse(body, video_decoder())
      |> result.replace_error("YouTube answered without a title.")
    // oEmbed answers 400 to an ID that is the right shape and belongs to nothing, which is the same
    // news as 404 from where a person is standing. None of these say which, so neither does this.
    400 | 401 | 403 | 404 ->
      Error("That video is private, deleted, or not a video at all.")
    other -> Error("YouTube answered " <> int.to_string(other) <> ".")
  }
}

fn nothing_to_go_on(input: String) -> String {
  case string.trim(input) {
    "" -> "Paste a YouTube link, or type one after the Keyword."
    typed ->
      "That does not look like a YouTube link or an ID: "
      <> string.inspect(typed)
  }
}
