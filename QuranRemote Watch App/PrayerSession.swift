import Combine
import Foundation
import WatchKit

/// Keeps the remote on screen through a prayer.
///
/// Without this, watchOS dims and then leaves the app after a few seconds, and
/// you would have to wake the watch and find the app again between rak'ahs.
/// An extended runtime session (declared as `mindfulness` in the watch app's
/// Info.plist) keeps Quran Remote frontmost for up to an hour.
public final class PrayerSession: NSObject, ObservableObject {

    @Published public private(set) var isActive = false
    @Published public private(set) var statusMessage: String?

    private var session: WKExtendedRuntimeSession?

    /// Whether the session is currently holding the app on screen.
    public var activityUpdates: AnyPublisher<Bool, Never> {
        $isActive.eraseToAnyPublisher()
    }

    public func toggle() {
        isActive ? stop() : start()
    }

    public func start() {
        guard session == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        self.session = session
        publishOnMain {
            self.isActive = true
            self.statusMessage = nil
        }
    }

    public func stop() {
        session?.invalidate()
        session = nil
        publishOnMain {
            self.isActive = false
            self.statusMessage = nil
        }
    }

    private func publishOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

extension PrayerSession: WKExtendedRuntimeSessionDelegate {

    public func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        publishOnMain { self.isActive = true }
    }

    public func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        publishOnMain { self.statusMessage = "Prayer mode is about to end" }
    }

    public func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        session = nil
        publishOnMain {
            self.isActive = false
            self.statusMessage = error?.localizedDescription
        }
    }
}
