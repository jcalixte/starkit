# Starkit

A keyboard-summoned launcher for a handful of personal automations, written in Gleam. Starkit
exists to replace the parts of Script Kit that get used, and nothing else.

## Language

### The two halves

**Shelf**:
The always-running macOS application: the summoning key, the bar, and the only thing in the
system permitted to touch macOS.
_Avoid_: launcher, palette, app, host

**Script**:
One Gleam module, addressed by name, that turns an **Input** and a **Context** into
**Effects**. A **Script** may reach the network on its own; it may never touch the machine.
_Avoid_: command, action, task, automation

**Fetching**:
A **Script** that reaches the network before it can decide, and therefore answers with a promise of
**Effects** rather than with **Effects**. Named in the **Vocabulary** as a second way of writing a
**Script**, because there is no synchronous HTTP on this target and a **Script** that stays local
should not have to say so. It is the only asymmetry in the **Vocabulary** and it is deliberate: the
**Shelf** awaits it and is otherwise indifferent, and the 5 s deadline applies unchanged. Added at
T5.2 with `youtube`, the first one.
_Avoid_: async, promise-returning, remote. Those describe the mechanism; this names the kind of
**Script** it is.

### What crosses the boundary

**Summon**:
To bring the **Shelf** on screen with its one key binding. The **Shelf** is never summoned by
clicking, and never appears unasked.
_Avoid_: open, show, invoke, trigger

**Dismiss**:
To put the **Shelf** away without running anything: ⌃⌘K again, Escape, or a click outside it. The
person **Dismisses**; a **Script** never does, and neither does an **Effect** that happens to
activate another application while the bar is up.
_Avoid_: close, cancel, hide. `hide` is AppKit's word for hiding the *application*, which is how
the keyboard is handed back, and that is one of the things a **Dismissal** does rather than the
thing itself.

**Input**:
The text a person types into the **Shelf** before a **Script** runs. A **Script** either **Asks**
for one, declared so the **Shelf** knows before it runs, or **Decides** without.
_Avoid_: argument, query, prompt, parameter

**Context**:
The slices of the world a **Script** declares it needs; the **Shelf** gathers exactly those
and no others.
_Avoid_: environment, state, world, ambient data

**Keyword**:
A space-free word that selects a **Script** in the **Shelf**. Everything typed after the first
space is the **Input**. A **Script** answers to one *canonical* **Keyword**, its module name and
therefore also its file name, and to any number of further **Keywords**, which are shorthand:
`yt` reaches `youtube`. They are matched the same way and differ only in that the canonical one
wins a tie.
_Avoid_: alias, trigger, shortcut, hotkey. A second **Keyword** is still a **Keyword**, typed
in the same field, and there are no per-**Script** key bindings; the only key binding in Starkit
summons the **Shelf**.

**Seed**:
The clipboard text a **Script**'s **Input** starts out holding, selected, so that accepting it
takes one keystroke and replacing it takes none. Only a **Script** that **Asks** is **Seeded**.
_Avoid_: default, prefill, autofill

**Asks** / **Decides**:
What a **Script** declares about the **Input**. One that **Asks** carries the question it asks
("YouTube URL") and gets a stage in the bar to ask it in, **Seeded** and selected. One that
**Decides** works from its **Context** alone and runs on the first ↩. Declared rather than
discovered, because the bar has to know before the **Script** runs.
_Avoid_: prompt, ask for input, interactive. And _do not_ call it a **Need**, which is a slice of
the machine the **Shelf** gathers; an **Input** comes from the person.

**Effect**:
One thing a **Script** asks the **Shelf** to do to the machine. A **Script** cannot act; it
can only ask.
_Avoid_: command, action, side effect, intent

**Manifest**:
What a **Script** declares about itself, as against what it decides: its **Keywords**, the name
shown in the **Shelf**, and the **Context** slices it needs. Everything the **Shelf** must know
to list a **Script** and gather for it, and nothing that requires building or running one,
which is why a **Script** that no longer compiles still has a name in the bar. Declared in Gleam
and compile-checked, so it cannot drift from the **Script** it describes.
_Avoid_: metadata, header, descriptor, frontmatter, config

**Refusal**:
Starkit declining to run a **Script**, in its own voice, naming which and why: a **Stale**
**Artefact**, a **Keyword** that resolves to nothing, an absent **Toolchain**, a **Script** that
crashed, a **Script** killed at the deadline. Distinct from **Notify**, which is a **Script** that
ran and reported what it decided, where a **Refusal** means no **Script** ever got to decide
anything. Crashing and being killed belong here because a process that died decided nothing, and
the words that follow a **Refusal** are Starkit's or the runtime's, never a **Script**'s.
_Avoid_: error, failure, rejection

**Vocabulary**:
Every name a **Script** author must learn from Starkit and could not have guessed from Gleam
itself: the **Effects**, the **Context** slices, and the `script` contract. Standard Gleam does
not count against it. The **Vocabulary** is closed but not frozen. It may grow, each addition is a
design decision, and what matters is the baseline it grows from.
_Avoid_: API, surface, framework, helpers, globals

### The Effect vocabulary

Deliberately closed and small. Adding a word here is a design decision.

**Open**:
Bring an application to the foreground, launching it if needed.

**Browse**:
Hand a URL to the machine, which opens it with whatever registered the scheme: a browser for
`https://`, an application for its own, like `obsidian://`. **Open** names an application and
**Browse** names an address, which is why they are two words and not one with two spellings — the
machine answers them by different mechanisms and fails them for different reasons. A **Script** that
fetched the URL is trusting where it came from, exactly as a person clicking a link is.
_Avoid_: open, visit, launch, url. And not **Link**, which is the name of a **Script**.

**Kill**:
Terminate an application immediately, discarding unsaved work.
_Avoid_: quit, close, terminate. Those imply the application is asked and may refuse or
prompt. **Kill** never asks, and that is a choice: speed is worth the risk.

**Copy**:
Put text on the clipboard and stop there. Nothing is typed anywhere, so nothing depends on what was
in front, and no Accessibility grant is involved. What a **Script** reaches for when the result is
worth keeping and there is nowhere to put it yet.
_Avoid_: clipboard, pasteboard, yank, stash. And do not call it a silent **Paste**: a **Paste** with
its keystroke removed is a different act, not a quieter one.

**Paste**:
Replace the selection in whatever application was frontmost before the **Shelf** appeared, and
leave the pasted text on the clipboard afterwards so it can be pasted again by hand. The
clipboard is deliberately **not** restored: pasting the same result into several places is the
common case, re-running the **Script** on the same subject is not.
_Avoid_: type, insert, set selected text

**Notify**:
Tell the person why a **Script** did nothing, in the **Shelf** itself, while it is still on
screen. Not a system notification, because nothing Starkit says is worth keeping.
_Avoid_: warn, alert, toast, notification

### Around the edges

**Toolchain**:
The `gleam` and `bun` that Starkit borrows from the machine rather than shipping. Starkit never
chooses a version: it uses whatever the login shell reports, so upgrading one is not an event.
_Avoid_: runtime, dependencies, environment

### Freshness

**Artefact**:
The compiled JavaScript a **Script** actually runs as. One per **Script**.

**Stale**:
Said of an **Artefact** built from source that has since changed. A **Stale** **Script**
refuses to run; a **Script** whose **Artefact** is not **Stale** always runs, even while the
project as a whole fails to build.
_Avoid_: dirty, outdated, out of sync

### The Context vocabulary

**Running Apps**:
The applications a person can see and switch to: those with windows and a Dock presence,
excluding background and helper processes.
_Avoid_: processes, open apps

## Relationships

- The person **Summons** and **Dismisses** the **Shelf**; a **Script** does neither
- The **Shelf** runs many **Scripts**; a **Script** never runs another **Script**
- A **Script** declares zero or more **Context** slices and consumes at most one **Input**
- A **Script** that **Asks** has its **Input** **Seeded**; one that **Decides** never is
- Every **Script** has exactly one *canonical* **Keyword**, which is its module name, and may
  answer to further **Keywords**; no **Keyword** contains a space
- A **Script** emits zero or more **Effects**, in order
- Every **Effect** is performed by the **Shelf**; a **Script** performs none of them
- Every **Script** has exactly one **Manifest**, and the **Shelf** knows them all without building
- A **Refusal** comes from Starkit, a **Notify** comes from a **Script**, and nothing else reports

## Example dialogue

> **Dev:** "Clean needs the list of apps to close. Does it shell out and ask the system?"
> **Julien:** "No. It declares **Running Apps** as its **Context**, and the **Shelf** hands
> them over. Asking the system myself costs 463 ms; the **Shelf** already knows for free."
>
> **Dev:** "And then Clean closes them?"
> **Julien:** "Clean decides *which*. It emits a **Kill** per app and the **Shelf** does it.
> **Kill**, not quit. I don't want a save dialog standing between me and an empty screen."

## Flagged ambiguities

- "script" meant both the Gleam source file and the thing that runs. Resolved: a **Script**
  is the module. Its compiled form is an **Artefact**; there is no third word for a single
  execution, because nothing in Starkit outlives one.
- "context" is overloaded against `CONTEXT.md` itself, which is a glossary and not a **Context**.
  Kept anyway: **Context** is the right domain word, and the collision is only in file naming.
- "shortcut" was used for both a typed alias and a per-**Script** global key chord. Resolved:
  only the typed one exists, and it is called a **Keyword**. There is exactly one key chord in
  Starkit and it **Summons** the **Shelf**.
- **A second name for a **Script** was asked for as a "shortcut", `yt` for `youtube`.** Resolved
  *without* a new word: by the definition above it is a **Keyword**, so what was wrong was the
  cardinality rather than the vocabulary, and the invariant moved from "exactly one **Keyword**"
  to "exactly one canonical **Keyword**, and any number more". The ban on "alias" therefore holds,
  since it was written to stop a **Keyword** being called something else and not to forbid a second
  one, and the field is `other_keywords`, which says what it holds in the **Vocabulary**'s own word.
- **Paste** and **Seed** both touch the clipboard, so "restore the clipboard" was ambiguous
  between putting back the **Seed** and keeping the pasted text. Resolved: keep the pasted
  text. The cost is that **Summoning** the same **Script** again **Seeds** from its own output,
  which is cosmetic, since the **Seed** arrives selected.
- "error" covered two different speakers: a **Script** that ran and reports it did nothing useful,
  and Starkit declining to run one at all. Resolved: the second is a **Refusal**, the first is a
  **Notify**. The wire says `refusal` and not `error` for that reason, and because `error`
  would collide with Swift's own in C4.

  A third case turned up at T1.4 and looked like neither: a **Script** that ran and then crashed, or
  one killed at the 5 s deadline. It ran, so **Notify** seemed to fit; nothing was decided, so
  **Refusal** did too. Resolved as a **Refusal**, which sharpened the test from "did it run" to "did
  a **Script** get to decide, and whose words are these". A **Notify** is a decision a **Script**
  made; a stack trace is the runtime's. No new word was needed, and finding that out is what the
  case was worth.
- "hide" named two acts at once: putting the bar away, and `NSApp.hide`, which is what returns
  activation to the application the person came from. C1 did both in one method called `hide`, so the
  code could not say which it meant, and **Summon** had no opposite in the glossary at all, while
  its own _Avoid_ list already ruled out "show", which C1 was using. Resolved: the act is a
  **Dismissal**, and `NSApp.hide` is one of the things it does. Found while specifying T2.6, when
  clicking outside became a third way to do the first one and nothing named it. It costs the
  **Vocabulary** nothing (G6): no **Script** author ever writes it, for the same reason none of them
  writes **Shelf** or **Artefact**.
- The reply to a run was briefly called an "envelope", a word from messaging that named the JSON
  shape rather than anything in the domain. Resolved: it carries **Effects** or a **Refusal**, and
  those two words are enough; the shape needs no name of its own.
- A **Script** was briefly called pure, which is wrong. Youtube and Link from URL fetch over HTTP,
  and the response decides the **Effects**, so the network cannot be a **Context** slice. The line
  is not purity: a **Script** owns the network, the **Shelf** owns the machine.
- "the name of an application" turned out to be two names, and only a machine that is not in English
  can tell you. **Open** says "the name you see in the Finder", and on this one that is
  *Calculatrice* while the bundle on disk is *Calculator.app*, so `Kill("Calculator")` found nothing
  to kill and said so, while `Open("Calculator")` would have launched it, because LaunchServices
  answers to either. Found at T4.3, when a **Kill** silently killed nothing. Resolved: the
  **Vocabulary** keeps one word, and both **Effects** accept both spellings, since C7 asks
  LaunchServices the same question for a **Kill** that it already asked for an **Open**. What a
  **Script** compares on its own side has no such help: a keep list in `clean.gleam` is matched
  against a **Running Apps** **Context**, which is made of displayed names, so *Calculatrice* is the
  spelling that spares it.
- **Copy** was nearly not a word at all, because **Paste** already leaves its text on the clipboard
  (T6) and the two therefore differ by one keystroke. Resolved as a word, on what each one needs
  rather than on what each one leaves behind: a **Paste** needs Accessibility and needs to know
  which application the bar took the keyboard from, and it types into that application whether or
  not it was a text field. A **Script** whose result is worth keeping and has nowhere to go had only
  the destructive one of the two. The **Effector** shows the split — `copy` cannot fail, and every
  way a **Paste** can is downstream of the clipboard write.

  Writing the clipboard *before* the Accessibility check came out of the same reading: the
  **Refusal** for a missing grant ends "the text is on the clipboard; ⌘V pastes it by hand", and
  until this change it was written before the clipboard had been touched. A denied grant now costs
  the run its keystroke and nothing more.
