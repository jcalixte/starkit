//// The entry point the Shelf invokes.
////
//// The Shelf runs the built artefact directly — `node run.mjs` — so this module's name is free
//// and need not match the package. `starkit` is the Vocabulary instead, which is what makes
//// `import starkit.{type Effect}` read the way it does in a Script.
////
//// Two verbs, and no state between them:
////
////   describe                  → every manifest, for the Catalogue to cache in manifests.json
////   run <keyword> <payload>   → the Effects one Script decided on
////
//// `describe` exists as a separate verb because the Catalogue must know the catalogue without
//// building or running anything (F2). Splitting it also means a Script can be broken without
//// the bar losing its name.
////
//// `run` answers with a JSON object rather than a bare array, because it can answer with a
//// Refusal instead of Effects — an unknown Keyword means the cached Manifests have gone stale,
//// and an undecodable payload means the Shelf sent something it promised not to. Neither is a
//// Script failing: no Script got to decide anything, which is exactly what makes it a Refusal
//// rather than a Notify. Carrying both in one object is also what keeps the Shelf's decode total.
////
//// `describe` answers with the array itself, because it has no second shape to arrive in: it reads
//// the registry and cannot Refuse. A Script that does not compile is not its problem either — the
//// registry is what broke or it isn't, and either way one Manifest cannot be missing on its own.
////
//// This file is Shelf-owned: vendored into ~/.starkit and overwritten on every install.

import gleam/dynamic/decode.{type Decoder}
import gleam/javascript/promise.{type Promise}
import gleam/json.{type Json}
import gleam/list
import registry
import starkit.{
  type Asking, type Context, type Effect, type Need, type Script, Asks, Context,
  Decides, Fetching, Kill, Notify, Open, Paste, RunningApps, Script,
}

/// Every Script's Manifest, as JSON.
pub fn describe() -> String {
  registry.all() |> json.array(of: manifest) |> json.to_string
}

/// Run the Script with this Keyword against the payload the Shelf gathered.
///
/// A Promise even when nothing here is asynchronous, because one kind of Script is: Gleam cannot
/// return a String down one branch and a Promise down another, so the wider of the two wins and the
/// synchronous case is resolved into it. `run.mjs` has awaited this since T0.3 in anticipation, and
/// awaiting a plain string costs nothing — so the shape changes here and nowhere else.
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
/// Pattern-matched rather than reached through `script.run`, which is the one field the two
/// constructors do not share a type for — and the reason they are two constructors at all.
fn decide(script: Script, input: String, context: Context) -> Promise(Json) {
  case script {
    Script(run: run, ..) -> promise.resolve(answer(run(input, context)))
    Fetching(run: run, ..) -> promise.map(run(input, context), answer)
  }
}

fn answer(effects: List(Effect)) -> Json {
  json.object([#("effects", json.array(effects, of: effect))])
}

fn find(keyword: String) -> Result(Script, String) {
  case list.find(registry.all(), fn(script) { script.keyword == keyword }) {
    Ok(script) -> Ok(script)
    Error(_) -> Error("No Script answers to the Keyword \"" <> keyword <> "\".")
  }
}

/// Every Need arrives under the same key it is named by, so the ContextGatherer can work from
/// the Manifest alone and never needs a second table mapping one to the other.
///
/// Undeclared Needs are absent from the payload rather than empty, and decode to their empty
/// value here — the Script sees nothing, which is the behaviour starkit.gleam documents and the
/// reason the Kill list is tested.
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
    #("needs", json.array(script.needs, of: need)),
    #("asks", asks(script.asks)),
  ])
}

/// The question, or null for a Script that has none.
///
/// Null rather than an empty string, because "" is a question a Script could plausibly have meant —
/// an Input stage with no label — and the two must not collide. The Shelf reads it as an optional,
/// so a manifests.json written before this field existed still lists every Script, which is F2's
/// whole promise about a cache surviving what it was written by.
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
    Kill(app) -> tagged("kill", "app", app)
    Paste(text) -> tagged("paste", "text", text)
    Notify(message) -> tagged("notify", "message", message)
  }
}

/// The field name is the Vocabulary's own, so `Paste(text:)` crosses the wire as `"text"` and
/// the Effector reads back what the Script wrote.
fn tagged(kind: String, field: String, value: String) -> Json {
  json.object([#("kind", json.string(kind)), #(field, json.string(value))])
}

/// `refusal` rather than `error`: it is Starkit's own voice, not a Script's, and `error` would
/// collide with Swift's own when C4 decodes this.
fn refusal(why: String) -> Json {
  json.object([#("refusal", json.string(why))])
}
