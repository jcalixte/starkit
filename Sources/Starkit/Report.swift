import Foundation

/// A line to stderr. Never stdout: that carries the **Effects** and nothing else, so a **Refusal**
/// printed there could be mistaken for one by anything reading a run.
func report(_ line: String) {
    FileHandle.standardError.write(Data((line + "\n").utf8))
}
