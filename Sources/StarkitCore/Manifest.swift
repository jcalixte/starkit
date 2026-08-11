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
    /// Strings, and they stay strings now that C8 reads them (T4.2). Decoding them into `Need` here
    /// would move the failure from the run to the *listing*, and a `manifests.json` naming one slice
    /// this binary has never heard of would empty the bar of every **Script** in it — which is
    /// precisely the collapse F2 exists to prevent. So the word is carried as written and refused at
    /// the moment it would have been gathered, by `Need.all`, where the **Refusal** can name the
    /// **Script** that asked for it.
    public let needs: [String]

    /// The question this **Script** asks, or nothing if it decides on its own.
    ///
    /// The **Asking** half of `starkit.gleam`, flattened: `Decides` arrives as `null` and
    /// `Asks(for:)` as its label, because Swift needs one bit — is there an **Input** stage — and
    /// the label is the only other thing carried. A `String?` rather than an enum for that reason,
    /// and because it is what a placeholder wants to be by the time C1 has it.
    ///
    /// Optional in the decoding sense too, which is F2 at work: `manifests.json` written before
    /// this field existed has no `asks` key, and a cache that fails to decode is a bar with no
    /// **Scripts** in it on the one launch after an upgrade.
    public let asks: String?

    public init(keyword: String, name: String, needs: [String] = [], asks: String? = nil) {
        self.keyword = keyword
        self.name = name
        self.needs = needs
        self.asks = asks
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
