import Foundation

/// Page math for the standard 604-page Madani mushaf.
public enum Mushaf {

    public static let firstPage = 1
    public static let lastPage = 604
    public static let pageCount = 604
    public static let pageRange = firstPage...lastPage

    public static func isValid(page: Int) -> Bool {
        pageRange.contains(page)
    }

    /// Pins a page number into `1...604` so navigation can never run off the end.
    public static func clamp(page: Int) -> Int {
        min(max(page, firstPage), lastPage)
    }

    public static func surah(number: Int) -> Surah? {
        guard (1...MushafData.surahs.count).contains(number) else { return nil }
        return MushafData.surahs[number - 1]
    }

    public static func juz(number: Int) -> Juz? {
        guard (1...MushafData.juzs.count).contains(number) else { return nil }
        return MushafData.juzs[number - 1]
    }

    /// The page a surah begins on.
    public static func startPage(ofSurah number: Int) -> Int {
        surah(number: number)?.startPage ?? firstPage
    }

    /// The page a juz' begins on.
    public static func startPage(ofJuz number: Int) -> Int {
        juz(number: number)?.startPage ?? firstPage
    }

    /// The juz' a page belongs to.
    public static func juz(forPage page: Int) -> Juz {
        let page = clamp(page: page)
        var result = MushafData.juzs[0]
        for juz in MushafData.juzs where juz.startPage <= page {
            result = juz
        }
        return result
    }

    /// Surahs that *begin* on this page (usually none, sometimes several).
    public static func surahsStarting(onPage page: Int) -> [Surah] {
        MushafData.surahs.filter { $0.startPage == page }
    }

    /// The surah a page is mostly in: the last one to have started on or
    /// before it. Used for the header and for the watch's offline display.
    public static func primarySurah(forPage page: Int) -> Surah {
        let page = clamp(page: page)
        var result = MushafData.surahs[0]
        for surah in MushafData.surahs where surah.startPage <= page {
            result = surah
        }
        return result
    }

    /// Every surah that (at least partly) appears on a page.
    ///
    /// Derived from surah start pages alone, so it is exact for surah
    /// beginnings and an estimate for the surah a page continues. Once a page's
    /// text has been loaded, `PageText.surahs` is authoritative — prefer it.
    public static func estimatedSurahs(onPage page: Int) -> [Surah] {
        let page = clamp(page: page)
        var result = [primarySurah(forPage: page)]
        result.append(contentsOf: surahsStarting(onPage: page))
        var seen = Set<Int>()
        return result
            .filter { seen.insert($0.number).inserted }
            .sorted { $0.number < $1.number }
    }

    /// Rough page for a verse, interpolated between surah start pages.
    ///
    /// Good enough to land the reader in the right neighbourhood when offline;
    /// the exact page comes from the loaded page text.
    public static func estimatedPage(ofSurah surahNumber: Int, verse: Int) -> Int {
        guard let surah = surah(number: surahNumber) else { return firstPage }
        guard surah.verseCount > 1, verse > 1 else { return surah.startPage }
        let nextStart = self.surah(number: surahNumber + 1)?.startPage ?? lastPage
        let span = max(nextStart - surah.startPage, 0)
        guard span > 0 else { return surah.startPage }
        let progress = Double(min(verse, surah.verseCount) - 1) / Double(surah.verseCount)
        return clamp(page: surah.startPage + Int((Double(span) * progress).rounded(.down)))
    }

    /// How far through the mushaf a page is, as `0...1`.
    public static func progress(forPage page: Int) -> Double {
        Double(clamp(page: page) - firstPage) / Double(pageCount - 1)
    }
}
