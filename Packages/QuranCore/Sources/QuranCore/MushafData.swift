import Foundation

/// Where a surah was revealed.
public enum RevelationPlace: String, Codable, Sendable, CaseIterable {
    case meccan
    case medinan

    public var displayName: String {
        switch self {
        case .meccan: return "Meccan"
        case .medinan: return "Medinan"
        }
    }
}

/// A chapter of the Qur'an, with the page it starts on in the standard
/// 604-page Madani mushaf.
public struct Surah: Codable, Hashable, Identifiable, Sendable {
    public let number: Int
    public let arabicName: String
    public let transliteratedName: String
    public let verseCount: Int
    public let startPage: Int
    public let revelationPlace: RevelationPlace

    public var id: Int { number }

    public init(
        number: Int,
        arabicName: String,
        transliteratedName: String,
        verseCount: Int,
        startPage: Int,
        revelationPlace: RevelationPlace
    ) {
        self.number = number
        self.arabicName = arabicName
        self.transliteratedName = transliteratedName
        self.verseCount = verseCount
        self.startPage = startPage
        self.revelationPlace = revelationPlace
    }

    /// `بِسْمِ ٱللَّهِ ...` is shown above every surah except Al-Fatihah (where it
    /// is the first verse) and At-Tawbah (where it is not recited at all).
    public var showsBasmalahHeader: Bool {
        number != 1 && number != 9
    }
}

/// A thirtieth of the Qur'an.
public struct Juz: Codable, Hashable, Identifiable, Sendable {
    public let number: Int
    public let startPage: Int

    public var id: Int { number }

    public init(number: Int, startPage: Int) {
        self.number = number
        self.startPage = startPage
    }
}

/// Static metadata for the standard 604-page Madani mushaf.
///
/// The tables below are generated data, not guesses at runtime: they let the
/// watch show "which surah / juz am I on" with no network and no phone.
public enum MushafData {

    /// All 114 surahs, in revelation-order-independent mushaf order.
    public static let surahs: [Surah] = [
        Surah(number: 1, arabicName: "الفاتحة", transliteratedName: "Al-Fatihah", verseCount: 7, startPage: 1, revelationPlace: .meccan),
        Surah(number: 2, arabicName: "البقرة", transliteratedName: "Al-Baqarah", verseCount: 286, startPage: 2, revelationPlace: .medinan),
        Surah(number: 3, arabicName: "آل عمران", transliteratedName: "Ali 'Imran", verseCount: 200, startPage: 50, revelationPlace: .medinan),
        Surah(number: 4, arabicName: "النساء", transliteratedName: "An-Nisa", verseCount: 176, startPage: 77, revelationPlace: .medinan),
        Surah(number: 5, arabicName: "المائدة", transliteratedName: "Al-Ma'idah", verseCount: 120, startPage: 106, revelationPlace: .medinan),
        Surah(number: 6, arabicName: "الأنعام", transliteratedName: "Al-An'am", verseCount: 165, startPage: 128, revelationPlace: .meccan),
        Surah(number: 7, arabicName: "الأعراف", transliteratedName: "Al-A'raf", verseCount: 206, startPage: 151, revelationPlace: .meccan),
        Surah(number: 8, arabicName: "الأنفال", transliteratedName: "Al-Anfal", verseCount: 75, startPage: 177, revelationPlace: .medinan),
        Surah(number: 9, arabicName: "التوبة", transliteratedName: "At-Tawbah", verseCount: 129, startPage: 187, revelationPlace: .medinan),
        Surah(number: 10, arabicName: "يونس", transliteratedName: "Yunus", verseCount: 109, startPage: 208, revelationPlace: .meccan),
        Surah(number: 11, arabicName: "هود", transliteratedName: "Hud", verseCount: 123, startPage: 221, revelationPlace: .meccan),
        Surah(number: 12, arabicName: "يوسف", transliteratedName: "Yusuf", verseCount: 111, startPage: 235, revelationPlace: .meccan),
        Surah(number: 13, arabicName: "الرعد", transliteratedName: "Ar-Ra'd", verseCount: 43, startPage: 249, revelationPlace: .medinan),
        Surah(number: 14, arabicName: "إبراهيم", transliteratedName: "Ibrahim", verseCount: 52, startPage: 255, revelationPlace: .meccan),
        Surah(number: 15, arabicName: "الحجر", transliteratedName: "Al-Hijr", verseCount: 99, startPage: 262, revelationPlace: .meccan),
        Surah(number: 16, arabicName: "النحل", transliteratedName: "An-Nahl", verseCount: 128, startPage: 267, revelationPlace: .meccan),
        Surah(number: 17, arabicName: "الإسراء", transliteratedName: "Al-Isra", verseCount: 111, startPage: 282, revelationPlace: .meccan),
        Surah(number: 18, arabicName: "الكهف", transliteratedName: "Al-Kahf", verseCount: 110, startPage: 293, revelationPlace: .meccan),
        Surah(number: 19, arabicName: "مريم", transliteratedName: "Maryam", verseCount: 98, startPage: 305, revelationPlace: .meccan),
        Surah(number: 20, arabicName: "طه", transliteratedName: "Taha", verseCount: 135, startPage: 312, revelationPlace: .meccan),
        Surah(number: 21, arabicName: "الأنبياء", transliteratedName: "Al-Anbya", verseCount: 112, startPage: 322, revelationPlace: .meccan),
        Surah(number: 22, arabicName: "الحج", transliteratedName: "Al-Hajj", verseCount: 78, startPage: 332, revelationPlace: .medinan),
        Surah(number: 23, arabicName: "المؤمنون", transliteratedName: "Al-Mu'minun", verseCount: 118, startPage: 342, revelationPlace: .meccan),
        Surah(number: 24, arabicName: "النور", transliteratedName: "An-Nur", verseCount: 64, startPage: 350, revelationPlace: .medinan),
        Surah(number: 25, arabicName: "الفرقان", transliteratedName: "Al-Furqan", verseCount: 77, startPage: 359, revelationPlace: .meccan),
        Surah(number: 26, arabicName: "الشعراء", transliteratedName: "Ash-Shu'ara", verseCount: 227, startPage: 367, revelationPlace: .meccan),
        Surah(number: 27, arabicName: "النمل", transliteratedName: "An-Naml", verseCount: 93, startPage: 377, revelationPlace: .meccan),
        Surah(number: 28, arabicName: "القصص", transliteratedName: "Al-Qasas", verseCount: 88, startPage: 385, revelationPlace: .meccan),
        Surah(number: 29, arabicName: "العنكبوت", transliteratedName: "Al-'Ankabut", verseCount: 69, startPage: 396, revelationPlace: .meccan),
        Surah(number: 30, arabicName: "الروم", transliteratedName: "Ar-Rum", verseCount: 60, startPage: 404, revelationPlace: .meccan),
        Surah(number: 31, arabicName: "لقمان", transliteratedName: "Luqman", verseCount: 34, startPage: 411, revelationPlace: .meccan),
        Surah(number: 32, arabicName: "السجدة", transliteratedName: "As-Sajdah", verseCount: 30, startPage: 415, revelationPlace: .meccan),
        Surah(number: 33, arabicName: "الأحزاب", transliteratedName: "Al-Ahzab", verseCount: 73, startPage: 418, revelationPlace: .medinan),
        Surah(number: 34, arabicName: "سبأ", transliteratedName: "Saba", verseCount: 54, startPage: 428, revelationPlace: .meccan),
        Surah(number: 35, arabicName: "فاطر", transliteratedName: "Fatir", verseCount: 45, startPage: 434, revelationPlace: .meccan),
        Surah(number: 36, arabicName: "يس", transliteratedName: "Ya-Sin", verseCount: 83, startPage: 440, revelationPlace: .meccan),
        Surah(number: 37, arabicName: "الصافات", transliteratedName: "As-Saffat", verseCount: 182, startPage: 446, revelationPlace: .meccan),
        Surah(number: 38, arabicName: "ص", transliteratedName: "Sad", verseCount: 88, startPage: 453, revelationPlace: .meccan),
        Surah(number: 39, arabicName: "الزمر", transliteratedName: "Az-Zumar", verseCount: 75, startPage: 458, revelationPlace: .meccan),
        Surah(number: 40, arabicName: "غافر", transliteratedName: "Ghafir", verseCount: 85, startPage: 467, revelationPlace: .meccan),
        Surah(number: 41, arabicName: "فصلت", transliteratedName: "Fussilat", verseCount: 54, startPage: 477, revelationPlace: .meccan),
        Surah(number: 42, arabicName: "الشورى", transliteratedName: "Ash-Shura", verseCount: 53, startPage: 483, revelationPlace: .meccan),
        Surah(number: 43, arabicName: "الزخرف", transliteratedName: "Az-Zukhruf", verseCount: 89, startPage: 489, revelationPlace: .meccan),
        Surah(number: 44, arabicName: "الدخان", transliteratedName: "Ad-Dukhan", verseCount: 59, startPage: 496, revelationPlace: .meccan),
        Surah(number: 45, arabicName: "الجاثية", transliteratedName: "Al-Jathiyah", verseCount: 37, startPage: 499, revelationPlace: .meccan),
        Surah(number: 46, arabicName: "الأحقاف", transliteratedName: "Al-Ahqaf", verseCount: 35, startPage: 502, revelationPlace: .meccan),
        Surah(number: 47, arabicName: "محمد", transliteratedName: "Muhammad", verseCount: 38, startPage: 507, revelationPlace: .medinan),
        Surah(number: 48, arabicName: "الفتح", transliteratedName: "Al-Fath", verseCount: 29, startPage: 511, revelationPlace: .medinan),
        Surah(number: 49, arabicName: "الحجرات", transliteratedName: "Al-Hujurat", verseCount: 18, startPage: 515, revelationPlace: .medinan),
        Surah(number: 50, arabicName: "ق", transliteratedName: "Qaf", verseCount: 45, startPage: 518, revelationPlace: .meccan),
        Surah(number: 51, arabicName: "الذاريات", transliteratedName: "Adh-Dhariyat", verseCount: 60, startPage: 520, revelationPlace: .meccan),
        Surah(number: 52, arabicName: "الطور", transliteratedName: "At-Tur", verseCount: 49, startPage: 523, revelationPlace: .meccan),
        Surah(number: 53, arabicName: "النجم", transliteratedName: "An-Najm", verseCount: 62, startPage: 526, revelationPlace: .meccan),
        Surah(number: 54, arabicName: "القمر", transliteratedName: "Al-Qamar", verseCount: 55, startPage: 528, revelationPlace: .meccan),
        Surah(number: 55, arabicName: "الرحمن", transliteratedName: "Ar-Rahman", verseCount: 78, startPage: 531, revelationPlace: .medinan),
        Surah(number: 56, arabicName: "الواقعة", transliteratedName: "Al-Waqi'ah", verseCount: 96, startPage: 534, revelationPlace: .meccan),
        Surah(number: 57, arabicName: "الحديد", transliteratedName: "Al-Hadid", verseCount: 29, startPage: 537, revelationPlace: .medinan),
        Surah(number: 58, arabicName: "المجادلة", transliteratedName: "Al-Mujadila", verseCount: 22, startPage: 542, revelationPlace: .medinan),
        Surah(number: 59, arabicName: "الحشر", transliteratedName: "Al-Hashr", verseCount: 24, startPage: 545, revelationPlace: .medinan),
        Surah(number: 60, arabicName: "الممتحنة", transliteratedName: "Al-Mumtahanah", verseCount: 13, startPage: 549, revelationPlace: .medinan),
        Surah(number: 61, arabicName: "الصف", transliteratedName: "As-Saff", verseCount: 14, startPage: 551, revelationPlace: .medinan),
        Surah(number: 62, arabicName: "الجمعة", transliteratedName: "Al-Jumu'ah", verseCount: 11, startPage: 553, revelationPlace: .medinan),
        Surah(number: 63, arabicName: "المنافقون", transliteratedName: "Al-Munafiqun", verseCount: 11, startPage: 554, revelationPlace: .medinan),
        Surah(number: 64, arabicName: "التغابن", transliteratedName: "At-Taghabun", verseCount: 18, startPage: 556, revelationPlace: .medinan),
        Surah(number: 65, arabicName: "الطلاق", transliteratedName: "At-Talaq", verseCount: 12, startPage: 558, revelationPlace: .medinan),
        Surah(number: 66, arabicName: "التحريم", transliteratedName: "At-Tahrim", verseCount: 12, startPage: 560, revelationPlace: .medinan),
        Surah(number: 67, arabicName: "الملك", transliteratedName: "Al-Mulk", verseCount: 30, startPage: 562, revelationPlace: .meccan),
        Surah(number: 68, arabicName: "القلم", transliteratedName: "Al-Qalam", verseCount: 52, startPage: 564, revelationPlace: .meccan),
        Surah(number: 69, arabicName: "الحاقة", transliteratedName: "Al-Haqqah", verseCount: 52, startPage: 566, revelationPlace: .meccan),
        Surah(number: 70, arabicName: "المعارج", transliteratedName: "Al-Ma'arij", verseCount: 44, startPage: 568, revelationPlace: .meccan),
        Surah(number: 71, arabicName: "نوح", transliteratedName: "Nuh", verseCount: 28, startPage: 570, revelationPlace: .meccan),
        Surah(number: 72, arabicName: "الجن", transliteratedName: "Al-Jinn", verseCount: 28, startPage: 572, revelationPlace: .meccan),
        Surah(number: 73, arabicName: "المزمل", transliteratedName: "Al-Muzzammil", verseCount: 20, startPage: 574, revelationPlace: .meccan),
        Surah(number: 74, arabicName: "المدثر", transliteratedName: "Al-Muddaththir", verseCount: 56, startPage: 575, revelationPlace: .meccan),
        Surah(number: 75, arabicName: "القيامة", transliteratedName: "Al-Qiyamah", verseCount: 40, startPage: 577, revelationPlace: .meccan),
        Surah(number: 76, arabicName: "الإنسان", transliteratedName: "Al-Insan", verseCount: 31, startPage: 578, revelationPlace: .medinan),
        Surah(number: 77, arabicName: "المرسلات", transliteratedName: "Al-Mursalat", verseCount: 50, startPage: 580, revelationPlace: .meccan),
        Surah(number: 78, arabicName: "النبأ", transliteratedName: "An-Naba", verseCount: 40, startPage: 582, revelationPlace: .meccan),
        Surah(number: 79, arabicName: "النازعات", transliteratedName: "An-Nazi'at", verseCount: 46, startPage: 583, revelationPlace: .meccan),
        Surah(number: 80, arabicName: "عبس", transliteratedName: "'Abasa", verseCount: 42, startPage: 585, revelationPlace: .meccan),
        Surah(number: 81, arabicName: "التكوير", transliteratedName: "At-Takwir", verseCount: 29, startPage: 586, revelationPlace: .meccan),
        Surah(number: 82, arabicName: "الانفطار", transliteratedName: "Al-Infitar", verseCount: 19, startPage: 587, revelationPlace: .meccan),
        Surah(number: 83, arabicName: "المطففين", transliteratedName: "Al-Mutaffifin", verseCount: 36, startPage: 587, revelationPlace: .meccan),
        Surah(number: 84, arabicName: "الانشقاق", transliteratedName: "Al-Inshiqaq", verseCount: 25, startPage: 589, revelationPlace: .meccan),
        Surah(number: 85, arabicName: "البروج", transliteratedName: "Al-Buruj", verseCount: 22, startPage: 590, revelationPlace: .meccan),
        Surah(number: 86, arabicName: "الطارق", transliteratedName: "At-Tariq", verseCount: 17, startPage: 591, revelationPlace: .meccan),
        Surah(number: 87, arabicName: "الأعلى", transliteratedName: "Al-A'la", verseCount: 19, startPage: 591, revelationPlace: .meccan),
        Surah(number: 88, arabicName: "الغاشية", transliteratedName: "Al-Ghashiyah", verseCount: 26, startPage: 592, revelationPlace: .meccan),
        Surah(number: 89, arabicName: "الفجر", transliteratedName: "Al-Fajr", verseCount: 30, startPage: 593, revelationPlace: .meccan),
        Surah(number: 90, arabicName: "البلد", transliteratedName: "Al-Balad", verseCount: 20, startPage: 594, revelationPlace: .meccan),
        Surah(number: 91, arabicName: "الشمس", transliteratedName: "Ash-Shams", verseCount: 15, startPage: 595, revelationPlace: .meccan),
        Surah(number: 92, arabicName: "الليل", transliteratedName: "Al-Layl", verseCount: 21, startPage: 595, revelationPlace: .meccan),
        Surah(number: 93, arabicName: "الضحى", transliteratedName: "Ad-Duha", verseCount: 11, startPage: 596, revelationPlace: .meccan),
        Surah(number: 94, arabicName: "الشرح", transliteratedName: "Ash-Sharh", verseCount: 8, startPage: 596, revelationPlace: .meccan),
        Surah(number: 95, arabicName: "التين", transliteratedName: "At-Tin", verseCount: 8, startPage: 597, revelationPlace: .meccan),
        Surah(number: 96, arabicName: "العلق", transliteratedName: "Al-'Alaq", verseCount: 19, startPage: 597, revelationPlace: .meccan),
        Surah(number: 97, arabicName: "القدر", transliteratedName: "Al-Qadr", verseCount: 5, startPage: 598, revelationPlace: .meccan),
        Surah(number: 98, arabicName: "البينة", transliteratedName: "Al-Bayyinah", verseCount: 8, startPage: 598, revelationPlace: .medinan),
        Surah(number: 99, arabicName: "الزلزلة", transliteratedName: "Az-Zalzalah", verseCount: 8, startPage: 599, revelationPlace: .medinan),
        Surah(number: 100, arabicName: "العاديات", transliteratedName: "Al-'Adiyat", verseCount: 11, startPage: 599, revelationPlace: .meccan),
        Surah(number: 101, arabicName: "القارعة", transliteratedName: "Al-Qari'ah", verseCount: 11, startPage: 600, revelationPlace: .meccan),
        Surah(number: 102, arabicName: "التكاثر", transliteratedName: "At-Takathur", verseCount: 8, startPage: 600, revelationPlace: .meccan),
        Surah(number: 103, arabicName: "العصر", transliteratedName: "Al-'Asr", verseCount: 3, startPage: 601, revelationPlace: .meccan),
        Surah(number: 104, arabicName: "الهمزة", transliteratedName: "Al-Humazah", verseCount: 9, startPage: 601, revelationPlace: .meccan),
        Surah(number: 105, arabicName: "الفيل", transliteratedName: "Al-Fil", verseCount: 5, startPage: 601, revelationPlace: .meccan),
        Surah(number: 106, arabicName: "قريش", transliteratedName: "Quraysh", verseCount: 4, startPage: 602, revelationPlace: .meccan),
        Surah(number: 107, arabicName: "الماعون", transliteratedName: "Al-Ma'un", verseCount: 7, startPage: 602, revelationPlace: .meccan),
        Surah(number: 108, arabicName: "الكوثر", transliteratedName: "Al-Kawthar", verseCount: 3, startPage: 602, revelationPlace: .meccan),
        Surah(number: 109, arabicName: "الكافرون", transliteratedName: "Al-Kafirun", verseCount: 6, startPage: 603, revelationPlace: .meccan),
        Surah(number: 110, arabicName: "النصر", transliteratedName: "An-Nasr", verseCount: 3, startPage: 603, revelationPlace: .medinan),
        Surah(number: 111, arabicName: "المسد", transliteratedName: "Al-Masad", verseCount: 5, startPage: 603, revelationPlace: .meccan),
        Surah(number: 112, arabicName: "الإخلاص", transliteratedName: "Al-Ikhlas", verseCount: 4, startPage: 604, revelationPlace: .meccan),
        Surah(number: 113, arabicName: "الفلق", transliteratedName: "Al-Falaq", verseCount: 5, startPage: 604, revelationPlace: .meccan),
        Surah(number: 114, arabicName: "الناس", transliteratedName: "An-Nas", verseCount: 6, startPage: 604, revelationPlace: .meccan),
    ]

    /// The 30 juz', by the page each one starts on.
    public static let juzs: [Juz] = [
        Juz(number: 1, startPage: 1),
        Juz(number: 2, startPage: 22),
        Juz(number: 3, startPage: 42),
        Juz(number: 4, startPage: 62),
        Juz(number: 5, startPage: 82),
        Juz(number: 6, startPage: 102),
        Juz(number: 7, startPage: 121),
        Juz(number: 8, startPage: 141),
        Juz(number: 9, startPage: 162),
        Juz(number: 10, startPage: 182),
        Juz(number: 11, startPage: 201),
        Juz(number: 12, startPage: 222),
        Juz(number: 13, startPage: 242),
        Juz(number: 14, startPage: 262),
        Juz(number: 15, startPage: 282),
        Juz(number: 16, startPage: 302),
        Juz(number: 17, startPage: 322),
        Juz(number: 18, startPage: 342),
        Juz(number: 19, startPage: 362),
        Juz(number: 20, startPage: 382),
        Juz(number: 21, startPage: 402),
        Juz(number: 22, startPage: 422),
        Juz(number: 23, startPage: 442),
        Juz(number: 24, startPage: 462),
        Juz(number: 25, startPage: 482),
        Juz(number: 26, startPage: 502),
        Juz(number: 27, startPage: 522),
        Juz(number: 28, startPage: 542),
        Juz(number: 29, startPage: 562),
        Juz(number: 30, startPage: 582),
    ]
}
