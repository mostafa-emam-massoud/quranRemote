import XCTest
@testable import QuranCore

final class MushafDataTests: XCTestCase {

    func testThereAre114Surahs() {
        XCTAssertEqual(MushafData.surahs.count, 114)
        XCTAssertEqual(MushafData.surahs.map(\.number), Array(1...114))
    }

    func testVerseCountsSumToTheWholeQuran() {
        XCTAssertEqual(MushafData.surahs.reduce(0) { $0 + $1.verseCount }, 6236)
    }

    func testSurahStartPagesAreOrderedAndInsideTheMushaf() {
        let pages = MushafData.surahs.map(\.startPage)
        XCTAssertEqual(pages, pages.sorted())
        XCTAssertEqual(pages.first, 1)
        XCTAssertEqual(pages.last, 604)
        XCTAssertTrue(pages.allSatisfy { Mushaf.pageRange.contains($0) })
    }

    func testKnownSurahLandmarks() {
        XCTAssertEqual(Mushaf.startPage(ofSurah: 1), 1)
        XCTAssertEqual(Mushaf.startPage(ofSurah: 2), 2)
        XCTAssertEqual(Mushaf.startPage(ofSurah: 18), 293)
        XCTAssertEqual(Mushaf.startPage(ofSurah: 36), 440)
        XCTAssertEqual(Mushaf.startPage(ofSurah: 67), 562)
        XCTAssertEqual(Mushaf.startPage(ofSurah: 114), 604)
        XCTAssertEqual(Mushaf.surah(number: 2)?.verseCount, 286)
        XCTAssertEqual(Mushaf.surah(number: 108)?.verseCount, 3)
    }

    func testJuzTableCoversTheMushaf() {
        XCTAssertEqual(MushafData.juzs.count, 30)
        XCTAssertEqual(MushafData.juzs.first?.startPage, 1)
        XCTAssertEqual(MushafData.juzs.last?.startPage, 582)
        XCTAssertEqual(MushafData.juzs.map(\.startPage), MushafData.juzs.map(\.startPage).sorted())
    }

    func testJuzForPage() {
        XCTAssertEqual(Mushaf.juz(forPage: 1).number, 1)
        XCTAssertEqual(Mushaf.juz(forPage: 21).number, 1)
        XCTAssertEqual(Mushaf.juz(forPage: 22).number, 2)
        XCTAssertEqual(Mushaf.juz(forPage: 582).number, 30)
        XCTAssertEqual(Mushaf.juz(forPage: 604).number, 30)
    }

    func testPrimarySurahForPage() {
        XCTAssertEqual(Mushaf.primarySurah(forPage: 1).number, 1)
        XCTAssertEqual(Mushaf.primarySurah(forPage: 3).number, 2)
        XCTAssertEqual(Mushaf.primarySurah(forPage: 604).number, 114)
    }

    func testSurahsStartingOnASharedPage() {
        // Pages near the end of the mushaf open several short surahs.
        XCTAssertEqual(Mushaf.surahsStarting(onPage: 604).map(\.number), [112, 113, 114])
        XCTAssertTrue(Mushaf.surahsStarting(onPage: 300).isEmpty)
    }

    func testClampKeepsNavigationInsideTheMushaf() {
        XCTAssertEqual(Mushaf.clamp(page: 0), 1)
        XCTAssertEqual(Mushaf.clamp(page: -40), 1)
        XCTAssertEqual(Mushaf.clamp(page: 900), 604)
        XCTAssertEqual(Mushaf.clamp(page: 300), 300)
    }

    func testEstimatedPageForVerseStaysWithinTheSurah() {
        for surah in MushafData.surahs {
            let next = Mushaf.surah(number: surah.number + 1)?.startPage ?? Mushaf.lastPage
            let page = Mushaf.estimatedPage(ofSurah: surah.number, verse: surah.verseCount)
            XCTAssertGreaterThanOrEqual(page, surah.startPage)
            XCTAssertLessThanOrEqual(page, next)
        }
        XCTAssertEqual(Mushaf.estimatedPage(ofSurah: 2, verse: 1), 2)
    }

    func testProgress() {
        XCTAssertEqual(Mushaf.progress(forPage: 1), 0, accuracy: 0.0001)
        XCTAssertEqual(Mushaf.progress(forPage: 604), 1, accuracy: 0.0001)
    }
}
