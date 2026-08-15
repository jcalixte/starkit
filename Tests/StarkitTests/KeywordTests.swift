import Foundation
import Testing

@testable import StarkitCore

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

    @Test("a second Keyword resolves to the module that declares it")
    func resolvesShorthand() {
        #expect(Keyword.resolve("yt", in: catalogue) == .one("youtube"))
    }

    @Test("a canonical Keyword resolves to itself")
    func resolvesCanonical() {
        #expect(Keyword.resolve("work", in: catalogue) == .one("work"))
    }

    @Test("resolving ignores case, as the bar does")
    func resolveIgnoresCase() {
        #expect(Keyword.resolve("YT", in: catalogue) == .one("youtube"))
    }

    @Test("a prefix does not resolve, though the bar matches on it")
    func prefixDoesNotResolve() {
        #expect(Keyword.resolve("y", in: catalogue) == .unknown)
        #expect(Keyword.resolve("wo", in: catalogue) == .unknown)
        #expect(Keyword.matches("wo", in: catalogue).map(\.keyword) == ["work"])
    }

    @Test("a word no Script answers to stays unresolved, and so does an empty Catalogue")
    func unknownStaysUnknown() {
        #expect(Keyword.resolve("zzz", in: catalogue) == .unknown)
        #expect(Keyword.resolve("work", in: []) == .unknown)
        #expect(Keyword.resolve("", in: catalogue) == .unknown)
    }

    @Test("a canonical Keyword beats another Script's shorthand instead of being ambiguous")
    func canonicalWinsOverShorthand() {
        let catalogue = self.catalogue + [Manifest(keyword: "yt", name: "Something else")]
        #expect(Keyword.resolve("yt", in: catalogue) == .one("yt"))
    }

    @Test("two Scripts sharing a shorthand is named, not silently picked")
    func sharedShorthandIsAmbiguous() {
        let catalogue = [
            Manifest(keyword: "youtube", name: "Youtube", otherKeywords: ["yt"]),
            Manifest(keyword: "ytdlp", name: "Download with yt-dlp", otherKeywords: ["yt"]),
        ]
        #expect(Keyword.resolve("yt", in: catalogue) == .several(["youtube", "ytdlp"]))
    }
}
