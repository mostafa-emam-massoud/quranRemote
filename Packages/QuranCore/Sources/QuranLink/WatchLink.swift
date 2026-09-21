#if canImport(WatchConnectivity)

import Combine
import Foundation
import QuranCore
import WatchConnectivity

/// The link between the watch and the iPhone.
///
/// Both ends run the same object: the watch sends commands and receives state,
/// the phone receives commands and publishes state. Messages go out live when
/// the counterpart is reachable and fall back to queued delivery when it is
/// not, so a command is never silently dropped mid-prayer.
public final class WatchLink: NSObject, ObservableObject {

    public static let shared = WatchLink()

    @Published public private(set) var isSupported: Bool = false
    @Published public private(set) var isActivated: Bool = false
    /// The counterpart app is running and can be messaged right now.
    @Published public private(set) var isReachable: Bool = false
    /// The counterpart app is installed at all.
    @Published public private(set) var isCounterpartInstalled: Bool = false
    @Published public private(set) var lastErrorDescription: String?

    private let commandSubject = PassthroughSubject<RemoteCommand, Never>()
    private let stateSubject = CurrentValueSubject<ReaderStateSnapshot?, Never>(nil)

    /// Commands arriving from the other device.
    public var commands: AnyPublisher<RemoteCommand, Never> {
        commandSubject.eraseToAnyPublisher()
    }

    /// The other device's latest reader state.
    public var states: AnyPublisher<ReaderStateSnapshot?, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var latestState: ReaderStateSnapshot? { stateSubject.value }

    /// Whether the counterpart app can be messaged right now.
    public var reachabilityUpdates: AnyPublisher<Bool, Never> {
        $isReachable.eraseToAnyPublisher()
    }

    /// Whether the counterpart app is installed at all.
    public var installationUpdates: AnyPublisher<Bool, Never> {
        $isCounterpartInstalled.eraseToAnyPublisher()
    }

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
    }

    /// Call once, early in the app's lifetime.
    public func activate() {
        guard WCSession.isSupported() else {
            publishOnMain { self.isSupported = false }
            return
        }
        let session = WCSession.default
        publishOnMain { self.isSupported = true }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        } else {
            refreshReachability(session)
        }
    }

    // MARK: - Sending

    public func send(command: RemoteCommand) {
        send(.command(command))
    }

    /// Publishes reader state. The latest state also goes into the application
    /// context, so a watch opened later sees the right page immediately.
    public func publish(state: ReaderStateSnapshot) {
        send(.state(state), alsoUpdateContext: true)
    }

    public func send(_ message: RemoteMessage, alsoUpdateContext: Bool = false) {
        guard let session, session.activationState == .activated else { return }
        guard let payload = try? message.payload() else { return }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                // Live delivery failed (the counterpart went to sleep between
                // the reachability check and the send): fall back to a queued
                // transfer rather than losing the command.
                self?.note(error: error)
                self?.queue(payload)
            }
        } else {
            queue(payload)
        }

        if alsoUpdateContext {
            try? session.updateApplicationContext(payload)
        }
    }

    private func queue(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        session.transferUserInfo(payload)
    }

    // MARK: - Receiving

    private func handle(payload: [String: Any]) {
        guard let message = RemoteMessage(payload: payload) else { return }
        publishOnMain {
            switch message {
            case .command(let command):
                self.commandSubject.send(command)
            case .state(let state):
                // Ignore state that is older than what we already have; queued
                // transfers can arrive out of order.
                if let current = self.stateSubject.value, current.updatedAt > state.updatedAt { return }
                self.stateSubject.send(state)
            }
        }
    }

    private func refreshReachability(_ session: WCSession) {
        let reachable = session.isReachable
        let activated = session.activationState == .activated
        #if os(iOS)
        let installed = session.isWatchAppInstalled
        #else
        let installed = session.isCompanionAppInstalled
        #endif
        publishOnMain {
            self.isReachable = reachable
            self.isActivated = activated
            self.isCounterpartInstalled = installed
        }
    }

    private func note(error: Error?) {
        guard let error else { return }
        publishOnMain { self.lastErrorDescription = error.localizedDescription }
    }

    private func publishOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

extension WatchLink: WCSessionDelegate {

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        note(error: error)
        refreshReachability(session)
        // Anything the counterpart left in the context while we were closed.
        let context = session.receivedApplicationContext
        if !context.isEmpty { handle(payload: context) }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        refreshReachability(session)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(payload: message)
    }

    public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handle(payload: message)
        replyHandler([:])
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(payload: userInfo)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(payload: applicationContext)
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        refreshReachability(session)
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate so the link survives the user switching watches.
        WCSession.default.activate()
    }

    public func sessionWatchStateDidChange(_ session: WCSession) {
        refreshReachability(session)
    }
    #endif
}

#endif
