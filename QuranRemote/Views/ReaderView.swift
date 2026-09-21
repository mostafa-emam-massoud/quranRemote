import QuranCore
import SwiftUI

/// The reader itself: the mushaf fills the screen, and the controls fade away
/// until you tap. Everything here is also reachable from the watch.
struct ReaderView: View {

    @EnvironmentObject private var reader: ReaderViewModel
    @State private var isChromeVisible = true
    @State private var sheet: ReaderSheet?
    @State private var chromeHideTask: Task<Void, Never>?

    private var palette: ReaderPalette { ReaderPalette.palette(for: reader.preferences.theme) }

    var body: some View {
        ZStack {
            palette.background
                .ignoresSafeArea()

            content
                .ignoresSafeArea(.container, edges: .bottom)

            VStack(spacing: 0) {
                if isChromeVisible {
                    ReaderHeaderView(openSheet: open(_:))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
                if isChromeVisible {
                    ReaderControlsView(openSheet: open(_:))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isChromeVisible)
        .preferredColorScheme(palette.colorScheme)
        .statusBarHidden(!isChromeVisible)
        .persistentSystemOverlays(isChromeVisible ? .automatic : .hidden)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .index:
                MushafIndexView()
                    .environmentObject(reader)
            case .settings:
                SettingsView()
                    .environmentObject(reader)
            }
        }
        .onAppear(perform: scheduleChromeHide)
    }

    @ViewBuilder
    private var content: some View {
        switch reader.preferences.displayMode {
        case .paged:
            PagedReaderView(onBackgroundTap: toggleChrome)
        case .continuous:
            ContinuousReaderView(onBackgroundTap: toggleChrome)
        }
    }

    private func toggleChrome() {
        isChromeVisible.toggle()
        if isChromeVisible {
            scheduleChromeHide()
        } else {
            chromeHideTask?.cancel()
        }
    }

    /// Controls get out of the way on their own, so nothing is covering the
    /// text by the time you start praying.
    private func scheduleChromeHide() {
        chromeHideTask?.cancel()
        chromeHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            isChromeVisible = false
        }
    }

    private func open(_ sheet: ReaderSheet) {
        chromeHideTask?.cancel()
        self.sheet = sheet
    }
}

enum ReaderSheet: String, Identifiable {
    case index
    case settings

    var id: String { rawValue }
}

// MARK: - Header

private struct ReaderHeaderView: View {

    let openSheet: (ReaderSheet) -> Void

    @EnvironmentObject private var reader: ReaderViewModel

    private var palette: ReaderPalette { ReaderPalette.palette(for: reader.preferences.theme) }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reader.currentSurah.arabicName)
                        .font(MushafFont.arabic(size: 20))
                        .foregroundStyle(palette.ink)
                    Text("\(reader.currentSurah.transliteratedName) · Juz' \(reader.currentJuz.number)")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryInk)
                }

                Spacer()

                ConnectionBadge()

                Button {
                    reader.toggleBookmark()
                } label: {
                    Image(systemName: reader.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(reader.isCurrentPageBookmarked ? "Remove bookmark" : "Bookmark this page")

                Button {
                    openSheet(.settings)
                } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel("Reading settings")
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            .font(.system(size: 18, weight: .medium))

            if let action = reader.lastRemoteAction {
                Label("Watch: \(action)", systemImage: "applewatch.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Bottom controls

private struct ReaderControlsView: View {

    let openSheet: (ReaderSheet) -> Void

    @EnvironmentObject private var reader: ReaderViewModel
    @State private var draftPage: Double = Double(Mushaf.firstPage)
    @State private var isScrubbing = false

    private var palette: ReaderPalette { ReaderPalette.palette(for: reader.preferences.theme) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button {
                    reader.perform(.previous(.page))
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous page")

                // The page only actually turns when the drag ends, so scrubbing
                // does not spray hundreds of messages at the watch.
                Slider(
                    value: $draftPage,
                    in: Double(Mushaf.firstPage)...Double(Mushaf.lastPage),
                    step: 1,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            reader.perform(.goToPage(Int(draftPage.rounded())))
                        }
                    }
                )
                .tint(palette.accent)

                Button {
                    reader.perform(.next(.page))
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next page")
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(palette.accent)

            HStack {
                Button {
                    openSheet(.index)
                } label: {
                    Label("Surahs, juz' and bookmarks", systemImage: "list.bullet")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 18, weight: .medium))
                }
                .accessibilityLabel("Open index")

                Spacer()

                Text("Page \(isScrubbing ? Int(draftPage.rounded()) : reader.page) of \(Mushaf.lastPage)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(isScrubbing ? palette.accent : palette.secondaryInk)

                Spacer()

                Button {
                    reader.perform(.goToPage(Mushaf.firstPage))
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16, weight: .medium))
                }
                .accessibilityLabel("Back to the first page")
            }
            .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
        .onAppear { draftPage = Double(reader.page) }
        .onChange(of: reader.page) { _, page in
            guard !isScrubbing else { return }
            draftPage = Double(page)
        }
    }
}

// MARK: - Connection badge

struct ConnectionBadge: View {

    @EnvironmentObject private var reader: ReaderViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: reader.watchIsReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
            if !reader.nearbyDeviceNames.isEmpty {
                Image(systemName: "ipad.and.iphone")
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(reader.watchIsReachable ? Color.green : Color.secondary)
        .accessibilityLabel(reader.watchIsReachable ? "Watch connected" : "Watch not connected")
    }
}
