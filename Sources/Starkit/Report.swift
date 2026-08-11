import Foundation

/// A line to stderr, which is the only channel Starkit has that is not the menu bar.
///
/// stdout is the **Effects** and nothing else, so a **Refusal** printed there could be mistaken for
/// one by anything reading a run. stderr is where the same sentence is visible when the executable
/// is run from a terminal during development; under `SMAppService` there is nothing on the other
/// end of it and C10 carries the one-line version instead.
func report(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}
