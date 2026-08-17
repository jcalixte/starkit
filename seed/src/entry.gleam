//// The entry point the Shelf invokes.
////
//// Two verbs, and no state between them:
////
////   describe                  → every manifest, for the Catalogue to cache in manifests.json
////   run <keyword> <payload>   → the Effects one Script decided on
////
//// `describe` is a separate verb because the Catalogue must know the catalogue without building or
//// running anything (F2), and it answers with a bare array because it reads the registry and cannot
//// Refuse. `run` answers with a JSON object instead, because it can answer with a Refusal in place
//// of Effects — carrying both shapes in one object is what keeps the Shelf's decode total.
////
//// This file is Shelf-owned: vendored into ~/.starkit and overwritten on every install.

import gleam/dynamic/decode.{type Decoder}
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import registry
import starkit.{
  type Asking, type Context, type Effect, type Need, type Script, Asks, Browse,
  Context, Copy, Decides, Fetching, Kill, Notify, Open, Paste, RunningApps,
  Script,
}

/// Every Script's Manifest, as JSON.
pub fn describe() -> String {
  registry.all() |> json.array(of: manifest) |> json.to_string
}

/// Run the Script with this Keyword against the payload the Shelf gathered.
///
/// A Promise even when nothing here is asynchronous, because one kind of Script is: Gleam cannot
/// return a String down one branch and a Promise down another, so the synchronous case is resolved
/// into the wider of the two.
pub fn run(keyword: String, payload: String) -> Promise(String) {
  case find(keyword) {
    Error(why) -> promise.resolve(refusal(why))
    Ok(script) ->
      case json.parse(payload, payload_decoder()) {
        Error(_) ->
          promise.resolve(refusal(
            "The payload for \""
            <> keyword
            <> "\" is not the shape the Shelf promised.",
          ))
        Ok(#(input, context)) -> decide(script, input, context)
      }
  }
  |> promise.map(json.to_string)
}

/// Let the Script decide, awaiting it only if it is the kind that fetches.
///
/// Pattern-matched rather than reached through `script.run`: that is the one field the two
/// constructors do not share a type for.
fn decide(script: Script, input: String, context: Context) -> Promise(Json) {
  case script {
    Script(run: run, ..) -> promise.resolve(answer(run(input, context)))
    Fetching(run: run, ..) -> promise.map(run(input, context), answer)
  }
}

fn answer(effects: List(Effect)) -> Json {
  json.object([#("effects", json.array(effects, of: effect))])
}

/// The exact bytes a run answers with, for a test to pin them against the Swift decoder that reads
/// them. There is no generator between the two halves and no shared schema, so a misspelled `kind`
/// or field name is otherwise found out by a person pressing ↩ rather than by anything in CI.
///
/// Goes through `answer`, which is what `decide` answers with, so this cannot drift from a real run.
pub fn encode(effects: List(Effect)) -> String {
  effects |> answer |> json.to_string
}

/// By the canonical Keyword only, deliberately. The Shelf resolves what was typed to a Keyword before
/// it gets here (C2), so the Keyword rule lives in exactly one place; a second copy here would be a
/// second thing to keep in step.
fn find(keyword: String) -> Result(Script, String) {
  case list.find(registry.all(), fn(script) { script.keyword == keyword }) {
    Ok(script) -> Ok(script)
    Error(_) -> Error("No Script answers to the Keyword \"" <> keyword <> "\".")
  }
}

/// Every Need arrives under the same key it is named by, so the ContextGatherer needs no second
/// table mapping one to the other.
///
/// Undeclared Needs are absent from the payload rather than empty and decode to their empty value
/// here — the behaviour starkit.gleam documents.
fn payload_decoder() -> Decoder(#(String, Context)) {
  use input <- decode.optional_field("input", "", decode.string)
  use running_apps <- decode.optional_field(
    "running_apps",
    [],
    decode.list(decode.string),
  )
  decode.success(#(input, Context(running_apps:)))
}

fn manifest(script: Script) -> Json {
  json.object([
    #("keyword", json.string(script.keyword)),
    #("name", json.string(script.name)),
    #("other_keywords", json.array(script.other_keywords, of: json.string)),
    #("needs", json.array(script.needs, of: need)),
    #("asks", asks(script.asks)),
  ])
}

/// The question, or null for a Script that has none.
///
/// Null rather than an empty string: `""` is a question a Script could plausibly have meant — an
/// Input stage with no label — and the two must not collide. The Shelf reads it as an optional, so
/// a manifests.json written before this field existed still lists every Script (F2).
fn asks(asking: Asking) -> Json {
  case asking {
    Decides -> json.null()
    Asks(for: question) -> json.string(question)
  }
}

fn need(need: Need) -> Json {
  case need {
    RunningApps -> json.string("running_apps")
  }
}

fn effect(effect: Effect) -> Json {
  case effect {
    Open(app) -> tagged("open", "app", app)
    Browse(url) -> tagged("browse", "url", url)
    Kill(app) -> tagged("kill", "app", app)
    Copy(text) -> tagged("copy", "text", text)
    Paste(text) -> tagged("paste", "text", text)
    Notify(message) -> tagged("notify", "message", message)
  }
}

/// The field name is the Vocabulary's own, so `Paste(text:)` crosses the wire as `"text"` and
/// the Effector reads back what the Script wrote.
fn tagged(kind: String, field: String, value: String) -> Json {
  json.object([#("kind", json.string(kind)), #(field, json.string(value))])
}

/// Named `refusal` rather than `error` because `error` would collide with Swift's own when C4
/// decodes this.
fn refusal(why: String) -> Json {
  json.object([#("refusal", json.string(why))])
}
