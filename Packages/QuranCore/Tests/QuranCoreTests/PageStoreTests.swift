import XCTest
@testable import QuranCore

/// Serves canned pages and counts how often it was asked.
private actor StubProvider: PageTextProviding {
    nonisolated let name = "stub"
    private(set) var requests: [Int] = []
    private let failingPages: Set<Int>

    init(failingPages: Set<Int> = []) {
        self.failingPages = failingPages
    }

    func requestCount(for page: Int) -> Int {
        requests.filter { $0 == page }.count
    }

    func totalRequests() -> Int { requests.count }

    func fetchPage(_ page: Int) async throws -> PageText {
        requests.append(page)
        if failingPages.contains(page) {
            throw QuranTextError.badResponse(status: 500)
        }
        return PageText(
            pageNumber: page,
            verses: [Verse(surahNumber: Mushaf.primarySurah(forPage: page).number, verseNumber: 1, text: "page \(page)")]
        )
    }
}

private struct AlwaysFailingProvider: PageTextProviding {
    let name = "failing"
    func fetchPage(_ page: Int) async throws -> PageText {
        throw QuranTextError.badResponse(status: 503)
    }
}

final class PageStoreTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuranStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testFetchesOnceThenServesFromCache() async throws {
        let provider = StubProvider()
        let store = PageStore(provider: provider, directory: directory)

        let first = try await store.page(42)
        let second = try await store.page(42)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.pageNumber, 42)
        let count = await provider.requestCount(for: 42)
        XCTAssertEqual(count, 1, "a cached page must not hit the network again")
    }

    func testCachedPagesSurviveANewStore() async throws {
        let provider = StubProvider()
        let store = PageStore(provider: provider, directory: directory)
        _ = try await store.page(7)

        // A fresh store over the same directory stands in for a relaunch.
        let coldProvider = StubProvider()
        let coldStore = PageStore(provider: coldProvider, directory: directory)
        let cached = await coldStore.cachedPage(7)

        XCTAssertEqual(cached?.pageNumber, 7)
        let requests = await coldProvider.totalRequests()
        XCTAssertEqual(requests, 0, "page 7 came off disk, so nothing was fetched")
    }

    func testCachedPageIsNilBeforeAnythingIsDownloaded() async {
        let store = PageStore(provider: StubProvider(), directory: directory)
        let cached = await store.cachedPage(500)
        XCTAssertNil(cached)
    }

    func testInvalidPagesAreRejected() async {
        let store = PageStore(provider: StubProvider(), directory: directory)
        do {
            _ = try await store.page(605)
            XCTFail("page 605 does not exist")
        } catch {
            XCTAssertEqual(error as? QuranTextError, .invalidPage(605))
        }
    }

    func testFailuresPropagateAndAreNotCached() async throws {
        let provider = StubProvider(failingPages: [3])
        let store = PageStore(provider: provider, directory: directory)

        do {
            _ = try await store.page(3)
            XCTFail("expected the provider's failure to surface")
        } catch {
            XCTAssertEqual(error as? QuranTextError, .badResponse(status: 500))
        }
        let cached = await store.cachedPage(3)
        XCTAssertNil(cached, "a failed fetch must not leave a hole in the cache")
    }

    func testDownloadReportsProgressAndFillsTheCache() async throws {
        let store = PageStore(provider: StubProvider(), directory: directory)
        // Seed a couple of pages so the "already downloaded" path is exercised.
        _ = try await store.page(1)

        let recorded = ProgressRecorder()
        try await store.downloadWholeMushaf(concurrency: 8) { progress in
            recorded.record(progress)
        }

        let downloaded = await store.downloadedPageCount()
        XCTAssertEqual(downloaded, Mushaf.pageCount)
        XCTAssertEqual(recorded.last?.completed, Mushaf.pageCount)
        XCTAssertEqual(recorded.last?.fraction, 1.0)
        XCTAssertTrue(recorded.isMonotonic, "progress must never go backwards")
    }

    func testClearingTheCacheRemovesEverything() async throws {
        let store = PageStore(provider: StubProvider(), directory: directory)
        _ = try await store.page(10)
        try await store.clearCache()

        let count = await store.downloadedPageCount()
        XCTAssertEqual(count, 0)
        let cached = await store.cachedPage(10)
        XCTAssertNil(cached)
    }

    func testFallbackProviderTriesTheNextSource() async throws {
        let backup = StubProvider()
        let provider = FallbackPageTextProvider(providers: [AlwaysFailingProvider(), backup])
        let page = try await provider.fetchPage(100)
        XCTAssertEqual(page.pageNumber, 100)
        let requests = await backup.totalRequests()
        XCTAssertEqual(requests, 1)
    }

    func testFallbackProviderSurfacesTheLastFailure() async {
        let provider = FallbackPageTextProvider(providers: [AlwaysFailingProvider(), AlwaysFailingProvider()])
        do {
            _ = try await provider.fetchPage(1)
            XCTFail("expected a failure when every source is down")
        } catch {
            XCTAssertEqual(error as? QuranTextError, .badResponse(status: 503))
        }
    }
}

/// Collects progress callbacks, which arrive from the download's task group.
private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [PageStore.DownloadProgress] = []

    func record(_ progress: PageStore.DownloadProgress) {
        lock.lock()
        values.append(progress)
        lock.unlock()
    }

    var last: PageStore.DownloadProgress? {
        lock.lock()
        defer { lock.unlock() }
        return values.last
    }

    var isMonotonic: Bool {
        lock.lock()
        defer { lock.unlock() }
        return zip(values, values.dropFirst()).allSatisfy { $0.completed <= $1.completed }
    }
}
