import XCTest
@testable import QuranCore

final class PageTextTests: XCTestCase {

    private let alQuranCloudJSON = """
    {
      "code": 200,
      "status": "OK",
      "data": {
        "number": 2,
        "ayahs": [
          {
            "number": 8,
            "text": "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ الٓمٓ",
            "numberInSurah": 1,
            "surah": { "number": 2, "name": "سورة البقرة" }
          },
          {
            "number": 9,
            "text": "ذَٰلِكَ ٱلْكِتَٰبُ لَا رَيْبَ ۛ فِيهِ",
            "numberInSurah": 2,
            "surah": { "number": 2, "name": "سورة البقرة" }
          }
        ]
      }
    }
    """

    private let quranComJSON = """
    {
      "verses": [
        { "id": 1, "verse_key": "18:1", "text_uthmani": "ٱلْحَمْدُ لِلَّهِ" },
        { "id": 2, "verse_key": "18:2", "text_uthmani": "قَيِّمًا لِّيُنذِرَ" },
        { "id": 3, "verse_key": "not-a-key", "text_uthmani": "يُهمَل" }
      ]
    }
    """

    func testAlQuranCloudParsing() throws {
        let page = try AlQuranCloudProvider.parse(Data(alQuranCloudJSON.utf8), page: 2)
        XCTAssertEqual(page.pageNumber, 2)
        XCTAssertEqual(page.verses.count, 2)
        XCTAssertEqual(page.verses.first?.key, "2:1")
        XCTAssertEqual(page.surahNumbers, [2])
        XCTAssertEqual(page.leadingSurah?.transliteratedName, "Al-Baqarah")
    }

    func testAlQuranCloudParsingStripsTheLeadingBasmalah() throws {
        let page = try AlQuranCloudProvider.parse(Data(alQuranCloudJSON.utf8), page: 2)
        let firstVerse = try XCTUnwrap(page.verses.first)
        XCTAssertFalse(
            QuranText.normalizedLetters(firstVerse.text)
                .hasPrefix(QuranText.normalizedLetters(QuranText.basmalah)),
            "the basmalah is drawn as a surah header, not as part of verse 1"
        )
        XCTAssertEqual(QuranText.normalizedLetters(firstVerse.text), QuranText.normalizedLetters("الٓمٓ"))
    }

    func testQuranComParsingSkipsMalformedVerses() throws {
        let page = try QuranComProvider.parse(Data(quranComJSON.utf8), page: 293)
        XCTAssertEqual(page.verses.map(\.key), ["18:1", "18:2"])
    }

    func testEmptyPagesAreAnError() {
        XCTAssertThrowsError(try QuranComProvider.parse(Data(#"{"verses": []}"#.utf8), page: 1))
        XCTAssertThrowsError(try AlQuranCloudProvider.parse(Data("not json".utf8), page: 1))
    }

    func testBasmalahIsKeptWhereItBelongs() {
        // Al-Fatihah: the basmalah *is* verse 1.
        let fatihah = QuranText.strippingBasmalah(from: QuranText.basmalah, surahNumber: 1, verseNumber: 1)
        XCTAssertEqual(fatihah, QuranText.basmalah)

        // At-Tawbah has no basmalah at all.
        let tawbah = QuranText.strippingBasmalah(from: "بَرَآءَةٌ مِّنَ ٱللَّهِ", surahNumber: 9, verseNumber: 1)
        XCTAssertEqual(tawbah, "بَرَآءَةٌ مِّنَ ٱللَّهِ")

        // Mid-surah verses are never touched.
        let middle = QuranText.strippingBasmalah(from: QuranText.basmalah, surahNumber: 27, verseNumber: 30)
        XCTAssertEqual(middle, QuranText.basmalah)

        // A first verse that is only the basmalah is left alone rather than
        // turned into an empty verse.
        let onlyBasmalah = QuranText.strippingBasmalah(from: QuranText.basmalah, surahNumber: 2, verseNumber: 1)
        XCTAssertEqual(onlyBasmalah, QuranText.basmalah)
    }

    func testNormalisationFoldsSpellingDifferences() {
        XCTAssertEqual(
            QuranText.normalizedLetters("بِسْمِ ٱللَّهِ"),
            QuranText.normalizedLetters("بسم الله")
        )
        XCTAssertEqual(QuranText.normalizedLetters("الرَّحْمَٰنِ"), QuranText.normalizedLetters("الرحمن"))
    }

    func testSurahRunsSplitAPageThatOpensANewSurah() {
        let page = PageText(pageNumber: 604, verses: [
            Verse(surahNumber: 112, verseNumber: 4, text: "و"),
            Verse(surahNumber: 113, verseNumber: 1, text: "ق"),
            Verse(surahNumber: 113, verseNumber: 2, text: "م")
        ])
        let runs = page.surahRuns()
        XCTAssertEqual(runs.count, 2)
        XCTAssertFalse(runs[0].startsSurah, "a surah continued from the previous page gets no header")
        XCTAssertTrue(runs[1].startsSurah)
        XCTAssertEqual(runs[1].verses.count, 2)
    }

    func testVerseMarkersUseArabicNumerals() {
        XCTAssertEqual(ArabicNumerals.string(from: 0), "٠")
        XCTAssertEqual(ArabicNumerals.string(from: 255), "٢٥٥")
        XCTAssertEqual(ArabicNumerals.string(from: 604), "٦٠٤")
        XCTAssertEqual(
            Verse(surahNumber: 2, verseNumber: 7, text: "x").endOfVerseMarker,
            "\u{06DD}٧"
        )
    }

    func testIndexLookup() {
        let page = PageText(pageNumber: 1, verses: [
            Verse(surahNumber: 1, verseNumber: 1, text: "a"),
            Verse(surahNumber: 1, verseNumber: 2, text: "b")
        ])
        XCTAssertEqual(page.index(ofVerseWithKey: "1:2"), 1)
        XCTAssertNil(page.index(ofVerseWithKey: "9:9"))
        XCTAssertEqual(page.verse(withKey: "1:1")?.text, "a")
    }
}
