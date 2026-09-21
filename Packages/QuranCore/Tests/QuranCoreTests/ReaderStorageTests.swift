import XCTest
@testable import QuranCore

final class ReaderStorageTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "quranRemote.tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaultsAreSensibleBeforeAnythingIsSaved() {
        let storage = ReaderStorage(defaults: defaults)
        XCTAssertEqual(storage.lastPage, 1)
        XCTAssertNil(storage.lastVerseKey)
        XCTAssertTrue(storage.bookmarks.isEmpty)
        XCTAssertEqual(storage.preferences, ReaderPreferences())
        XCTAssertTrue(storage.preferences.keepScreenAwake, "the screen must stay on while praying")
    }

    func testPreferencesRoundTrip() {
        let storage = ReaderStorage(defaults: defaults)
        var preferences = ReaderPreferences()
        preferences.fontScale = 1.8
        preferences.theme = .night
        preferences.displayMode = .continuous
        preferences.crownAction = .scrubMushaf
        storage.preferences = preferences

        XCTAssertEqual(ReaderStorage(defaults: defaults).preferences, preferences)
    }

    func testPreferencesDecodeLenientlyWhenKeysAreMissing() throws {
        // Stands in for a build that predates a newly added preference.
        let partial = Data(#"{"fontScale": 1.3, "theme": "dark"}"#.utf8)
        let decoded = try JSONDecoder().decode(ReaderPreferences.self, from: partial)
        XCTAssertEqual(decoded.fontScale, 1.3)
        XCTAssertEqual(decoded.theme, .dark)
        XCTAssertEqual(decoded.displayMode, ReaderPreferences().displayMode)
        XCTAssertEqual(decoded.crownAction, ReaderPreferences().crownAction)
    }

    func testFontScaleIsClamped() {
        var preferences = ReaderPreferences()
        preferences.fontScale = 12
        XCTAssertEqual(preferences.clampedFontScale, ReaderPreferences.fontScaleRange.upperBound)
        preferences.fontScale = 0.01
        XCTAssertEqual(preferences.clampedFontScale, ReaderPreferences.fontScaleRange.lowerBound)
    }

    func testLastPageIsClampedOnTheWayInAndOut() {
        let storage = ReaderStorage(defaults: defaults)
        storage.lastPage = 9_999
        XCTAssertEqual(storage.lastPage, 604)
        storage.lastPage = 0
        XCTAssertEqual(storage.lastPage, 1)
        storage.lastPage = 305
        XCTAssertEqual(storage.lastPage, 305)
    }

    func testBookmarksAreKeptInPageOrderAndDeduplicated() {
        let storage = ReaderStorage(defaults: defaults)
        storage.addBookmark(Bookmark(page: 293, verseKey: "18:1", note: "Friday"))
        storage.addBookmark(Bookmark(page: 2))
        storage.addBookmark(Bookmark(page: 293, verseKey: "18:1", note: "Friday again"))

        XCTAssertEqual(storage.bookmarks.map(\.page), [2, 293])
        XCTAssertEqual(storage.bookmarks.last?.note, "Friday again")

        let id = try? XCTUnwrap(storage.bookmarks.first?.id)
        if let id { storage.removeBookmark(id: id) }
        XCTAssertEqual(storage.bookmarks.map(\.page), [293])
    }

    func testBookmarkPageIsClamped() {
        XCTAssertEqual(Bookmark(page: 700).page, 604)
        XCTAssertEqual(Bookmark(page: 293).surah.number, 18)
    }
}
