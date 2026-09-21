import QuranCore
import SwiftUI

/// One long scroll through the whole mushaf, for people who would rather
/// nudge the text along than turn pages.
struct ContinuousReaderView: View {

    let onBackgroundTap: () -> Void

    @EnvironmentObject private var reader: ReaderViewModel

    /// While a programmatic scroll is settling, pages stream past and each one
    /// reports that it appeared. Ignore those so a jump to juz' 30 does not get
    /// dragged back by the pages it flew over.
    @State private var ignoreAppearancesUntil: Date = .distantPast

    private var palette: ReaderPalette { ReaderPalette.palette(for: reader.preferences.theme) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(Mushaf.pageRange), id: \.self) { page in
                        PageContentView(page: page, scrollsInternally: false, onBackgroundTap: onBackgroundTap)
                            .frame(minHeight: reader.text(for: page) == nil ? 420 : 0)
                            .id(PageAnchor.top(page))
                            .onAppear {
                                guard Date() >= ignoreAppearancesUntil else { return }
                                reader.userDidReach(page: page)
                            }
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .background(palette.page)
            .onChange(of: reader.scrollRequest) { _, request in
                guard let request else { return }
                scroll(to: request, using: proxy)
            }
            .onAppear {
                ignoreAppearancesUntil = Date().addingTimeInterval(1.0)
                proxy.scrollTo(PageAnchor.top(reader.page), anchor: .top)
            }
        }
    }

    /// Always land on the page first: verse anchors live inside the page and
    /// only exist once the lazy stack has built it.
    private func scroll(to request: ReaderViewModel.ScrollRequest, using proxy: ScrollViewProxy) {
        ignoreAppearancesUntil = Date().addingTimeInterval(0.9)
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(PageAnchor.top(request.page), anchor: .top)
        }
        guard request.anchorID != PageAnchor.top(request.page) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(request.anchorID, anchor: request.unitPoint)
            }
        }
    }
}
