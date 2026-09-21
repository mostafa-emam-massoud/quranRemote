import Combine
import Foundation
import QuranCore
import QuranLink
import SwiftUI
import WatchKit

/// The watch side of the remote.
///
/// It keeps its own copy of the page so a tap feels instant, sends the command
/// to the phone, and then trusts whatever the phone reports back.
@MainActor
final class RemoteViewModel: ObservableObject {

    @Published private(set) var navigator: ReaderNavigator
    @Published private(set) var isPhoneReachable = false
    @Published private(set) var isPhoneAppInstalled = false
    /// Set when a command could not be delivered live, so the UI can say so.
    @Published private(set) var isWaitingForPhone = false
    /// Mirrors the extended runtime session, so views observe one object.
    @Published private(set) var isPrayerModeActive = false

    @Published var crownAction: CrownAction {
        didSet {
            guard crownAction != oldValue else { return }
            var preferences = storage.preferences
            preferences.crownAction = crownAction
            storage.preferences = preferences
        }
    }

    let prayerSession = PrayerSession()

    private let link: WatchLink
    private let storage: ReaderStorage
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    init(link: WatchLink = .shared, storage: ReaderStorage = ReaderStorage()) {
        self.link = link
        self.storage = storage
        self.crownAction = storage.preferences.crownAction
        self.navigator = ReaderNavigator(page: storage.lastPage)
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        link.states
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, let state else { return }
                self.applyFromPhone(state)
            }
            .store(in: &cancellables)

        link.reachabilityUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] reachable in
                self?.isPhoneReachable = reachable
                if reachable {
                    self?.isWaitingForPhone = false
                    self?.link.send(command: .requestState)
                }
            }
            .store(in: &cancellables)

        link.installationUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] installed in
                self?.isPhoneAppInstalled = installed
            }
            .store(in: &cancellables)

        prayerSession.activityUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.isPrayerModeActive = active
            }
            .store(in: &cancellables)

        link.activate()
        link.send(command: .requestState)
    }

    // MARK: - Where the reader is

    var page: Int { navigator.page }
    var surah: Surah { Mushaf.primarySurah(forPage: navigator.page) }
    var juz: Juz { Mushaf.juz(forPage: navigator.page) }
    var progress: Double { Mushaf.progress(forPage: navigator.page) }

    // MARK: - Commands

    func nextPage() { send(.next(.page)) }
    func previousPage() { send(.previous(.page)) }
    func nextVerse() { send(.next(.verse)) }
    func previousVerse() { send(.previous(.verse)) }
    func goToPage(_ page: Int) { send(.goToPage(page)) }
    func goToSurah(_ number: Int) { send(.goToSurah(number)) }
    func goToJuz(_ number: Int) { send(.goToJuz(number)) }

    /// Moves the crown's value onto a page, without echoing commands for pages
    /// the crown merely passed through.
    func crownScrubbed(to value: Double) {
        let target = Mushaf.clamp(page: Int(value.rounded()))
        guard target != navigator.page else { return }
        send(.goToPage(target))
    }

    func togglePrayerMode() {
        prayerSession.toggle()
        WKInterfaceDevice.current().play(prayerSession.isActive ? .start : .stop)
    }

    private func send(_ command: RemoteCommand) {
        // Move locally first: the wrist should not wait for Bluetooth. Verse
        // steps are the exception — only the phone knows where the verses on a
        // page fall, so the watch waits to be told rather than guessing and
        // showing a page number that then jumps back.
        let result: NavigationResult
        switch command {
        case .next(.verse), .previous(.verse):
            result = NavigationResult(
                page: navigator.page,
                focus: .none,
                didMove: true,
                pageChanged: false,
                direction: .none
            )
        default:
            result = navigator.apply(command)
        }
        link.send(command: command)
        isWaitingForPhone = !isPhoneReachable

        if result.didMove {
            WKInterfaceDevice.current().play(.click)
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func applyFromPhone(_ state: ReaderStateSnapshot) {
        isWaitingForPhone = false
        guard state.page != navigator.page || state.verseKey != navigator.focusedVerseKey else { return }
        navigator.setPage(state.page, focus: state.verseKey)
        storage.lastPage = state.page
    }
}
