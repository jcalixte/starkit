import Foundation

/// Starkit declining to run a **Script** at all, in its own voice, naming which and why.
///
/// Not an error type in the Swift sense of "something went wrong": a **Refusal** is a decision,
/// and the reason is written to be read by the person who has to fix it. That is why it carries a
/// sentence rather than a code — every **Refusal** ends up somewhere a person looks, either in the
/// menu bar or on stderr, and there is nowhere for a code to be translated into a sentence later.
///
/// Distinct from a **Notify**, which is a **Script** that *did* run reporting what it decided. A
/// **Refusal** means no **Script** ever got to decide anything — which includes a **Script** that
/// crashed or was killed at the deadline, because dying is not deciding. `entry.gleam` answers a run
/// with one or the other, and C4 decodes both into these two shapes.
public struct Refusal: Error, Equatable {
    /// One sentence, for the menu bar. An icon can say *that* something is wrong but never *what*,
    /// and a menu item is one line — so this has to stand alone at a glance.
    public let reason: String

    /// Someone else's words, verbatim, when there are some: a Gleam type error, a stack trace from
    /// a **Script**. Kept apart from `reason` because it is many lines and belongs where a person
    /// can read it properly, never in a menu. There is nothing Starkit can add to a compiler
    /// diagnostic, and any paraphrase of one would be worse than passing it through.
    public let detail: String?

    public init(_ reason: String, detail: String? = nil) {
        self.reason = reason
        self.detail = detail
    }
}
