# Writing a Script

What a **Script** may do, what it may not, and how a saved file becomes a **Keyword** you can
type. The compile-checked truth is [`src/starkit.gleam`](./src/starkit.gleam); where this file and
that module disagree, the module wins.

A **Script** is one Gleam module in `src/scripts/`. It turns an **Input** and a **Context** into a
list of **Effects**. It decides *what* should happen; the **Shelf** decides *how*, and is the only
side permitted to touch the machine.

Vendored into `~/.starkit` and overwritten on every install, like `starkit.gleam` itself.

## The shape

```gleam
//// One sentence saying what this Script does.

import starkit.{type Script, Decides, Notify, Script}

pub fn script() -> Script {
  Script(
    keyword: "hello",            // the module name, so also the file name
    name: "Hello",               // what the bar shows
    other_keywords: ["hi"],      // shorthand; [] is the normal case
    needs: [],                   // the Context slices you want gathered
    asks: Decides,               // or Asks(for: "a question")
    run: fn(_input, _context) { [Notify("it works")] },
  )
}
```

`pub fn script() -> Script` is the whole contract. `Starkit registry` finds it by file name and
nothing else, so the function name and its visibility are not yours to change.

Two constructors, and you want `Script` unless you reach the network:

| Constructor | `run` returns | For |
| ----------- | ------------- | --- |
| `Script` | `List(Effect)` | Everything local |
| `Fetching` | `Promise(List(Effect))` | A **Script** that must fetch before it can decide |

## The Effects

Every one of them is performed by the **Shelf**, in the order you listed them.

| Effect | Does | Worth knowing |
| ------ | ---- | ------------- |
| `Open(app:)` | Brings an application to the front, launching it if needed | Takes the displayed name or the bundle name: `Calculatrice` or `Calculator` both work |
| `Browse(url:)` | Hands a URL to whatever registered its scheme | A whole URL, scheme and all: `https://…`, or `obsidian://`, `mailto:`. An application by name is an `Open`, and a string without a scheme is a **Refusal** rather than a guess |
| `Kill(app:)` | Terminates it immediately | Never asks, never lets it save. Same two spellings accepted |
| `Copy(text:)` | Puts the text on the clipboard | Types nothing anywhere, so it does not care what was in front. Reach for it when the result is worth keeping and there is nowhere to put it |
| `Paste(text:)` | Puts the text on the clipboard, restores focus to the application you came from, and synthesises ⌘V | The text stays on the clipboard afterwards, so it can be pasted again by hand. Needs Accessibility; a `Copy` does not |
| `Notify(message:)` | Shows a message in the bar while it is still on screen | Not a system notification, and the only way a **Script** reports anything, failure included |

Returning `[]` is legitimate: the seeded `work.gleam` is exactly that until you fill it in.

The table above is the whole list, and there is no escape hatch to stand in for a word that is not
on it. A **Script** that needs a new capability gets a new word in the **Vocabulary**, which is a
design decision. See *When the Vocabulary is not enough* below.

## What a Script can know

Two channels, and both are declared in the **Manifest** instead of discovered at run time, because
the bar has to know before your code runs.

**The Input** is the text typed after the **Keyword**. `Asks(for: "YouTube URL")` gets a stage in
the bar carrying that question, **Seeded** from the clipboard and arriving selected, so accepting
the clipboard is one keystroke. `Decides` never gets a stage and runs on the first ↩. Either way
`run` receives a string, and it is `""` when nothing was typed. Typing the **Input** on the
**Keyword**'s own line (`youtube <url>`) skips the stage, so an `Asks` **Script** must still handle
an empty one.

**The Context** is what the **Shelf** gathered for the **Needs** you declared. One slice exists:

| Need | Field | Holds |
| ---- | ----- | ----- |
| `RunningApps` | `context.running_apps` | The applications a person can see and switch to, as the names *this machine* displays: `Calculatrice` on a French Mac |

An undeclared **Need** arrives as its empty value instead of failing to compile. Forgetting
`needs: [RunningApps]` therefore gives you an empty list and a **Script** that decides on nothing,
which is why the `clean` **Kill** list is tested.

## Fetching

A **Script** owns the network; the **Shelf** owns the machine and never fetches on your behalf.
There is no synchronous HTTP on this target, so a **Script** that reads the network is `Fetching`
and answers with a promise:

```gleam
Fetching(
  keyword: "link",
  // …
  run: fn(input, _context) { decide(input) },
)

fn decide(input: String) -> Promise(List(Effect)) {
  case request.to(input) {
    Error(_) -> promise.resolve([Notify("Starkit could not read that as a URL.")])
    Ok(asked) -> {
      use sent <- promise.await(fetch.send(asked))
      // …
    }
  }
}
```

The **Shelf** awaits it and is otherwise indifferent: the same **Effects** arrive, under the same
5 s deadline. Every failure has to become a sentence, because a `Notify` in the bar is the only
place it can be shown. `link.gleam` and `youtube.gleam` both turn statuses into sentences and are
worth copying.

## What you can import

Standard Gleam does not count against the **Vocabulary**, and the whole of `gleam_stdlib` is
available. Beyond it:

| Module | For | Example |
| ------ | --- | ------- |
| `gleam/javascript/promise` | The `Promise` a `Fetching` **Script** returns | both fetchers |
| `gleam/fetch`, `gleam/http/request` | Reaching the network | `link.gleam` |
| `gleam/json`, `gleam/dynamic/decode` | Reading a JSON answer back | `youtube.gleam` |
| `text` | `text.normalise`, which flattens typographic punctuation to what a keyboard types, so a pasted title is one you can find again by typing it | both pasters |

`text` is Shelf-owned and replaced wholesale on install, and importing it means sharing its fate:
every **Script** that imports it goes **Stale** when it changes. That is the one exception to
**Script** isolation, and it is why the module holds nothing but `normalise`.

Adding a dependency to `gleam.toml` is an *ask first*. The file is overwritten on every install, so
an edit there does not survive one anyway.

## What a Script cannot do

- Touch the machine. There is no filesystem access, no process control, no shelling out and no
  AppleScript. Only **Effects**.
- Use `@external`. Zero FFI is a measured property of the design, and it is what makes
  `starkit.gleam` the whole interface.
- Run another **Script**, or reach into one. `import scripts/other` is not a supported shape.
- Outlive 5 seconds. A **Script** still running then is killed and the bar says so. A fetch that
  never returns is what that deadline is for.
- Write to stdout. `stdout` *is* the protocol: `io.println` lands in front of the JSON reply and
  earns you `Starkit could not read what "x" answered`. `echo` and `io.println_error` go to stderr
  and are safe, which is how you print while debugging.
- Keep anything between runs. A fresh `bun` per run, and nothing survives it. No caches, no files on
  the side.
- Carry configuration outside its **Manifest**. There is no config file and no per-**Script** key
  binding; the only key binding in Starkit **Summons** the bar.
- Use OTP, actors, or an Erlang-only Hex package. The target is JavaScript, measured at roughly
  5x faster to start for this workload; this is not BEAM Gleam. `docs/adr/0001` in the Starkit repo
  has the numbers.

`panic`, `todo` and an unhandled crash all become a **Refusal** naming the **Script**, with the
stack trace as the detail, and no **Effect** is performed: the list goes out only once `run` has
returned the whole of it. Once it has, the **Shelf** performs them in order and there is no way
back. `clean` guards against **Killing** Starkit for exactly that reason, since a **Kill** aimed at
itself would end the process partway down its own list.

## Keywords

A **Keyword** is a Gleam module name, so `src/scripts/daily_notes.gleam` answers to `daily_notes`:
lowercase letters, digits and underscores, starting with a letter. That one is *canonical*.
`other_keywords` are shorthand typed in the same field (`yt` for `youtube`) and are not file names,
so they may be anything you would type.

What you type is matched in four bands, best first: the canonical **Keyword** exactly, one of the
others exactly, the canonical one by prefix, then the others by prefix. A **Keyword** spelled in
full always wins, so `link` cannot run `linkedin`, and a two-letter shorthand cannot be shadowed by
a **Script** that merely starts with those letters.

## The loop

Create a **Script** from the bar (⌃⌘K, type a name nothing answers to, and the `Create` row writes
the file from the template and opens it in Zed) or from a terminal:

```sh
Starkit create <keyword>   # writes src/scripts/<keyword>.gleam if absent, then opens it
Starkit edit <keyword>     # opens it; refuses rather than writing a template over the question
Starkit delete <keyword>   # moves it and its test suite to the Trash
```

Saving is the whole flow after that. The Watcher rewrites `src/registry.gleam` and rebuilds within
about 200 ms, so a new **Script** is in the bar by the next **Summon** and an already-built one is
never built at **Summon** time. A build that fails turns the menu bar red immediately, naming the
error, instead of waiting for you to try running something.

One project, per-**Script** freshness (`docs/adr/0002` in the Starkit repo): a **Script** whose
**Artefact** was built from the source on disk always runs, even while the project as a whole does
not compile. A **Script** whose source has changed since its last successful build is **Stale** and
is **Refused** by name. Breaking `youtube.gleam` does not stop `work` from running.

From a terminal:

```sh
Starkit run <keyword> [input]             # runs it for real
Starkit run <keyword> [input] --dry-run   # prints the Effects and performs none
cd ~/.starkit && gleam test               # the Script test suites
```

`--dry-run` is the debugging path and is kept permanently. `Starkit run` accepts any **Keyword** a
**Script** answers to, but spelled in full only: the bar shows you the row it picked before ↩
reaches it, and a terminal shows nothing between the word and the **Effects**.

## Testing one

Put the suite in `test/<keyword>_test.gleam`; `gleeunit` discovers every `*_test.gleam` and
`test/starkit_test.gleam` is only the runner. Test the decision a **Script** makes and leave the
plumbing alone: make `pub` whatever part of it answers the question that would be silent if it were
wrong, and call it with plain values:

```gleam
pub fn a_kept_application_is_spared_test() {
  assert clean.kills(["Zed", "Slack"], ["Zed"]) == [Kill("Slack")]
}
```

Use the bare `assert` keyword and not `gleeunit/should`: the existing suites all use it, and a
function whose name ends in `_test` is the whole registration.

`starkit.empty_context()` is there for a **Script** that takes a whole **Context** and declared no
**Needs**. What is worth testing is the failure that does not look like one: a wrong YouTube ID
pastes a working link to the wrong video, and a name missing from a keep list closes an application
with whatever was unsaved in it.

Delete a **Script**'s source and its test suite goes with it. `gleam build` typechecks `test/`, so a
suite left behind is a project that stops compiling 200 ms later, which is why `Starkit delete`
moves both.

## Which files are yours

| Path | Who owns it |
| ---- | ----------- |
| `src/scripts/*.gleam` | Yours. Seeded once on a fresh install, never overwritten after |
| `test/*_test.gleam` | Yours, apart from `starkit_test.gleam` |
| `src/starkit.gleam`, `src/entry.gleam`, `src/text.gleam`, `run.mjs`, `gleam.toml`, this file | The **Shelf**'s. Overwritten on every install |
| `src/registry.gleam` | Generated from `src/scripts/` on every save. Do not edit |
| `starkit.toml` | Yours, and optional: `bun` and `gleam` paths for a shell that hides them, and the `editor` ⌥↩ opens a **Script** in |

## When the Vocabulary is not enough

Adding an **Effect** or a **Context** slice is a design decision, and the smallness of the
**Vocabulary** is the property being defended, so the bar for a new word is several **Scripts**
needing it and not one. The same goes for a permission beyond Accessibility, and for a new
dependency. Ask before adding any of them, and update the **Vocabulary** in the Starkit repo's
`CONTEXT.md` in the same change that adds to it.
