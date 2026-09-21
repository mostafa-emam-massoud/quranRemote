import QuranCore
import SwiftUI

/// Jumping somewhere specific from the wrist: a surah, a juz', or a page.
struct JumpView: View {

    @EnvironmentObject private var remote: RemoteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    SurahListView { number in
                        remote.goToSurah(number)
                        dismiss()
                    }
                } label: {
                    Label("Surah", systemImage: "book")
                }

                NavigationLink {
                    JuzListView { number in
                        remote.goToJuz(number)
                        dismiss()
                    }
                } label: {
                    Label("Juz'", systemImage: "rectangle.split.3x1")
                }

                NavigationLink {
                    PagePickerView(startingAt: remote.page) { page in
                        remote.goToPage(page)
                        dismiss()
                    }
                } label: {
                    Label("Page", systemImage: "number")
                }
            }
            .navigationTitle("Go to")
        }
    }
}

private struct SurahListView: View {
    let select: (Int) -> Void

    var body: some View {
        List(MushafData.surahs) { surah in
            Button {
                select(surah.number)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(surah.transliteratedName)
                            .font(.system(size: 15))
                        Text("page \(surah.startPage)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(surah.arabicName)
                        .font(.system(size: 17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .navigationTitle("Surah")
    }
}

private struct JuzListView: View {
    let select: (Int) -> Void

    var body: some View {
        List(MushafData.juzs) { juz in
            Button {
                select(juz.number)
            } label: {
                HStack {
                    Text("Juz' \(juz.number)")
                    Spacer()
                    Text("p. \(juz.startPage)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Juz'")
    }
}

/// A crown-driven page picker: spin to the page, tap once to go.
private struct PagePickerView: View {
    let startingAt: Int
    let select: (Int) -> Void

    @State private var page: Int

    init(startingAt: Int, select: @escaping (Int) -> Void) {
        self.startingAt = startingAt
        self.select = select
        _page = State(initialValue: startingAt)
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Page", selection: $page) {
                ForEach(Array(Mushaf.pageRange), id: \.self) { number in
                    Text("\(number)").tag(number)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxHeight: 90)

            Text(Mushaf.primarySurah(forPage: page).transliteratedName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button("Go") {
                select(page)
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Page")
    }
}
