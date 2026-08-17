import Foundation
import Testing

@testable import StarkitCore

struct OverridesTests {
    private let keys = ["bun", "gleam", "editor"]

    private func read(_ text: String) -> [String: String] {
        Overrides.read(text, keys: keys)
    }

    @Test("a key on its own line, quoted or not, is an override")
    func plainLines() {
        #expect(
            read(
                """
                bun = "/opt/homebrew/bin/bun"
                gleam = /usr/local/bin/gleam
                """
            ) == ["bun": "/opt/homebrew/bin/bun", "gleam": "/usr/local/bin/gleam"]
        )
    }

    @Test("spacing around the key, the equals and the value is not part of either")
    func spacing() {
        #expect(read("   editor   =   \"Zed\"   ") == ["editor": "Zed"])
        #expect(read("bun=/bin/bun") == ["bun": "/bin/bun"])
    }

    @Test("a file written on Windows does not name a path with a carriage return on the end")
    func carriageReturns() {
        // Left in, this is a path to nothing and the Toolchain Refuses with a name that looks right.
        #expect(read("bun = \"/bin/bun\"\r\ngleam = \"/bin/gleam\"\r\n")["bun"] == "/bin/bun")
        #expect(read("bun = /bin/bun\r\n")["bun"] == "/bin/bun")
    }

    @Test("an absent file, a comment and a key Starkit does not know are all no override")
    func ignored() {
        #expect(read("").isEmpty)
        #expect(read("# bun = \"/bin/bun\"").isEmpty)
        #expect(read("shell = \"/bin/fish\"").isEmpty, "a key outside the list is not read")
        #expect(read("[toolchain]\nbun = \"/bin/bun\"") == ["bun": "/bin/bun"], "a table header is not")
        #expect(read("bun").isEmpty, "a line with no equals is not a key")
    }

    @Test("an empty value is a line half-written, not an override")
    func emptyValue() {
        // The Toolchain falls back to the login shell rather than Refusing with a path of "".
        #expect(read("bun = \"\"").isEmpty)
        #expect(read("bun =").isEmpty)
    }

    @Test("only the first equals separates, so a value may contain one")
    func equalsInTheValue() {
        #expect(read("editor = \"Visual Studio Code = 1\"") == ["editor": "Visual Studio Code = 1"])
    }

    @Test("a key given twice keeps the last one")
    func lastWins() {
        #expect(read("bun = /first/bun\nbun = /second/bun") == ["bun": "/second/bun"])
    }
}
