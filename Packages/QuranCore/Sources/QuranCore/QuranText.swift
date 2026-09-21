import Foundation

/// Small text utilities for Qur'anic Arabic.
public enum QuranText {

    /// The basmalah in Uthmani script.
    public static let basmalah = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"

    /// Letters only, with tashkeel, tatweel and alef variants normalised away.
    /// Used to compare text that differs only in vowelling between editions.
    public static func normalizedLetters(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            // Alef with hamza / madda / wasla all fold to bare alef.
            case 0x0622, 0x0623, 0x0625, 0x0671, 0x0672, 0x0673:
                result.unicodeScalars.append(Unicode.Scalar(0x0627)!)
            // Alef maqsura folds to ya.
            case 0x0649:
                result.unicodeScalars.append(Unicode.Scalar(0x064A)!)
            // Ta marbuta folds to ha.
            case 0x0629:
                result.unicodeScalars.append(Unicode.Scalar(0x0647)!)
            case 0x0621...0x064A:
                result.unicodeScalars.append(scalar)
            default:
                // Tashkeel, tatweel, Qur'anic annotation marks, spaces,
                // punctuation: all dropped.
                continue
            }
        }
        return result
    }

    /// Some editions prepend the basmalah to the first verse of every surah
    /// (except Al-Fatihah and At-Tawbah). The reader draws it as a header
    /// instead, so strip it from the verse body when it is there.
    public static func strippingBasmalah(from text: String, surahNumber: Int, verseNumber: Int) -> String {
        guard verseNumber == 1, surahNumber != 1, surahNumber != 9 else { return text }

        let needle = normalizedLetters(basmalah)
        guard !needle.isEmpty, normalizedLetters(text).hasPrefix(needle) else { return text }

        // Walk the original string until as many significant letters have been
        // consumed as the basmalah contains, then cut there. This keeps the
        // original vowelling of whatever follows intact.
        var consumed = 0
        var cutIndex = text.startIndex
        var index = text.startIndex
        while index < text.endIndex {
            consumed += normalizedLetters(String(text[index])).count
            index = text.index(after: index)
            if consumed >= needle.count {
                cutIndex = index
                break
            }
        }
        guard consumed >= needle.count else { return text }

        // Carry on past any diacritics hanging off the last letter of the
        // basmalah, so the verse does not start with an orphaned kasra.
        while cutIndex < text.endIndex, normalizedLetters(String(text[cutIndex])).isEmpty,
              !text[cutIndex].isWhitespace {
            cutIndex = text.index(after: cutIndex)
        }

        let remainder = text[cutIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        return remainder.isEmpty ? text : remainder
    }
}
