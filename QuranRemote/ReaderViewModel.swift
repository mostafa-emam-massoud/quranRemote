import Combine
import QuranCore
import QuranLink
import SwiftUI
import UIKit

/// Drives the reader on iPhone and iPad.
///
/// Every way of moving through the mushaf — a swipe, the page slider, the
/// surah list, the watch, a linked iPad — ends up in `ReaderNavigator`, and
/// every move is broadcast back out so the other devices stay in step.
@MainActor
final class ReaderViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var navigator: ReaderNavigator
    @Published private(set) var pages: [Int: PageText] = [:]
    @Published private(set) var loadingPages: Set<Int> = []
    @Published private(set) var failures: [Int: String] = [:]
    @Published private(set) var bookmarks: [Bookmark] = []
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var downloadedPageCount: Int = 0
    @Published private(set) var watchIsReachable: Bool = false
    @Published private(set) var watchAppIsInstalled: Bool = false
    @Published private(set) var nearbyDeviceNames: [String] = []
    @Published private(set) var scrollRequest: ScrollRequest?
    /// Shown briefly in the header so it is obvious the watch got through.
    @Published private(set) var lastRemoteAction: String?

    @Published var preferences: ReaderPreferences {
        didSet {
            guard preferences != oldValue else { return }
            storage.preferences = preferences
            applyPreferenceSideEffects(previous: oldValue)
        }
    }

    // MARK: - Collaborators

    private let store: PageStore
    private let storage: ReaderStorage
    private let watchLink: WatchLink
    private var cancellables: Set<AnyCancellable> = []
    private var downloadTask: Task<Void, Never>?
    private var pendingFocus: VerseAnchor = .none
    private var scrollToken = 0
    private var isApplyingRemoteState = false
    private var hasStarted = false

    init(
        store: PageStore = PageStore(),
        storage: ReaderStorage = ReaderStorage(),
        watchLink: WatchLink = .shared
    ) {
        self.store = store
        self.storage = storage
        self.watchLink = watchLink
        self.preferences = storage.preferences
        self.navigator = ReaderNavigator(page: storage.lastPage, focusedVerseKey: storage.lastVerseKey)
        self.bookmarks = storage.bookmarks
    }

    // MARK: - Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        subscribeToWatch()
        subscribeToNearbyDevices()
        watchLink.activate()
        if preferences.nearbyLinkEnabled {
            startNearbyLink()
        }
        UIApplication.shared.isIdleTimerDisabled = preferences.keepScreenAwake

        ensureLoaded(page: page)
        prefetchAround(page: page)
        refreshDownloadedCount()
        broadcastState()
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .active:
            UIApplication.shared.isIdleTimerDisabled = preferences.keepScreenAwake
            broadcastState()
        case .background, .inactive:
            persist()
        @unknown default:
            break
        }
    }

    // MARK: - Where we are

    var page: Int { navigator.page }
    var focusedVerseKey: String? { navigator.focusedVerseKey }
    var currentPageText: PageText? { pages[page] }
    var currentSurah: Surah {
        currentPageText?.leadingSurah ?? Mushaf.primarySurah(forPage: page)
    }
    var currentJuz: Juz { Mushaf.juz(forPage: page) }
    var isCurrentPageBookmarked: Bool { bookmarks.contains { $0.page == page } }

    func text(for page: Int) -> PageText? { pages[page] }
    func isLoading(page: Int) -> Bool { loadingPages.contains(page) }
    func failure(for page: Int) -> String? { failures[page] }

    // MARK: - Navigation

    /// A move the person made on this device.
    func perform(_ command: RemoteCommand) {
        apply(command, source: .local)
    }

    /// A page reached by swiping or scrolling, rather than by a command.
    func userDidReach(page newPage: Int) {
        guard newPage != navigator.page else { return }
        navigator.setPage(newPage)
        pendingFocus = .none
        afterMove(pageChanged: true, playHaptic: false)
    }

    func focusVerse(_ verse: Verse) {
        guard verse.key != navigator.focusedVerseKey else {
            navigator.setFocus(verseKey: nil)
            broadcastState()
            return
        }
        navigator.setFocus(verseKey: verse.key)
        afterMove(pageChanged: false, playHaptic: false)
    }

    func toggleBookmark() {
        if let existing = bookmarks.first(where: { $0.page == page }) {
            storage.removeBookmark(id: existing.id)
        } else {
            storage.addBookmark(Bookmark(page: page, verseKey: focusedVerseKey))
        }
        bookmarks = storage.bookmarks
    }

    func removeBookmark(_ bookmark: Bookmark) {
        storage.removeBookmark(id: bookmark.id)
        bookmarks = storage.bookmarks
    }

    // MARK: - Loading

    func ensureLoaded(page target: Int) {
        guard Mushaf.isValid(page: target), pages[target] == nil, !loadingPages.contains(target) else { return }
        loadingPages.insert(target)
        Task { [self, store] in
            do {
                let text = try await store.page(target)
                self.pages[target] = text
                self.failures[target] = nil
                self.resolvePendingFocus(using: text)
            } catch {
                self.failures[target] = error.localizedDescription
            }
            self.loadingPages.remove(target)
        }
    }

    func retry(page target: Int) {
        failures[target] = nil
        ensureLoaded(page: target)
    }

    private func prefetchAround(page target: Int) {
        let neighbours = [target - 1, target + 1, target + 2].filter { Mushaf.isValid(page: $0) }
        Task { [store] in
            await store.prefetch(pages: neighbours)
        }
    }

    // MARK: - Offline download

    enum DownloadState: Equatable {
        case idle
        case running(completed: Int, total: Int)
        case finished
        case failed(String)

        var fraction: Double {
            switch self {
            case .running(let completed, let total): return total > 0 ? Double(completed) / Double(total) : 0
            case .finished: return 1
            case .idle, .failed: return 0
            }
        }

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    func downloadWholeMushaf() {
        guard !downloadState.isRunning else { return }
        downloadState = .running(completed: 0, total: Mushaf.pageCount)
        downloadTask = Task { [self, store] in
            do {
                try await store.downloadWholeMushaf { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadState = .running(completed: progress.completed, total: progress.total)
                    }
                }
                self.downloadState = .finished
            } catch is CancellationError {
                self.downloadState = .idle
            } catch {
                self.downloadState = .failed(error.localizedDescription)
            }
            self.refreshDownloadedCount()
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadState = .idle
    }

    func clearDownloads() {
        Task { [self, store] in
            try? await store.clearCache()
            self.pages.removeAll()
            self.downloadState = .idle
            self.refreshDownloadedCount()
            self.ensureLoaded(page: self.page)
        }
    }

    private func refreshDownloadedCount() {
        Task { [self, store] in
            self.downloadedPageCount = await store.downloadedPageCount()
        }
    }

    // MARK: - Remote links

    private func subscribeToWatch() {
        watchLink.commands
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                self?.apply(command, source: .watch)
            }
            .store(in: &cancellables)

        watchLink.reachabilityUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reachable in
                self?.watchIsReachable = reachable
                // A watch that just woke up needs to be told where we are.
                if reachable { self?.broadcastState() }
            }
            .store(in: &cancellables)

        watchLink.installationUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] installed in
                self?.watchAppIsInstalled = installed
            }
            .store(in: &cancellables)
    }

    private func subscribeToNearbyDevices() {
        let nearby = NearbyLink.shared

        nearby.commands
            .receive(on: DispatchQueue.main)
            .sink { [weak self] command in
                self?.apply(command, source: .nearby)
            }
            .store(in: &cancellables)

        nearby.states
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.applyRemote(state: state)
            }
            .store(in: &cancellables)

        nearby.connectedDeviceUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] names in
                self?.nearbyDeviceNames = names
            }
            .store(in: &cancellables)
    }

    private func startNearbyLink() {
        NearbyLink.shared.start(displayName: UIDevice.current.name)
    }

    private enum CommandSource {
        case local
        case watch
        case nearby
    }

    private func apply(_ command: RemoteCommand, source: CommandSource) {
        if case .requestState = command {
            broadcastState()
            return
        }

        let result = navigator.apply(command, pageText: pages[navigator.page])

        if source != .local {
            lastRemoteAction = command.shortDescription
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self?.lastRemoteAction = nil
            }
        }

        // A command from the watch is relayed on to a linked iPad, which is how
        // the watch drives a device it cannot pair with.
        if source == .watch, preferences.nearbyLinkEnabled {
            NearbyLink.shared.send(command: command)
        }

        pendingFocus = result.focus
        requestScroll(for: result)
        afterMove(pageChanged: result.pageChanged, playHaptic: result.didMove && source != .local)
    }

    private func applyRemote(state: ReaderStateSnapshot) {
        guard state.page != navigator.page || state.verseKey != navigator.focusedVerseKey else { return }
        isApplyingRemoteState = true
        navigator.setPage(state.page, focus: state.verseKey)
        isApplyingRemoteState = false
        afterMove(pageChanged: true, playHaptic: false)
    }

    private func afterMove(pageChanged: Bool, playHaptic: Bool) {
        ensureLoaded(page: page)
        prefetchAround(page: page)
        persist()
        if !isApplyingRemoteState {
            broadcastState()
        }
        if playHaptic, preferences.hapticOnPageTurn {
            Haptics.pageTurn()
        }
    }

    private func broadcastState() {
        let snapshot = navigator.snapshot
        watchLink.publish(state: snapshot)
        if preferences.nearbyLinkEnabled {
            NearbyLink.shared.publish(state: snapshot)
        }
    }

    private func persist() {
        storage.lastPage = navigator.page
        storage.lastVerseKey = navigator.focusedVerseKey
    }

    // MARK: - Scrolling

    struct ScrollRequest: Equatable {
        let anchorID: String
        let page: Int
        let unitPoint: UnitPoint
        let token: Int
    }

    private func requestScroll(for result: NavigationResult) {
        switch result.focus {
        case .key(let key):
            requestScroll(to: key, page: result.page, unitPoint: .center)
        case .first:
            requestScroll(to: PageAnchor.top(result.page), page: result.page, unitPoint: .top)
        case .last:
            requestScroll(to: PageAnchor.bottom(result.page), page: result.page, unitPoint: .bottom)
        case .none:
            requestScroll(to: PageAnchor.top(result.page), page: result.page, unitPoint: .top)
        }
    }

    private func requestScroll(to anchorID: String, page: Int, unitPoint: UnitPoint) {
        scrollToken += 1
        scrollRequest = ScrollRequest(anchorID: anchorID, page: page, unitPoint: unitPoint, token: scrollToken)
    }

    /// Turns a `.first`/`.last` anchor into a real verse once the page arrives.
    private func resolvePendingFocus(using text: PageText) {
        guard text.pageNumber == navigator.page else { return }
        switch pendingFocus {
        case .last:
            if let last = text.verses.last {
                navigator.setFocus(verseKey: last.key)
                requestScroll(to: last.key, page: text.pageNumber, unitPoint: .center)
            }
        case .first, .none, .key:
            break
        }
        pendingFocus = .none
    }

    // MARK: - Preferences

    private func applyPreferenceSideEffects(previous: ReaderPreferences) {
        UIApplication.shared.isIdleTimerDisabled = preferences.keepScreenAwake

        if preferences.nearbyLinkEnabled != previous.nearbyLinkEnabled {
            if preferences.nearbyLinkEnabled {
                startNearbyLink()
                broadcastState()
            } else {
                NearbyLink.shared.stop()
            }
        }
    }
}

/// Stable SwiftUI scroll anchors for the top and bottom of a page.
enum PageAnchor {
    static func top(_ page: Int) -> String { "page-\(page)-top" }
    static func bottom(_ page: Int) -> String { "page-\(page)-bottom" }
}

enum Haptics {
    static func pageTurn() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}
