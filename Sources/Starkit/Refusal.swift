import Foundation

/// Starkit declining to run a **Script** at all, in its own voice, naming which and why.
///
/// Not an error type in the Swift sense of "something went wrong": a **Refusal** is a decision,
/// and the reason is written to be read by the person who has to fix it. That is why it carries a
/// sentence rather than a code — every **Refusal** ends up somewhere a person looks, either in the
/// menu bar or on stderr, and there is nowhere for a code to be translated into a sentence later.
///
/// Distinct from a **Notify**, which is a **Script** that *did* run reporting what it decided. A
/// **Refusal** means no **Script** ever got to decide anything. `entry.gleam` answers a run with
/// one or the other, and C4 decodes both into these two shapes.
struct Refusal: Error {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }
}
