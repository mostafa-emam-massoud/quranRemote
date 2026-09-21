import Foundation

/// Page background / ink, chosen for readability in a dim room.
public enum ReaderTheme: String, Codable, CaseIterable, Sendable, Identifiable {
    case parchment
    case light
    case dark
    case night

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .parchment: return "Parchment"
        case .light: return "Light"
        case .dark: return "Dark"
        case .night: return "Night"
        }
    }

    public var isDark: Bool {
        self == .dark || self == .night
    }
}

/// What the watch's Digital Crown does.
public enum CrownAction: String, Codable, CaseIterable, Sendable, Identifiable {
    /// One detent of the crown turns one page.
    case turnPages
    /// The crown scrubs across the whole mushaf, for finding a page fast.
    case scrubMushaf
    /// The crown steps verse by verse down the current page.
    case stepVerses

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .turnPages: return "Turn pages"
        case .scrubMushaf: return "Scrub mushaf"
        case .stepVerses: return "Step verses"
        }
    }
}

public struct ReaderPreferences: Codable, Equatable, Sendable {
    /// Multiplier on the Arabic text size, 0.7…2.5.
    public var fontScale: Double
    public var theme: ReaderTheme
    public var displayMode: DisplayMode
    /// Praying means not touching the phone for minutes at a time.
    public var keepScreenAwake: Bool
    /// Tint the verse the remote is pointing at.
    public var highlightFocusedVerse: Bool
    public var hapticOnPageTurn: Bool
    /// Two pages side by side on a landscape iPad, like an open mushaf.
    public var twoPageSpreadOnPad: Bool
    /// Let this device talk to other iPhones/iPads over the local network,
    /// which is how a watch drives an iPad. Off until asked for.
    public var nearbyLinkEnabled: Bool
    public var crownAction: CrownAction

    public init(
        fontScale: Double = 1.0,
        theme: ReaderTheme = .parchment,
        displayMode: DisplayMode = .paged,
        keepScreenAwake: Bool = true,
        highlightFocusedVerse: Bool = true,
        hapticOnPageTurn: Bool = true,
        twoPageSpreadOnPad: Bool = true,
        nearbyLinkEnabled: Bool = false,
        crownAction: CrownAction = .turnPages
    ) {
        self.fontScale = fontScale
        self.theme = theme
        self.displayMode = displayMode
        self.keepScreenAwake = keepScreenAwake
        self.highlightFocusedVerse = highlightFocusedVerse
        self.hapticOnPageTurn = hapticOnPageTurn
        self.twoPageSpreadOnPad = twoPageSpreadOnPad
        self.nearbyLinkEnabled = nearbyLinkEnabled
        self.crownAction = crownAction
    }

    public static let fontScaleRange: ClosedRange<Double> = 0.7...2.5

    public var clampedFontScale: Double {
        min(max(fontScale, Self.fontScaleRange.lowerBound), Self.fontScaleRange.upperBound)
    }

    /// Older builds may not have written every key; decoding stays lenient so
    /// a new preference never wipes someone's settings.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReaderPreferences()
        fontScale = try container.decodeIfPresent(Double.self, forKey: .fontScale) ?? defaults.fontScale
        theme = try container.decodeIfPresent(ReaderTheme.self, forKey: .theme) ?? defaults.theme
        displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? defaults.displayMode
        keepScreenAwake = try container.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? defaults.keepScreenAwake
        highlightFocusedVerse = try container.decodeIfPresent(Bool.self, forKey: .highlightFocusedVerse) ?? defaults.highlightFocusedVerse
        hapticOnPageTurn = try container.decodeIfPresent(Bool.self, forKey: .hapticOnPageTurn) ?? defaults.hapticOnPageTurn
        twoPageSpreadOnPad = try container.decodeIfPresent(Bool.self, forKey: .twoPageSpreadOnPad) ?? defaults.twoPageSpreadOnPad
        nearbyLinkEnabled = try container.decodeIfPresent(Bool.self, forKey: .nearbyLinkEnabled) ?? defaults.nearbyLinkEnabled
        crownAction = try container.decodeIfPresent(CrownAction.self, forKey: .crownAction) ?? defaults.crownAction
    }
}

/// A place worth coming back to.
public struct Bookmark: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var page: Int
    public var verseKey: String?
    public var note: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        page: Int,
        verseKey: String? = nil,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.page = Mushaf.clamp(page: page)
        self.verseKey = verseKey
        self.note = note
        self.createdAt = createdAt
    }

    public var surah: Surah { Mushaf.primarySurah(forPage: page) }
}

/// Everything persisted between launches, on either device.
public struct ReaderStorage {

    private enum Key {
        static let preferences = "quranRemote.preferences"
        static let lastPage = "quranRemote.lastPage"
        static let lastVerseKey = "quranRemote.lastVerseKey"
        static let bookmarks = "quranRemote.bookmarks"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var preferences: ReaderPreferences {
        get {
            guard let data = defaults.data(forKey: Key.preferences),
                  let decoded = try? JSONDecoder().decode(ReaderPreferences.self, from: data)
            else { return ReaderPreferences() }
            return decoded
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.preferences)
        }
    }

    public var lastPage: Int {
        get {
            let stored = defaults.integer(forKey: Key.lastPage)
            return stored == 0 ? Mushaf.firstPage : Mushaf.clamp(page: stored)
        }
        nonmutating set { defaults.set(Mushaf.clamp(page: newValue), forKey: Key.lastPage) }
    }

    public var lastVerseKey: String? {
        get { defaults.string(forKey: Key.lastVerseKey) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastVerseKey) }
    }

    public var bookmarks: [Bookmark] {
        get {
            guard let data = defaults.data(forKey: Key.bookmarks),
                  let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
            else { return [] }
            return decoded
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.bookmarks)
        }
    }

    public func addBookmark(_ bookmark: Bookmark) {
        var all = bookmarks
        all.removeAll { $0.page == bookmark.page && $0.verseKey == bookmark.verseKey }
        all.append(bookmark)
        bookmarks = all.sorted { $0.page < $1.page }
    }

    public func removeBookmark(id: UUID) {
        bookmarks = bookmarks.filter { $0.id != id }
    }
}
