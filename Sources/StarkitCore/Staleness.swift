import Foundation

/// One of the **Shelf**-owned modules every **Script** is compiled against.
public struct SharedModule: Equatable, Sendable {
    public let name: String
    public let modified: Date

    public init(name: String, modified: Date) {
        self.name = name
        self.modified = modified
    }
}

/// Whether a **Script**'s **Artefact** was built from the source still on disk.
///
/// This is the whole of [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md).
/// All **Scripts** share one Gleam project, so `gleam build` fails as a whole and one broken
/// **Script** would otherwise stop every other one — at **Summon** time, which is always the worst
/// moment. Two measured facts make that avoidable: Gleam emits *no* **Artefacts** when any module
/// fails, so an **Artefact** on disk is never half-updated; and an untouched **Script**'s
/// **Artefact** was built from exactly the source still beside it. Comparing mtimes therefore
/// identifies the culprit precisely, and yields the guarantee worth stating plainly: **a Script
/// you have not edited always runs.**
///
/// Comparing mtimes rather than just running `gleam build` and using the result will look like
/// superstition to a future reader. It is not. It is the isolation mechanism.
///
/// Pure by construction — it takes dates, never paths, so the rule can be tested without a
/// filesystem and the reading of mtimes stays in C5 where it belongs.
public enum Staleness: Equatable, Sendable {
    /// Built from the source on disk. Runs, even while the project as a whole does not compile.
    case current
    /// Never built, or built and since removed. Indistinguishable from the outside, and the same
    /// answer either way.
    case artefactMissing
    /// The **Script**'s own source has been edited since it was last built.
    case sourceChanged
    /// A **Shelf**-owned module every **Script** depends on has moved. Named, because "something
    /// shared changed" is not something a person can act on.
    case sharedModuleChanged(String)
}

extension Staleness {
    /// Equal timestamps count as current. Gleam writes an **Artefact** after reading the source it
    /// came from, so equality means "built in the same instant", never "built before".
    public static func of(
        source: Date,
        artefact: Date?,
        shared: [SharedModule] = []
    ) -> Staleness {
        guard let artefact else { return .artefactMissing }
        if source > artefact { return .sourceChanged }
        // First by the order given, so the same set of changes always names the same module and
        // the message a person sees does not depend on dictionary ordering.
        if let changed = shared.first(where: { $0.modified > artefact }) {
            return .sharedModuleChanged(changed.name)
        }
        return .current
    }

    public var isStale: Bool { self != .current }
}
