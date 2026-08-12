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
        Manifest(keyword: "youtube", name: "Youtube", otherKeywords: ["yt"]),
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

    @Test("a second Keyword finds the Script — yt is Youtube")
    func shorthandMatches() {
        #expect(Keyword.matches("yt", in: catalogue).map(\.keyword) == ["youtube"])
    }

    @Test("a second Keyword matches by prefix too, like the canonical one")
    func shorthandPrefix() {
        #expect(Keyword.matches("y", in: catalogue).map(\.keyword) == ["youtube"])
    }

    // The band order, and the reason there is one. A two-letter shorthand is the fastest thing to type
    // in the bar, so it must not be pushed down the list by a Script that merely starts with those
    // letters — while a canonical Keyword typed in full still wins outright.
    @Test("a shorthand typed in full beats another Script's Keyword prefix")
    func exactShorthandBeatsKeywordPrefix() {
        let catalogue =
            self.catalogue + [Manifest(keyword: "ytdlp", name: "Download with yt-dlp")]
        #expect(Keyword.matches("yt", in: catalogue).map(\.keyword) == ["youtube", "ytdlp"])
    }

    @Test("a canonical Keyword typed in full beats another Script's shorthand")
    func canonicalBeatsShorthand() {
        let catalogue = self.catalogue + [Manifest(keyword: "yt", name: "Something else")]
        #expect(Keyword.matches("yt", in: catalogue).first?.keyword == "yt")
    }

    // A Script whose canonical Keyword *and* a second one both match is still one row. Without the
    // bands being exclusive this filtered twice and the bar listed Youtube above Youtube.
    @Test("a Script matching by both names appears once")
    func noDuplicateRow() {
        let catalogue = [Manifest(keyword: "youtube", name: "Youtube", otherKeywords: ["you", "yt"])]
        #expect(Keyword.matches("you", in: catalogue).count == 1)
    }

    @Test("a second Keyword is matched case-insensitively, like everything else typed")
    func shorthandIgnoresCase() {
        #expect(Keyword.matches("YT", in: catalogue).map(\.keyword) == ["youtube"])
    }

    @Test("a Script with only its canonical Keyword still matches exactly as it did")
    func canonicalOnlyUnchanged() {
        #expect(Keyword.matches("wo", in: catalogue).map(\.keyword) == ["work"])
        #expect(Keyword.matches("zzz", in: catalogue).isEmpty)
    }
}
