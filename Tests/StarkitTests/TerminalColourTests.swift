import Testing

@testable import StarkitCore

/// Tested because the input is not ours and the failure is silent: escapes that survive do not
/// crash anything, they just make a menu bar item unreadable at the moment it matters most.
struct TerminalColourTests {
    @Test("a real gleam diagnostic comes out readable")
    func gleamDiagnostic() {
        // Copied from `gleam build` on a Script with an unknown variable, escapes and all.
        let coloured = "\u{1B}[0m\u{1B}[1m\u{1B}[38;5;9merror\u{1B}[0m\u{1B}[1m: Unknown variable\u{1B}[0m"
        #expect(coloured.withoutTerminalColour == "error: Unknown variable")
    }

    @Test("text with no escapes is returned unchanged")
    func plainText() {
        #expect("The name `x` is not in scope here.".withoutTerminalColour
            == "The name `x` is not in scope here.")
    }

    @Test("the box-drawing characters gleam frames errors with are kept")
    func keepsNonEscapes() {
        let framed = "  \u{1B}[0m\u{1B}[36m┌─\u{1B}[0m src/scripts/youtube.gleam:4:3"
        #expect(framed.withoutTerminalColour == "  ┌─ src/scripts/youtube.gleam:4:3")
    }
}
