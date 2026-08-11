import Foundation

/// What a **Script** declares about itself, as against what it decides.
///
/// The Swift half of `starkit.gleam`'s `Script` minus the deciding: its **Keyword**, the name shown
/// in the bar, and the **Context** slices it needs. Everything the **Shelf** needs in order to
/// *list* a **Script**, and nothing that needs building or running one — which is what lets a
/// **Script** that no longer compiles keep its name in the bar (F2).
public struct Manifest: Equatable, Sendable, Codable {
    public let keyword: String
    public let name: String

    /// The **Needs** as `entry.gleam` names them — `running_apps` and, for now, nothing else.
    ///
    /// Strings rather than a Swift mirror of the `Need` type, because nothing reads them yet.
    /// C8 gathers **Context** at T4.2 and that is where a mismatched name has to be caught; giving
    /// them a type here would be deciding how, three tasks before anything exercises the decision.
    public let needs: [String]

    public init(keyword: String, name: String, needs: [String] = []) {
        self.keyword = keyword
        self.name = name
        self.needs = needs
    }
}

extension Manifest {
    /// Read what `describe` answered: every **Manifest**, or a **Refusal** saying why there are none.
    ///
    /// A bare array, unlike `run`'s reply. Listing cannot **Refuse** from inside — it reads the
    /// registry and nothing else — so there is no second shape for this to arrive in.
    ///
    /// Pure, and in `StarkitCore` for the same reason `Effect.all` is: obtaining the reply needs a
    /// machine, reading it does not.
    public static func all(
        reply: Data,
        diagnostics: String?,
        exitStatus: Int32
    ) throws(Refusal) -> [Manifest] {
        guard !reply.isEmpty else {
            throw Refusal(
                "Starkit could not list your Scripts.",
                detail: diagnostics ?? "bun exited \(exitStatus) without writing an answer."
            )
        }
        do {
            return try JSONDecoder().decode([Manifest].self, from: reply)
        } catch {
            throw Refusal(
                "Starkit could not read the list of your Scripts.",
                detail: "\(error)"
            )
        }
    }
}
