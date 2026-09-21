import Foundation

/// A single verse as it appears on a mushaf page.
public struct Verse: Codable, Hashable, Identifiable, Sendable {
    public let surahNumber: Int
    public let verseNumber: Int
    public let text: String

    public init(surahNumber: Int, verseNumber: Int, text: String) {
        self.surahNumber = surahNumber
        self.verseNumber = verseNumber
        self.text = text
    }

    /// `"2:255"` — the same key both APIs use, and a stable SwiftUI scroll anchor.
    public var key: String { "\(surahNumber):\(verseNumber)" }
    public var id: String { key }

    public var startsSurah: Bool { verseNumber == 1 }

    public var surah: Surah? { Mushaf.surah(number: surahNumber) }

    /// The circled ayah number that closes the verse in a printed mushaf.
    public var endOfVerseMarker: String {
        "\u{06DD}" + ArabicNumerals.string(from: verseNumber)
    }
}

/// The text of one mushaf page.
public struct PageText: Codable, Hashable, Identifiable, Sendable {
    public let pageNumber: Int
    public let verses: [Verse]

    public init(pageNumber: Int, verses: [Verse]) {
        self.pageNumber = pageNumber
        self.verses = verses
    }

    public var id: Int { pageNumber }

    public var isEmpty: Bool { verses.isEmpty }

    /// Surah numbers appearing on the page, in reading order.
    public var surahNumbers: [Int] {
        var seen = Set<Int>()
        return verses.map(\.surahNumber).filter { seen.insert($0).inserted }
    }

    public var surahs: [Surah] {
        surahNumbers.compactMap { Mushaf.surah(number: $0) }
    }

    /// The surah to put in the header: the one the page opens with.
    public var leadingSurah: Surah? {
        verses.first.flatMap { Mushaf.surah(number: $0.surahNumber) }
    }

    public func verse(withKey key: String) -> Verse? {
        verses.first { $0.key == key }
    }

    public func index(ofVerseWithKey key: String) -> Int? {
        verses.firstIndex { $0.key == key }
    }

    /// Verses grouped into runs belonging to the same surah, so a page that
    /// ends one surah and starts the next can draw a header in between.
    public func surahRuns() -> [SurahRun] {
        var runs: [SurahRun] = []
        for verse in verses {
            if var last = runs.last, last.surahNumber == verse.surahNumber {
                last.verses.append(verse)
                runs[runs.count - 1] = last
            } else {
                runs.append(SurahRun(surahNumber: verse.surahNumber, verses: [verse]))
            }
        }
        return runs
    }

    public struct SurahRun: Identifiable, Hashable, Sendable {
        public let surahNumber: Int
        public var verses: [Verse]

        public var id: String { "\(surahNumber)-\(verses.first?.verseNumber ?? 0)" }
        public var surah: Surah? { Mushaf.surah(number: surahNumber) }
        /// A header is only drawn where the surah actually begins on this page.
        public var startsSurah: Bool { verses.first?.startsSurah ?? false }
    }
}

/// Eastern Arabic numerals, for ayah markers and the page number.
public enum ArabicNumerals {
    private static let digits: [Character] = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]

    public static func string(from value: Int) -> String {
        let magnitude = abs(value)
        let converted = String(magnitude).compactMap { character -> Character? in
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else { return nil }
            return digits[digit]
        }
        let result = String(converted)
        return value < 0 ? "-" + result : result
    }
}
