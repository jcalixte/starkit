import Foundation

/// One of the **Shelf**-owned modules every **Script** is compiled against, and whether it has
/// changed since the last build that succeeded.
public struct SharedModule: Equatable, Sendable {
    public let name: String
    /// The hash of the file on disk.
    public let source: String
    /// The hash the last successful build recorded, or `nil` if it never compiled this file.
    public let asBuilt: String?

    public init(name: String, source: String, asBuilt: String?) {
        self.name = name
        self.source = source
        self.asBuilt = asBuilt
    }

    var changed: Bool { asBuilt != source }
}

/// Whether a **Script**'s **Artefact** was built from the source still on disk.
///
/// This is the whole of [ADR 0002](../../docs/adr/0002-one-project-with-per-script-staleness.md).
/// All **Scripts** share one Gleam project, so `gleam build` fails as a whole and one broken
/// **Script** would otherwise stop every other one — at **Summon** time, which is always the worst
/// moment. Two measured facts make that avoidable: Gleam emits *no* **Artefacts** when any module
/// fails, so an **Artefact** on disk is never half-updated; and an unchanged **Script**'s
/// **Artefact** was built from exactly the source still beside it. Comparing the two therefore
/// identifies the culprit precisely, and yields the guarantee worth stating plainly: **a Script you
/// have not edited always runs.**
///
/// It compares content, not mtimes, because Gleam's incremental build compares content too:
/// `touch work.gleam && gleam build` recompiles nothing and leaves the **Artefact**'s mtime where
/// it was, so an mtime rule reads that as an edit and **Refuses** a **Script** no rebuild can ever
/// make **Current** again. Any editor that rewrites a file on save without changing a byte reaches
/// it. Starkit and Gleam have to mean the same thing by "changed", and Gleam is the one that
/// decides what gets compiled.
///
/// Pure by construction — it takes hashes, never paths, so the rule can be tested without a
/// filesystem and reading files stays in C5 where it belongs.
public enum Staleness: Equatable, Sendable {
    /// Built from the source on disk. Runs, even while the project as a whole does not compile.
    case current
    /// Never built, or built and since removed. Indistinguishable from the outside, and the same
    /// answer either way.
    case artefactMissing
    /// The **Script**'s own source has changed since it was last built.
    case sourceChanged
    /// A **Shelf**-owned module every **Script** depends on has changed. Named, because "something
    /// shared changed" is not something a person can act on.
    case sharedModuleChanged(String)
}

extension Staleness {
    /// - Parameters:
    ///   - source: the hash of the **Script**'s source as it is on disk.
    ///   - asBuilt: the hash the last successful build recorded for it, or `nil` if that build never
    ///     saw this file — a **Script** written since, which has no **Artefact** to be current.
    ///   - artefactExists: whether the compiled **Artefact** is where the **Shelf** looks for it.
    ///     Asked as a fact rather than derived from the hashes, because a matching hash and a missing
    ///     file is a real state: `gleam clean`, or Gleam moving a build path it never promised to
    ///     keep (DESIGN.md §9).
    public static func of(
        source: String,
        asBuilt: String?,
        artefactExists: Bool,
        shared: [SharedModule] = []
    ) -> Staleness {
        guard artefactExists else { return .artefactMissing }
        guard asBuilt == source else { return .sourceChanged }
        // First by the order given, so the same set of changes always names the same module and the
        // message a person sees does not depend on dictionary ordering.
        if let changed = shared.first(where: \.changed) {
            return .sharedModuleChanged(changed.name)
        }
        return .current
    }

    public var isStale: Bool { self != .current }
}
