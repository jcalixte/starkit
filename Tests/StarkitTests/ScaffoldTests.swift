import Foundation
import Testing

@testable import StarkitCore

/// What the bar is allowed to offer, and what it writes when the offer is taken.
struct ScaffoldTests {
    @Test("a lowercase word is a Keyword")
    func plainWord() {
        #expect(Scaffold.isValid("notes"))
        #expect(Scaffold.isValid("daily_notes"))
        #expect(Scaffold.isValid("todo2"))
    }

    // Each of these would land as `import scripts/<keyword>` in a generated module, so the offer has
    // to be withheld rather than the name repaired: what Gleam rejects, the bar must not promise.
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

    // The template's whole job is to compile on arrival: C6 builds it within 200 ms of the file
    // appearing, so a template with a hole in it would turn the menu bar red as its welcome. This
    // pins the shape; that it *compiles* was checked by writing one and letting C6 build it (T9.3).
    @Test("the template declares the Keyword it was asked for, and decides nothing")
    func template() {
        let source = Scaffold.source(for: "daily_notes")
        #expect(source.contains("import starkit.{type Script, Decides, Script}"))
        #expect(source.contains("pub fn script() -> Script {"))
        #expect(source.contains(#"keyword: "daily_notes","#))
        #expect(source.contains(#"name: "Daily notes","#))
        #expect(source.contains("needs: [],"))
        #expect(source.contains("asks: Decides,"))
        // Returns no Effects: a template that did something would be a Script nobody asked to run.
        #expect(source.contains("      []\n"))
        // Exactly one trailing newline, like the registry and for the same reason: a file `gleam
        // format` would rewrite is a file whose mtime moves later, and this one is about to be opened
        // in an editor that formats on save.
        #expect(source.hasSuffix("}\n"))
        #expect(!source.hasSuffix("}\n\n"))
    }
}
