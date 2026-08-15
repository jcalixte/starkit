import Foundation
import Testing

@testable import StarkitCore

struct ScaffoldTests {
    @Test("a lowercase word is a Keyword")
    func plainWord() {
        #expect(Scaffold.isValid("notes"))
        #expect(Scaffold.isValid("daily_notes"))
        #expect(Scaffold.isValid("todo2"))
    }

    @Test("what Gleam would not accept as a module name is not offered")
    func notAModuleName() {
        #expect(!Scaffold.isValid(""))
        #expect(!Scaffold.isValid("Notes"), "a capital is not a Gleam module name")
        #expect(!Scaffold.isValid("2fast"), "a module name cannot start with a digit")
        #expect(!Scaffold.isValid("_hidden"), "nor with an underscore")
        #expect(!Scaffold.isValid("my notes"), "nor hold a space")
        #expect(!Scaffold.isValid("my-notes"), "nor a hyphen")
        #expect(!Scaffold.isValid("notes.gleam"), "nor the extension")
        #expect(!Scaffold.isValid("café"), "nor anything outside ASCII")
    }

    @Test("the name is the Keyword made readable")
    func derivedName() {
        #expect(Scaffold.name(for: "notes") == "Notes")
        #expect(Scaffold.name(for: "daily_notes") == "Daily notes")
        #expect(Scaffold.name(for: "a") == "A")
    }

    @Test("the template declares the Keyword it was asked for, and decides nothing")
    func template() {
        let source = Scaffold.source(for: "daily_notes")
        #expect(source.contains("import starkit.{type Script, Decides, Script}"))
        #expect(source.contains("pub fn script() -> Script {"))
        #expect(source.contains(#"keyword: "daily_notes","#))
        #expect(source.contains(#"name: "Daily notes","#))
        #expect(source.contains("needs: [],"))
        #expect(source.contains("asks: Decides,"))
        #expect(source.contains("      []\n"))
        // Exactly one trailing newline: a file `gleam format` would rewrite is a file whose mtime
        // moves later, and this one is about to be opened in an editor that formats on save.
        #expect(source.hasSuffix("}\n"))
        #expect(!source.hasSuffix("}\n\n"))
    }
}
