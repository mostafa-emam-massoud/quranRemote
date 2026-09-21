import QuranCore
import SwiftUI

/// Page-by-page reading, swiped right-to-left like a printed mushaf.
/// On a landscape iPad it shows two pages at once, as an open mushaf does.
struct PagedReaderView: View {

    let onBackgroundTap: () -> Void

    @EnvironmentObject private var reader: ReaderViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let spread = usesSpread(size: geometry.size)
            TabView(selection: selection(spread: spread)) {
                ForEach(slots(spread: spread), id: \.self) { slot in
                    slotContent(slot, spread: spread)
                        .tag(slot)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            // The mushaf turns right to left, and so does its text.
            .environment(\.layoutDirection, .rightToLeft)
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    // MARK: - Spread handling

    private func usesSpread(size: CGSize) -> Bool {
        reader.preferences.twoPageSpreadOnPad
            && horizontalSizeClass == .regular
            && size.width > size.height
    }

    /// In spread mode a "slot" is the odd, right-hand page of a pair.
    private func slots(spread: Bool) -> [Int] {
        spread
            ? Array(stride(from: Mushaf.firstPage, through: Mushaf.lastPage - 1, by: 2))
            : Array(Mushaf.pageRange)
    }

    private func slot(for page: Int, spread: Bool) -> Int {
        guard spread else { return page }
        return page.isMultiple(of: 2) ? max(page - 1, Mushaf.firstPage) : page
    }

    private func selection(spread: Bool) -> Binding<Int> {
        Binding(
            get: { slot(for: reader.page, spread: spread) },
            set: { newSlot in
                guard newSlot != slot(for: reader.page, spread: spread) else { return }
                reader.userDidReach(page: newSlot)
            }
        )
    }

    @ViewBuilder
    private func slotContent(_ slot: Int, spread: Bool) -> some View {
        if spread {
            HStack(spacing: 0) {
                PageContentView(page: slot, scrollsInternally: true, onBackgroundTap: onBackgroundTap)
                Rectangle()
                    .fill(ReaderPalette.palette(for: reader.preferences.theme).divider)
                    .frame(width: 1)
                if slot + 1 <= Mushaf.lastPage {
                    PageContentView(page: slot + 1, scrollsInternally: true, onBackgroundTap: onBackgroundTap)
                }
            }
        } else {
            PageContentView(page: slot, scrollsInternally: true, onBackgroundTap: onBackgroundTap)
        }
    }
}
