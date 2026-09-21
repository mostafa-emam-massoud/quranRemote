import Foundation

/// How far a single "next"/"previous" moves the reader.
public enum NavigationUnit: String, Codable, Sendable, CaseIterable {
    /// A whole mushaf page.
    case page
    /// One verse — used to creep down a long page without losing your place.
    case verse
}

/// Something the watch (or a linked device) asks the reader to do.
public enum RemoteCommand: Codable, Equatable, Sendable {
    case next(NavigationUnit)
    case previous(NavigationUnit)
    case goToPage(Int)
    case goToSurah(Int)
    case goToJuz(Int)
    /// "Tell me where you are" — sent when the remote wakes up.
    case requestState

    public var shortDescription: String {
        switch self {
        case .next(let unit): return "next \(unit.rawValue)"
        case .previous(let unit): return "previous \(unit.rawValue)"
        case .goToPage(let page): return "page \(page)"
        case .goToSurah(let surah): return "surah \(surah)"
        case .goToJuz(let juz): return "juz \(juz)"
        case .requestState: return "request state"
        }
    }
}

/// What the reader is currently showing. Sent back so the watch can display
/// the page, surah and juz' without needing the Qur'an text itself.
public struct ReaderStateSnapshot: Codable, Equatable, Sendable {
    public var page: Int
    public var surahNumber: Int
    public var verseKey: String?
    public var displayMode: DisplayMode
    public var updatedAt: Date

    /// `surahNumber` defaults to whichever surah the page is in, so callers
    /// that only know the page do not have to work it out.
    public init(
        page: Int,
        surahNumber: Int? = nil,
        verseKey: String? = nil,
        displayMode: DisplayMode = .paged,
        updatedAt: Date = Date()
    ) {
        let clamped = Mushaf.clamp(page: page)
        self.page = clamped
        self.surahNumber = surahNumber ?? Mushaf.primarySurah(forPage: clamped).number
        self.verseKey = verseKey
        self.displayMode = displayMode
        self.updatedAt = updatedAt
    }

    public var surah: Surah { Mushaf.surah(number: surahNumber) ?? MushafData.surahs[0] }
    public var juz: Juz { Mushaf.juz(forPage: page) }
    public var progress: Double { Mushaf.progress(forPage: page) }
}

/// How the reader lays pages out.
public enum DisplayMode: String, Codable, Sendable, CaseIterable {
    /// One page at a time, swiped right-to-left like a printed mushaf.
    case paged
    /// One long vertical scroll through the whole mushaf.
    case continuous

    public var displayName: String {
        switch self {
        case .paged: return "Page by page"
        case .continuous: return "Continuous scroll"
        }
    }
}

/// Everything that travels between the watch and the phone.
public enum RemoteMessage: Codable, Equatable, Sendable {
    case command(RemoteCommand)
    case state(ReaderStateSnapshot)
}

public extension RemoteMessage {

    /// Key under which the encoded message is carried in a WatchConnectivity
    /// dictionary. `Data` is a valid property-list value, so a single key keeps
    /// the payload small and versionable.
    static let payloadKey = "quranRemote.message.v1"

    func payload() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return [Self.payloadKey: try encoder.encode(self)]
    }

    init?(payload: [String: Any]) {
        guard let data = payload[Self.payloadKey] as? Data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let message = try? decoder.decode(RemoteMessage.self, from: data) else { return nil }
        self = message
    }
}

public extension RemoteMessage {

    /// Raw JSON, for transports that carry bytes rather than dictionaries
    /// (Multipeer Connectivity between an iPhone and an iPad).
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(self)
    }

    init?(data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let message = try? decoder.decode(RemoteMessage.self, from: data) else { return nil }
        self = message
    }
}
