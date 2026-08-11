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
//// Both verbs answer with a JSON object, never a bare array. `run` can fail in a way no Effect
//// can express — an unknown Keyword means the cached manifests have gone stale, and an
//// undecodable payload means the Shelf sent something it promised not to — so the envelope
//// carries either `effects` or `error`, and the Shelf's decode stays total. A Script reporting
//// its *own* failure is not this: that is a Notify, which is an Effect like any other.
////
//// This file is Shelf-owned: vendored into ~/.starkit and overwritten on every install.

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/list
import registry
import starkit.{
  type Context, type Effect, type Need, type Script, Context, Kill, Notify, Open,
  Paste, RunningApps,
}

/// Every Script's manifest, as JSON.
pub fn describe() -> String {
  registry.all() |> json.array(of: manifest) |> json.to_string
}

/// Run the Script with this Keyword against the payload the Shelf gathered.
pub fn run(keyword: String, payload: String) -> String {
  let envelope = case find(keyword) {
    Error(message) -> error(message)
    Ok(script) ->
      case json.parse(payload, payload_decoder()) {
        Error(_) ->
          error(
            "The payload for \""
            <> keyword
            <> "\" is not the shape the Shelf promised.",
          )
        Ok(#(input, context)) -> {
          let decide = script.run
          json.object([
            #("effects", json.array(decide(input, context), of: effect)),
          ])
        }
      }
  }
  json.to_string(envelope)
}

fn find(keyword: String) -> Result(Script, String) {
  case list.find(registry.all(), fn(script) { script.keyword == keyword }) {
    Ok(script) -> Ok(script)
    Error(_) -> Error("No Script answers to the Keyword \"" <> keyword <> "\".")
  }
}

/// Every Need arrives under the same key it is named by, so the ContextGatherer can work from
/// the manifest alone and never needs a second table mapping one to the other.
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
  ])
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

fn error(message: String) -> Json {
  json.object([#("error", json.string(message))])
}
