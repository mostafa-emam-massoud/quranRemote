import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum QuranTextError: Error, Equatable, LocalizedError {
    case invalidPage(Int)
    case badResponse(status: Int)
    case malformedResponse(String)
    case notCachedAndOffline(page: Int)
    case allProvidersFailed

    public var errorDescription: String? {
        switch self {
        case .invalidPage(let page):
            return "Page \(page) is outside the mushaf (1–\(Mushaf.pageCount))."
        case .badResponse(let status):
            return "The Qur'an text service replied with status \(status)."
        case .malformedResponse(let detail):
            return "Unexpected response from the Qur'an text service: \(detail)"
        case .notCachedAndOffline(let page):
            return "Page \(page) has not been downloaded yet and there is no connection."
        case .allProvidersFailed:
            return "Could not reach any Qur'an text service."
        }
    }
}

/// Minimal seam over the network so parsing and caching can be tested offline.
public protocol HTTPTransport: Sendable {
    func data(from url: URL) async throws -> (Data, Int)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        return (data, status)
    }
}

/// A source of mushaf page text.
public protocol PageTextProviding: Sendable {
    var name: String { get }
    func fetchPage(_ page: Int) async throws -> PageText
}

/// api.alquran.cloud — key-free, returns a whole page of Uthmani text.
public struct AlQuranCloudProvider: PageTextProviding {
    public let name = "alquran.cloud"
    private let transport: HTTPTransport
    private let edition: String

    public init(transport: HTTPTransport = URLSessionTransport(), edition: String = "quran-uthmani") {
        self.transport = transport
        self.edition = edition
    }

    public func fetchPage(_ page: Int) async throws -> PageText {
        guard Mushaf.isValid(page: page) else { throw QuranTextError.invalidPage(page) }
        guard let url = URL(string: "https://api.alquran.cloud/v1/page/\(page)/\(edition)") else {
            throw QuranTextError.malformedResponse("bad url")
        }
        let (data, status) = try await transport.data(from: url)
        guard (200...299).contains(status) else { throw QuranTextError.badResponse(status: status) }
        return try Self.parse(data, page: page)
    }

    struct Response: Decodable {
        struct Payload: Decodable {
            struct Ayah: Decodable {
                struct SurahRef: Decodable { let number: Int }
                let text: String
                let numberInSurah: Int
                let surah: SurahRef
            }
            let ayahs: [Ayah]
        }
        let data: Payload
    }

    public static func parse(_ data: Data, page: Int) throws -> PageText {
        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw QuranTextError.malformedResponse(String(describing: error))
        }
        let verses = decoded.data.ayahs.map { ayah in
            Verse(
                surahNumber: ayah.surah.number,
                verseNumber: ayah.numberInSurah,
                text: QuranText.strippingBasmalah(
                    from: ayah.text,
                    surahNumber: ayah.surah.number,
                    verseNumber: ayah.numberInSurah
                )
            )
        }
        guard !verses.isEmpty else { throw QuranTextError.malformedResponse("page \(page) had no verses") }
        return PageText(pageNumber: page, verses: verses)
    }
}

/// api.quran.com v4 — the source Quran.com itself uses.
public struct QuranComProvider: PageTextProviding {
    public let name = "quran.com"
    private let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func fetchPage(_ page: Int) async throws -> PageText {
        guard Mushaf.isValid(page: page) else { throw QuranTextError.invalidPage(page) }
        let string = "https://api.quran.com/api/v4/verses/by_page/\(page)?fields=text_uthmani&per_page=all"
        guard let url = URL(string: string) else {
            throw QuranTextError.malformedResponse("bad url")
        }
        let (data, status) = try await transport.data(from: url)
        guard (200...299).contains(status) else { throw QuranTextError.badResponse(status: status) }
        return try Self.parse(data, page: page)
    }

    struct Response: Decodable {
        struct VerseDTO: Decodable {
            let verse_key: String
            let text_uthmani: String?
            let text_imlaei: String?
        }
        let verses: [VerseDTO]
    }

    public static func parse(_ data: Data, page: Int) throws -> PageText {
        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw QuranTextError.malformedResponse(String(describing: error))
        }
        let verses: [Verse] = decoded.verses.compactMap { dto in
            let parts = dto.verse_key.split(separator: ":")
            guard parts.count == 2,
                  let surah = Int(parts[0]),
                  let ayah = Int(parts[1]),
                  let text = dto.text_uthmani ?? dto.text_imlaei
            else { return nil }
            return Verse(
                surahNumber: surah,
                verseNumber: ayah,
                text: QuranText.strippingBasmalah(from: text, surahNumber: surah, verseNumber: ayah)
            )
        }
        guard !verses.isEmpty else { throw QuranTextError.malformedResponse("page \(page) had no verses") }
        return PageText(pageNumber: page, verses: verses)
    }
}

/// Tries each provider in turn. Praying is a bad time to meet a 500, so the
/// reader always has a second source to fall back on.
public struct FallbackPageTextProvider: PageTextProviding {
    public let name = "fallback"
    private let providers: [PageTextProviding]

    public init(providers: [PageTextProviding]) {
        self.providers = providers
    }

    public static func standard(transport: HTTPTransport = URLSessionTransport()) -> FallbackPageTextProvider {
        FallbackPageTextProvider(providers: [
            AlQuranCloudProvider(transport: transport),
            QuranComProvider(transport: transport)
        ])
    }

    public func fetchPage(_ page: Int) async throws -> PageText {
        var lastError: Error = QuranTextError.allProvidersFailed
        for provider in providers {
            do {
                return try await provider.fetchPage(page)
            } catch {
                if error is CancellationError { throw error }
                lastError = error
            }
        }
        throw lastError
    }
}
