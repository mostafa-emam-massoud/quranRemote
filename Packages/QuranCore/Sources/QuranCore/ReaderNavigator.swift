import Foundation

/// Where to put the reading focus after a move. `first`/`last` are resolved to
/// a concrete verse once that page's text is available.
public enum VerseAnchor: Equatable, Sendable {
    case none
    case first
    case last
    case key(String)
}

public enum NavigationDirection: String, Equatable, Sendable {
    case forward
    case backward
    case jump
    case none
}

/// The result of applying one remote command.
public struct NavigationResult: Equatable, Sendable {
    public var page: Int
    public var focus: VerseAnchor
    public var didMove: Bool
    public var pageChanged: Bool
    public var direction: NavigationDirection

    public init(
        page: Int,
        focus: VerseAnchor,
        didMove: Bool,
        pageChanged: Bool,
        direction: NavigationDirection
    ) {
        self.page = page
        self.focus = focus
        self.didMove = didMove
        self.pageChanged = pageChanged
        self.direction = direction
    }
}

/// Pure navigation state: what page we are on and which verse is focused.
///
/// All movement — taps on the phone, the Digital Crown, the watch's buttons —
/// funnels through here, so every surface behaves identically and the rules are
/// unit-testable without a device.
public struct ReaderNavigator: Equatable, Sendable {

    public private(set) var page: Int
    public private(set) var focusedVerseKey: String?

    public init(page: Int = Mushaf.firstPage, focusedVerseKey: String? = nil) {
        self.page = Mushaf.clamp(page: page)
        self.focusedVerseKey = focusedVerseKey
    }

    /// Applies a command. `pageText` is the text of the *current* page when it
    /// is loaded; without it, verse-sized steps degrade to page-sized steps.
    @discardableResult
    public mutating func apply(_ command: RemoteCommand, pageText: PageText? = nil) -> NavigationResult {
        switch command {
        case .requestState:
            return stay()

        case .goToPage(let target):
            return jump(to: target, focus: .none)

        case .goToSurah(let number):
            guard let surah = Mushaf.surah(number: number) else { return stay() }
            return jump(to: surah.startPage, focus: .key("\(surah.number):1"))

        case .goToJuz(let number):
            guard let juz = Mushaf.juz(number: number) else { return stay() }
            return jump(to: juz.startPage, focus: .first)

        case .next(.page):
            return step(by: 1, focus: .first)

        case .previous(.page):
            return step(by: -1, focus: .first)

        case .next(.verse):
            guard let pageText, !pageText.isEmpty, pageText.pageNumber == page else {
                return step(by: 1, focus: .first)
            }
            let current = focusedVerseKey.flatMap { pageText.index(ofVerseWithKey: $0) } ?? -1
            let next = current + 1
            if next < pageText.verses.count {
                return settle(page: page, focus: .key(pageText.verses[next].key), direction: .forward)
            }
            return step(by: 1, focus: .first)

        case .previous(.verse):
            guard let pageText, !pageText.isEmpty, pageText.pageNumber == page else {
                return step(by: -1, focus: .last)
            }
            let current = focusedVerseKey.flatMap { pageText.index(ofVerseWithKey: $0) } ?? pageText.verses.count
            let previous = current - 1
            if previous >= 0 {
                return settle(page: page, focus: .key(pageText.verses[previous].key), direction: .backward)
            }
            return step(by: -1, focus: .last)
        }
    }

    /// Records a focus change that came from the UI (a tap, or a scroll that
    /// settled on a verse) rather than from a command.
    public mutating func setFocus(verseKey: String?) {
        focusedVerseKey = verseKey
    }

    /// Records a page change that came from the UI (a swipe, or a scroll).
    public mutating func setPage(_ page: Int, focus: String? = nil) {
        let clamped = Mushaf.clamp(page: page)
        if clamped != self.page {
            self.page = clamped
            focusedVerseKey = focus
        } else if let focus {
            focusedVerseKey = focus
        }
    }

    public var snapshot: ReaderStateSnapshot {
        ReaderStateSnapshot(
            page: page,
            surahNumber: currentSurahNumber,
            verseKey: focusedVerseKey
        )
    }

    private var currentSurahNumber: Int {
        if let key = focusedVerseKey,
           let surah = Int(key.split(separator: ":").first.map(String.init) ?? ""),
           Mushaf.surah(number: surah) != nil {
            return surah
        }
        return Mushaf.primarySurah(forPage: page).number
    }

    // MARK: - Movement primitives

    private mutating func step(by delta: Int, focus: VerseAnchor) -> NavigationResult {
        let target = Mushaf.clamp(page: page + delta)
        guard target != page else {
            // Already at the first or last page: report no movement so the
            // caller can play a "nope" haptic instead of a page-turn one.
            return NavigationResult(
                page: page,
                focus: focusedVerseKey.map { VerseAnchor.key($0) } ?? .none,
                didMove: false,
                pageChanged: false,
                direction: .none
            )
        }
        return settle(page: target, focus: focus, direction: delta > 0 ? .forward : .backward)
    }

    private mutating func jump(to target: Int, focus: VerseAnchor) -> NavigationResult {
        let clamped = Mushaf.clamp(page: target)
        let changed = clamped != page
        return settle(page: clamped, focus: focus, direction: changed ? .jump : .none, forceMove: changed)
    }

    private mutating func settle(
        page newPage: Int,
        focus: VerseAnchor,
        direction: NavigationDirection,
        forceMove: Bool? = nil
    ) -> NavigationResult {
        let pageChanged = newPage != page
        let focusChanged: Bool
        switch focus {
        case .key(let key):
            focusChanged = key != focusedVerseKey
            focusedVerseKey = key
        case .none:
            focusChanged = focusedVerseKey != nil
            focusedVerseKey = nil
        case .first, .last:
            focusChanged = focusedVerseKey != nil
            focusedVerseKey = nil
        }
        page = newPage
        return NavigationResult(
            page: newPage,
            focus: focus,
            didMove: forceMove ?? (pageChanged || focusChanged),
            pageChanged: pageChanged,
            direction: direction
        )
    }

    private func stay() -> NavigationResult {
        NavigationResult(
            page: page,
            focus: focusedVerseKey.map { VerseAnchor.key($0) } ?? .none,
            didMove: false,
            pageChanged: false,
            direction: .none
        )
    }
}
