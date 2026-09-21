import QuranCore
import SwiftUI
import UIKit

/// Colours for one reading theme. Kept in code rather than in the asset
/// catalogue so the four themes stay side by side and easy to tune.
struct ReaderPalette {
    let background: Color
    let page: Color
    let ink: Color
    let secondaryInk: Color
    let accent: Color
    let highlight: Color
    let divider: Color
    let colorScheme: ColorScheme

    static func palette(for theme: ReaderTheme) -> ReaderPalette {
        switch theme {
        case .parchment:
            return ReaderPalette(
                background: Color(hex: 0xE8DCC3),
                page: Color(hex: 0xFBF5E6),
                ink: Color(hex: 0x2B2519),
                secondaryInk: Color(hex: 0x6F6243),
                accent: Color(hex: 0x8A6A2F),
                highlight: Color(hex: 0xC9A227).opacity(0.22),
                divider: Color(hex: 0xC9B78F),
                colorScheme: .light
            )
        case .light:
            return ReaderPalette(
                background: Color(hex: 0xF2F3F5),
                page: .white,
                ink: Color(hex: 0x11161C),
                secondaryInk: Color(hex: 0x5C6672),
                accent: Color(hex: 0x0E7C66),
                highlight: Color(hex: 0x0E7C66).opacity(0.14),
                divider: Color(hex: 0xD8DDE3),
                colorScheme: .light
            )
        case .dark:
            return ReaderPalette(
                background: Color(hex: 0x101317),
                page: Color(hex: 0x181D22),
                ink: Color(hex: 0xE7E3D8),
                secondaryInk: Color(hex: 0x9AA3AC),
                accent: Color(hex: 0x5FBFA3),
                highlight: Color(hex: 0x5FBFA3).opacity(0.18),
                divider: Color(hex: 0x2A3138),
                colorScheme: .dark
            )
        case .night:
            // Deliberately dim and warm: readable in a dark room without
            // wrecking your night vision or lighting up the row behind you.
            return ReaderPalette(
                background: .black,
                page: Color(hex: 0x05070A),
                ink: Color(hex: 0xC59A54),
                secondaryInk: Color(hex: 0x7A6134),
                accent: Color(hex: 0xB5843C),
                highlight: Color(hex: 0xB5843C).opacity(0.16),
                divider: Color(hex: 0x1A1509),
                colorScheme: .dark
            )
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Picks the best Arabic face that is actually installed.
///
/// Drop a mushaf font (for example KFGQPC HAFS Uthmanic Script) into `Fonts/`
/// and list it under `UIAppFonts` in `Config/QuranRemote-Info.plist`, and the
/// reader will use it. Without one, it falls back to the system serif face,
/// which renders Uthmani text correctly — just less beautifully.
enum MushafFont {

    static let preferredFamilies = [
        "KFGQPC HAFS Uthmanic Script",
        "KFGQPC Uthmanic Script HAFS",
        "Al Qalam Quran Majeed",
        "me_quran",
        "Scheherazade New",
        "Amiri Quran",
        "Amiri"
    ]

    /// Resolved once: font lookups are not free and this never changes at runtime.
    static let installedFamily: String? = preferredFamilies.first { family in
        UIFont(name: family, size: 20) != nil
    }

    static func arabic(size: CGFloat) -> Font {
        if let installedFamily {
            return .custom(installedFamily, size: size)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    /// Base size before the reader's own scale is applied.
    static func size(base: CGFloat, scale: Double) -> CGFloat {
        base * CGFloat(scale)
    }
}
