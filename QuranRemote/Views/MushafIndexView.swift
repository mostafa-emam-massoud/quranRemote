import QuranCore
import SwiftUI

/// Jump anywhere: by surah, by juz', by page number, or back to a bookmark.
struct MushafIndexView: View {

    @EnvironmentObject private var reader: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .surahs
    @State private var search = ""

    enum Tab: String, CaseIterable, Identifiable {
        case surahs
        case juz
        case bookmarks

        var id: String { rawValue }
        var title: String {
            switch self {
            case .surahs: return "Surahs"
            case .juz: return "Juz'"
            case .bookmarks: return "Bookmarks"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                List {
                    switch tab {
                    case .surahs: surahSection
                    case .juz: juzSection
                    case .bookmarks: bookmarkSection
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Go to")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Surah or page number")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var surahSection: some View {
        if let page = typedPageNumber {
            Button {
                go(.goToPage(page))
            } label: {
                Label("Go to page \(page)", systemImage: "arrow.right.doc.on.clipboard")
            }
            .buttonStyle(.plain)
        }
        ForEach(filteredSurahs) { surah in
            Button {
                go(.goToSurah(surah.number))
            } label: {
                HStack {
                    Text("\(surah.number)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(surah.transliteratedName)
                            .font(.body)
                        Text("\(surah.verseCount) verses · \(surah.revelationPlace.displayName) · page \(surah.startPage)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(surah.arabicName)
                        .font(MushafFont.arabic(size: 20))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var juzSection: some View {
        ForEach(MushafData.juzs) { juz in
            Button {
                go(.goToJuz(juz.number))
            } label: {
                HStack {
                    Text("Juz' \(juz.number)")
                    Spacer()
                    Text("page \(juz.startPage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var bookmarkSection: some View {
        if reader.bookmarks.isEmpty {
            ContentUnavailableView(
                "No bookmarks yet",
                systemImage: "bookmark",
                description: Text("Tap the bookmark button in the reader to save where you are.")
            )
        } else {
            ForEach(reader.bookmarks) { bookmark in
                Button {
                    go(.goToPage(bookmark.page))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Page \(bookmark.page) · \(bookmark.surah.transliteratedName)")
                        if !bookmark.note.isEmpty {
                            Text(bookmark.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        reader.removeBookmark(bookmark)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// A bare number in the search field is most likely a page number.
    private var typedPageNumber: Int? {
        guard let number = Int(search.trimmingCharacters(in: .whitespacesAndNewlines)),
              Mushaf.isValid(page: number)
        else { return nil }
        return number
    }

    private var filteredSurahs: [Surah] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return MushafData.surahs }
        if let number = Int(query) {
            // A number could be either a surah or a page; show both readings.
            return MushafData.surahs.filter { $0.number == number || $0.startPage == number }
        }
        return MushafData.surahs.filter {
            $0.transliteratedName.localizedCaseInsensitiveContains(query)
                || $0.arabicName.contains(query)
        }
    }

    private func go(_ command: RemoteCommand) {
        reader.perform(command)
        dismiss()
    }
}
