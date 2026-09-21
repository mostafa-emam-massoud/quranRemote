import QuranCore
import SwiftUI

/// One mushaf page: surah headers where a surah opens, then its verses.
///
/// Verses are separate blocks rather than one justified paragraph on purpose —
/// it gives every verse a tap target, a highlight, and a scroll anchor, which
/// is what keeps your place while you are standing in prayer.
struct PageContentView: View {

    let page: Int
    /// `true` in page-by-page mode, where a long page scrolls inside itself.
    /// `false` in continuous mode, where the whole mushaf is one scroll view.
    let scrollsInternally: Bool
    let onBackgroundTap: () -> Void

    @EnvironmentObject private var reader: ReaderViewModel

    private var palette: ReaderPalette { ReaderPalette.palette(for: reader.preferences.theme) }

    var body: some View {
        Group {
            if scrollsInternally {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        pageStack
                    }
                    .onChange(of: reader.scrollRequest) { _, request in
                        guard let request, request.page == page else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(request.anchorID, anchor: request.unitPoint)
                        }
                    }
                }
            } else {
                pageStack
            }
        }
        .frame(maxWidth: .infinity)
        // Only a self-scrolling page should stretch to fill the screen; inside
        // the continuous scroll a page is exactly as tall as its text.
        .frame(maxHeight: scrollsInternally ? CGFloat.infinity : nil)
        .background(palette.page)
        .onAppear { reader.ensureLoaded(page: page) }
    }

    private var pageStack: some View {
        VStack(spacing: 18) {
            // In continuous mode the whole page row carries the anchor instead,
            // so that a jump can reach a page that has not been built yet.
            if scrollsInternally {
                anchor(PageAnchor.top(page))
            }

            if let text = reader.text(for: page) {
                ForEach(text.surahRuns()) { run in
                    VStack(spacing: 14) {
                        if run.startsSurah, let surah = run.surah {
                            SurahHeaderView(surah: surah, palette: palette)
                        }
                        ForEach(run.verses) { verse in
                            VerseView(
                                verse: verse,
                                isFocused: reader.focusedVerseKey == verse.key,
                                palette: palette,
                                fontScale: reader.preferences.clampedFontScale,
                                highlightEnabled: reader.preferences.highlightFocusedVerse
                            )
                            .id(verse.key)
                            .onTapGesture { reader.focusVerse(verse) }
                        }
                    }
                }
            } else if let failure = reader.failure(for: page) {
                PageProblemView(page: page, message: failure, palette: palette) {
                    reader.retry(page: page)
                }
                .frame(minHeight: 320)
            } else {
                PageLoadingView(page: page, palette: palette)
                    .frame(minHeight: 320)
            }

            PageFooterView(page: page, palette: palette)
            if scrollsInternally {
                anchor(PageAnchor.bottom(page))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onBackgroundTap() }
    }

    private func anchor(_ id: String) -> some View {
        Color.clear
            .frame(height: 1)
            .id(id)
    }
}

private struct VerseView: View {
    let verse: Verse
    let isFocused: Bool
    let palette: ReaderPalette
    let fontScale: Double
    let highlightEnabled: Bool

    var body: some View {
        Text(verse.text + "  " + verse.endOfVerseMarker)
            .font(MushafFont.arabic(size: MushafFont.size(base: 26, scale: fontScale)))
            .foregroundStyle(palette.ink)
            .lineSpacing(MushafFont.size(base: 16, scale: fontScale))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(showsHighlight ? palette.highlight : Color.clear)
            )
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilityLabel)
    }

    private var showsHighlight: Bool { isFocused && highlightEnabled }

    private var accessibilityLabel: String {
        let surahName = verse.surah?.transliteratedName ?? ""
        return "\(surahName) verse \(verse.verseNumber)"
    }
}

private struct SurahHeaderView: View {
    let surah: Surah
    let palette: ReaderPalette

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ornament
                Text(surah.arabicName)
                    .font(MushafFont.arabic(size: 24))
                    .foregroundStyle(palette.accent)
                ornament
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(palette.accent.opacity(0.5), lineWidth: 1.5)
            )

            if surah.showsBasmalahHeader {
                Text(QuranText.basmalah)
                    .font(MushafFont.arabic(size: 20))
                    .foregroundStyle(palette.ink.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Surah \(surah.transliteratedName)")
    }

    private var ornament: some View {
        Image(systemName: "diamond")
            .font(.system(size: 8))
            .foregroundStyle(palette.accent.opacity(0.7))
    }
}

private struct PageFooterView: View {
    let page: Int
    let palette: ReaderPalette

    var body: some View {
        HStack {
            Text("Juz' \(Mushaf.juz(forPage: page).number)")
            Spacer()
            Text(ArabicNumerals.string(from: page))
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(Mushaf.primarySurah(forPage: page).transliteratedName)
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.secondaryInk)
        .padding(.top, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
        }
    }
}

private struct PageLoadingView: View {
    let page: Int
    let palette: ReaderPalette

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(palette.accent)
            Text("Loading page \(page)…")
                .font(.footnote)
                .foregroundStyle(palette.secondaryInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PageProblemView: View {
    let page: Int
    let message: String
    let palette: ReaderPalette
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(palette.accent)
            Text("Page \(page) is not available offline")
                .font(.headline)
                .foregroundStyle(palette.ink)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.secondaryInk)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
            Text("Tip: download the whole mushaf in Settings so this never happens mid-prayer.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.secondaryInk)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
