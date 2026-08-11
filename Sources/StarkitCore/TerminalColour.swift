import Foundation

extension String {
    /// The same text with terminal colour escapes removed.
    ///
    /// Both halves of the **Toolchain** colour their output unconditionally. Measured: `gleam`
    /// writes 28 escape sequences into a compile error even when its output is a pipe and even
    /// with `NO_COLOR=1` set, and ADR 0003 records bun ignoring `NO_COLOR` the same way. So there
    /// is no environment variable that makes this unnecessary — the escapes have to come out here,
    /// or a Gleam type error reaches the menu bar as `[0m[1m[38;5;9merror[0m`.
    ///
    /// CSI sequences only, which is all either tool emits. A general terminal emulator this is
    /// not, and it does not need to be: the input is compiler diagnostics, not arbitrary output.
    public var withoutTerminalColour: String {
        replacingOccurrences(
            of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]",
            with: "",
            options: .regularExpression
        )
    }
}
