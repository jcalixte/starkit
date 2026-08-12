import Foundation

extension String {
    /// The same text with CSI colour escapes removed.
    ///
    /// No environment variable makes this unnecessary: `gleam` writes escapes into a compile error
    /// even when its output is a pipe and `NO_COLOR=1` is set, and ADR 0003 records bun ignoring
    /// `NO_COLOR` the same way.
    public var withoutTerminalColour: String {
        replacingOccurrences(
            of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]",
            with: "",
            options: .regularExpression
        )
    }
}
