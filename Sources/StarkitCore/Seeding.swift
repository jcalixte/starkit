/// Which half of `$STARKIT_HOME` belongs to the **Shelf** and which half is yours.
///
/// One rule, applied by path, so a file added to `seed/` later is carried without a list to update:
/// `src/scripts/` is what you write, everything else under `seed/` is the **Shelf**'s to replace.
/// That is what lets the **Vocabulary** upgrade on every install without a hand merge while an
/// install never touches a **Script** you have edited.
public enum Seeding {
    /// What is owed to one file of seed content.
    public enum Verdict: Equatable, Sendable {
        /// **Shelf**-owned: written whenever it differs, so the **Vocabulary** cannot drift.
        case vendor

        /// Yours, and not there yet: written once.
        case seed

        /// Yours, and already there. The **Script** you edited, left alone.
        case keep

        /// Not seed content. `build/` is `gleam build`'s, and 3 MB of one machine's **Artefacts**
        /// copied over another home's `build/` is how a **Script** comes to look built when it is
        /// not.
        case skip
    }

    /// The relative path of the one file `gleam build` would be entitled to overwrite anyway, and the
    /// prefix that decides ownership. Both are compared as paths rather than names: a `scripts`
    /// directory somewhere else under `seed/` would not be yours.
    private static let yours = "src/scripts/"
    private static let generated = "build/"

    /// Generated per home by `Starkit registry`, and never seed content — `install.sh` writes it into
    /// a fresh home before the first build because `gleam build` fails on the missing module. Skipped
    /// rather than vendored: one machine's copy written over another home's would name **Scripts**
    /// that home does not have, and rewriting it marks every **Artefact** **Stale**.
    private static let perHome = "src/registry.gleam"

    /// `path` is relative to the root of the seed content, with no leading `./`.
    public static func verdict(for path: String, destinationExists: Bool) -> Verdict {
        if path.hasPrefix(generated) { return .skip }
        if path == perHome { return .skip }
        // Written by whatever wrote it, on whichever machine. Never content.
        if path.hasSuffix(".DS_Store") { return .skip }
        guard path.hasPrefix(yours) else { return .vendor }
        return destinationExists ? .keep : .seed
    }
}
