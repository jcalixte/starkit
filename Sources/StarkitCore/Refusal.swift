import Foundation

/// Starkit declining to run a **Script** at all. Distinct from a **Notify**, which is a **Script**
/// that ran and reported what it decided; a crash or a deadline kill is a **Refusal**, because dying
/// is not deciding. `entry.gleam` answers a run with one or the other, and C4 decodes both.
public struct Refusal: Error, Equatable {
    /// One sentence — rendered as a single menu-bar item, so it has to stand alone.
    public let reason: String

    /// A compiler diagnostic or stack trace, verbatim and often many lines. Never shown in the menu.
    public let detail: String?

    public init(_ reason: String, detail: String? = nil) {
        self.reason = reason
        self.detail = detail
    }
}
