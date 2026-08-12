import Foundation
import Testing

@testable import StarkitCore

/// The three cases SPEC names, and the two the bar would be broken without.
struct KeywordTests {
    private let catalogue = [
        Manifest(keyword: "clean", name: "Clean", needs: ["running_apps"]),
        Manifest(keyword: "link", name: "Link from url"),
        Manifest(keyword: "personal", name: "Personal"),
        Manifest(keyword: "work", name: "Work"),
        Manifest(keyword: "youtube", name: "Youtube"),
    ]

    @Test("the first token is the Keyword and the rest is the Input")
    func splitsAtTheFirstSpace() {
        let typed = Keyword.split("youtube https://youtu.be/dQw4w9WgXcQ")
        #expect(typed.keyword == "youtube")
        #expect(typed.input == "https://youtu.be/dQw4w9WgXcQ")
    }

    @Test("a Keyword with nothing after it has an empty Input, not a missing one")
    func keywordAlone() {
        let typed = Keyword.split("  work  ")
        #expect(typed.keyword == "work")
        #expect(typed.input == "")
    }

    // The Input is handed to a Script verbatim, so its own spacing is not Starkit's to tidy — a
    // page title has spaces in it and arrives through this path.
    @Test("the Input keeps the spaces inside it")
    func inputIsVerbatim() {
        #expect(Keyword.split("link  a  b").input == "a  b")
    }

    @Test("a Keyword that matches nothing selects nothing")
    func noMatch() {
        #expect(Keyword.matches("zzz", in: catalogue).isEmpty)
    }

    @Test("nothing typed selects every Script")
    func nothingTyped() {
        #expect(Keyword.matches("", in: catalogue) == catalogue)
    }

    @Test("a prefix selects every Script it starts, in the order they were reported")
    func prefixMatches() {
        #expect(Keyword.matches("l", in: catalogue).map(\.keyword) == ["link"])
        #expect(Keyword.matches("WO", in: catalogue).map(\.keyword) == ["work"])
    }

    // Typing `link` in full must run Link, not the Script that merely starts the same way — while
    // both stay listed, because the longer one is still reachable by typing more of it.
    @Test("a Keyword that prefixes another lists both, the exact one first")
    func exactBeforeLonger() {
        let ambiguous =
            catalogue + [
                Manifest(keyword: "linkedin", name: "LinkedIn"),
                Manifest(keyword: "linkroll", name: "Linkroll"),
            ]
        #expect(
            Keyword.matches("link", in: ambiguous).map(\.keyword) == ["link", "linkedin", "linkroll"]
        )
        #expect(
            Keyword.matches("linked", in: ambiguous).map(\.keyword) == ["linkedin"]
        )
    }
}
