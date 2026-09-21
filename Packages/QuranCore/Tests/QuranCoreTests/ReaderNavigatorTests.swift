import XCTest
@testable import QuranCore

final class ReaderNavigatorTests: XCTestCase {

    private func page(_ number: Int, verses: [(Int, Int)]) -> PageText {
        PageText(
            pageNumber: number,
            verses: verses.map { Verse(surahNumber: $0.0, verseNumber: $0.1, text: "نص") }
        )
    }

    func testNextAndPreviousPage() {
        var navigator = ReaderNavigator(page: 10)
        let forward = navigator.apply(.next(.page))
        XCTAssertEqual(forward.page, 11)
        XCTAssertTrue(forward.pageChanged)
        XCTAssertEqual(forward.direction, .forward)

        let back = navigator.apply(.previous(.page))
        XCTAssertEqual(back.page, 10)
        XCTAssertEqual(back.direction, .backward)
        XCTAssertEqual(navigator.page, 10)
    }

    func testNavigationStopsAtTheCovers() {
        var first = ReaderNavigator(page: 1)
        let before = first.apply(.previous(.page))
        XCTAssertEqual(before.page, 1)
        XCTAssertFalse(before.didMove)

        var last = ReaderNavigator(page: 604)
        let after = last.apply(.next(.page))
        XCTAssertEqual(after.page, 604)
        XCTAssertFalse(after.didMove)
    }

    func testGoToPageClamps() {
        var navigator = ReaderNavigator(page: 1)
        XCTAssertEqual(navigator.apply(.goToPage(9_999)).page, 604)
        XCTAssertEqual(navigator.apply(.goToPage(-3)).page, 1)
        XCTAssertEqual(navigator.apply(.goToPage(255)).page, 255)
        XCTAssertEqual(navigator.apply(.goToPage(255)).didMove, false)
    }

    func testGoToSurahLandsOnItsFirstVerse() {
        var navigator = ReaderNavigator(page: 1)
        let result = navigator.apply(.goToSurah(36))
        XCTAssertEqual(result.page, 440)
        XCTAssertEqual(result.focus, .key("36:1"))
        XCTAssertEqual(navigator.focusedVerseKey, "36:1")
        XCTAssertEqual(navigator.snapshot.surahNumber, 36)
    }

    func testGoToJuz() {
        var navigator = ReaderNavigator(page: 1)
        XCTAssertEqual(navigator.apply(.goToJuz(30)).page, 582)
        XCTAssertEqual(navigator.apply(.goToJuz(31)).page, 582, "an unknown juz' must not move the reader")
    }

    func testVerseStepsWalkDownThePage() {
        let text = page(50, verses: [(3, 1), (3, 2), (3, 3)])
        var navigator = ReaderNavigator(page: 50)

        XCTAssertEqual(navigator.apply(.next(.verse), pageText: text).focus, .key("3:1"))
        XCTAssertEqual(navigator.apply(.next(.verse), pageText: text).focus, .key("3:2"))
        XCTAssertEqual(navigator.apply(.next(.verse), pageText: text).focus, .key("3:3"))

        // Past the last verse, a verse step turns the page.
        let overflow = navigator.apply(.next(.verse), pageText: text)
        XCTAssertEqual(overflow.page, 51)
        XCTAssertEqual(overflow.focus, .first)
        XCTAssertTrue(overflow.pageChanged)
    }

    func testVerseStepsBackwardsCrossToThePreviousPage() {
        let text = page(50, verses: [(3, 1), (3, 2)])
        var navigator = ReaderNavigator(page: 50, focusedVerseKey: "3:1")
        let result = navigator.apply(.previous(.verse), pageText: text)
        XCTAssertEqual(result.page, 49)
        XCTAssertEqual(result.focus, .last)
    }

    func testVerseStepsFallBackToPagesWithoutText() {
        var navigator = ReaderNavigator(page: 100)
        XCTAssertEqual(navigator.apply(.next(.verse), pageText: nil).page, 101)
        XCTAssertEqual(navigator.apply(.previous(.verse), pageText: nil).page, 100)
    }

    func testStaleTextForAnotherPageIsIgnored() {
        let text = page(7, verses: [(2, 40), (2, 41)])
        var navigator = ReaderNavigator(page: 100)
        XCTAssertEqual(navigator.apply(.next(.verse), pageText: text).page, 101)
    }

    func testRequestStateDoesNotMove() {
        var navigator = ReaderNavigator(page: 120, focusedVerseKey: "5:1")
        let result = navigator.apply(.requestState)
        XCTAssertFalse(result.didMove)
        XCTAssertEqual(navigator.page, 120)
        XCTAssertEqual(navigator.focusedVerseKey, "5:1")
    }

    func testSetPageFromTheUIClearsStaleFocus() {
        var navigator = ReaderNavigator(page: 10, focusedVerseKey: "2:100")
        navigator.setPage(11)
        XCTAssertEqual(navigator.page, 11)
        XCTAssertNil(navigator.focusedVerseKey)

        navigator.setPage(11, focus: "2:110")
        XCTAssertEqual(navigator.focusedVerseKey, "2:110")
    }

    func testSnapshotReportsSurahAndJuz() {
        let navigator = ReaderNavigator(page: 293)
        let snapshot = navigator.snapshot
        XCTAssertEqual(snapshot.page, 293)
        XCTAssertEqual(snapshot.surahNumber, 18)
        XCTAssertEqual(snapshot.juz.number, 15)
    }
}
