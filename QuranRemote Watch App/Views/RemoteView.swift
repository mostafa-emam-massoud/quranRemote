import QuranCore
import SwiftUI

/// The main watch screen: where the reader is, and two big targets to move it.
///
/// Sized for a wrist during prayer — the buttons are as large as the screen
/// allows, the Digital Crown works without looking, and every move gives a
/// haptic so you know it landed.
struct RemoteView: View {

    @EnvironmentObject private var remote: RemoteViewModel
    @State private var showsJump = false
    @State private var showsSettings = false
    @State private var crownPage: Double = 1
    @State private var verseCrown: Double = 0
    @State private var isSyncingCrown = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                header
                buttons
                footer
            }
            .padding(.horizontal, 4)
            .focusable(true)
            .modifier(
                CrownControl(
                    action: remote.crownAction,
                    pageValue: $crownPage,
                    verseValue: $verseCrown,
                    onPage: { page in
                        guard !isSyncingCrown else { return }
                        remote.crownScrubbed(to: page)
                    },
                    onVerseStep: { forward in
                        guard !isSyncingCrown else { return }
                        if forward {
                            remote.nextVerse()
                        } else {
                            remote.previousVerse()
                        }
                    }
                )
            )
            .navigationTitle("Page \(remote.page)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Watch settings")
                }
            }
            .sheet(isPresented: $showsJump) {
                JumpView()
                    .environmentObject(remote)
            }
            .sheet(isPresented: $showsSettings) {
                WatchSettingsView()
                    .environmentObject(remote)
            }
            .onAppear { syncCrown(to: remote.page) }
            .onChange(of: remote.page) { _, page in
                syncCrown(to: page)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 2) {
            Text(remote.surah.arabicName)
                .font(.system(size: 22))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(remote.surah.transliteratedName)
                Text("·")
                Text("Juz' \(remote.juz.number)")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button {
                remote.nextPage()
            } label: {
                Label("Next", systemImage: "chevron.down")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Next page")

            Button {
                remote.previousPage()
            } label: {
                Label("Back", systemImage: "chevron.up")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Previous page")
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                showsJump = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Jump to a surah, juz' or page")

            Button {
                remote.togglePrayerMode()
            } label: {
                Image(systemName: remote.isPrayerModeActive ? "hands.and.sparkles.fill" : "hands.and.sparkles")
            }
            .buttonStyle(.bordered)
            .tint(remote.isPrayerModeActive ? .green : nil)
            .accessibilityLabel(remote.isPrayerModeActive ? "Turn off prayer mode" : "Keep the remote on screen for prayer")

            ConnectionDot(isReachable: remote.isPhoneReachable, isWaiting: remote.isWaitingForPhone)
        }
        .font(.system(size: 14))
    }

    // MARK: - Crown

    /// Keeps the crown's value on the current page without that assignment
    /// bouncing straight back out as a new command.
    private func syncCrown(to page: Int) {
        isSyncingCrown = true
        crownPage = Double(page)
        Task { @MainActor in
            isSyncingCrown = false
        }
    }
}

/// One crown, three jobs. Kept in a modifier so each mode has its own binding.
private struct CrownControl: ViewModifier {

    let action: CrownAction
    @Binding var pageValue: Double
    @Binding var verseValue: Double
    let onPage: (Double) -> Void
    let onVerseStep: (Bool) -> Void

    func body(content: Content) -> some View {
        switch action {
        case .turnPages:
            content
                .digitalCrownRotation(
                    $pageValue,
                    from: Double(Mushaf.firstPage),
                    through: Double(Mushaf.lastPage),
                    by: 1,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: pageValue) { _, value in onPage(value) }
        case .scrubMushaf:
            content
                .digitalCrownRotation(
                    $pageValue,
                    from: Double(Mushaf.firstPage),
                    through: Double(Mushaf.lastPage),
                    by: 1,
                    sensitivity: .high,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: pageValue) { _, value in onPage(value) }
        case .stepVerses:
            content
                .digitalCrownRotation(
                    $verseValue,
                    from: -10_000,
                    through: 10_000,
                    by: 1,
                    sensitivity: .low,
                    isContinuous: true,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: verseValue) { oldValue, newValue in
                    guard newValue != oldValue else { return }
                    onVerseStep(newValue > oldValue)
                }
        }
    }
}

private struct ConnectionDot: View {
    let isReachable: Bool
    let isWaiting: Bool

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .accessibilityLabel(label)
    }

    private var symbol: String {
        if isReachable { return "iphone.radiowaves.left.and.right" }
        return isWaiting ? "clock.arrow.circlepath" : "iphone.slash"
    }

    private var color: Color {
        if isReachable { return .green }
        return isWaiting ? .orange : .secondary
    }

    private var label: String {
        if isReachable { return "iPhone connected" }
        return isWaiting ? "Waiting for the iPhone" : "iPhone not connected"
    }
}
