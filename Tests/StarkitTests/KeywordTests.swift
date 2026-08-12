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

    // What `Starkit run <keyword>` resolves before it builds anything. Everything below the resolution
    // is addressed by the canonical Keyword, because that is the module name on disk.

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

    // The whole reason this is not just `matches().first`. In the bar a prefix is safe because the row
    // it picked is on screen before ↩ reaches it; at a terminal `run c` would be Clean force-quitting
    // every application on the machine with nothing shown in between.
    @Test("a prefix does not resolve, though the bar matches on it")
    func prefixDoesNotResolve() {
        #expect(Keyword.resolve("y", in: catalogue) == .unknown)
        #expect(Keyword.resolve("wo", in: catalogue) == .unknown)
        #expect(Keyword.matches("wo", in: catalogue).map(\.keyword) == ["work"])
    }

    // Unknown rather than a refusal, so the caller keeps the word and C5 refuses it against a real
    // path: an empty manifests.json is a home that has never been listed, not a home with no Scripts.
    @Test("a word no Script answers to stays unresolved, and so does an empty Catalogue")
    func unknownStaysUnknown() {
        #expect(Keyword.resolve("zzz", in: catalogue) == .unknown)
        #expect(Keyword.resolve("work", in: []) == .unknown)
        #expect(Keyword.resolve("", in: catalogue) == .unknown)
    }

    // The band order decides this rather than a tie being declared — the same rule that makes the bar
    // list `yt` above Youtube when both answer to it.
    @Test("a canonical Keyword beats another Script's shorthand instead of being ambiguous")
    func canonicalWinsOverShorthand() {
        let catalogue = self.catalogue + [Manifest(keyword: "yt", name: "Something else")]
        #expect(Keyword.resolve("yt", in: catalogue) == .one("yt"))
    }

    // Two Scripts can declare the same shorthand — nothing stops them, since only the canonical
    // Keyword has to be unique. The bar picks the first row; a terminal has no row to show, so it says
    // so and runs neither.
    @Test("two Scripts sharing a shorthand is named, not silently picked")
    func sharedShorthandIsAmbiguous() {
        let catalogue = [
            Manifest(keyword: "youtube", name: "Youtube", otherKeywords: ["yt"]),
            Manifest(keyword: "ytdlp", name: "Download with yt-dlp", otherKeywords: ["yt"]),
        ]
        #expect(Keyword.resolve("yt", in: catalogue) == .several(["youtube", "ytdlp"]))
    }
}
