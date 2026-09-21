#if canImport(MultipeerConnectivity) && os(iOS)

import Combine
import Foundation
import MultipeerConnectivity
import QuranCore

/// Links iOS devices on the same Wi-Fi network.
///
/// Apple Watch only pairs with an iPhone, never with an iPad. So when the
/// mushaf is on the iPad, the iPhone acts as a bridge: the watch talks to the
/// iPhone over WatchConnectivity, and the iPhone relays to the iPad over this
/// link. Every device both advertises and browses, so it does not matter which
/// one is opened first.
public final class NearbyLink: NSObject, ObservableObject {

    public static let shared = NearbyLink()

    /// Bonjour service type. Must also be declared in the app's Info.plist
    /// under `NSBonjourServices`.
    public static let serviceType = "quran-remote"

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var connectedDeviceNames: [String] = []

    private let commandSubject = PassthroughSubject<RemoteCommand, Never>()
    private let stateSubject = PassthroughSubject<ReaderStateSnapshot, Never>()

    public var commands: AnyPublisher<RemoteCommand, Never> { commandSubject.eraseToAnyPublisher() }
    public var states: AnyPublisher<ReaderStateSnapshot, Never> { stateSubject.eraseToAnyPublisher() }

    public var isConnected: Bool { !connectedDeviceNames.isEmpty }

    /// The names of the devices currently linked to this one.
    public var connectedDeviceUpdates: AnyPublisher<[String], Never> {
        $connectedDeviceNames.eraseToAnyPublisher()
    }

    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private override init() {
        super.init()
    }

    /// Starts advertising and browsing. `displayName` shows up in the other
    /// device's connection list.
    public func start(displayName: String) {
        guard !isRunning else { return }

        // A stable, unique-per-install suffix keeps two devices with the same
        // name apart and gives the invite rule below a deterministic winner.
        let name = Self.uniqueName(from: displayName)
        let peerID = MCPeerID(displayName: name)
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["app": "quranRemote"],
            serviceType: Self.serviceType
        )
        advertiser.delegate = self

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self

        self.peerID = peerID
        self.session = session
        self.advertiser = advertiser
        self.browser = browser

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        publishOnMain { self.isRunning = true }
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        peerID = nil
        publishOnMain {
            self.isRunning = false
            self.connectedDeviceNames = []
        }
    }

    public func send(command: RemoteCommand) {
        send(.command(command))
    }

    public func publish(state: ReaderStateSnapshot) {
        send(.state(state))
    }

    public func send(_ message: RemoteMessage) {
        guard let session, !session.connectedPeers.isEmpty, let data = try? message.encoded() else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: - Plumbing

    private static func uniqueName(from displayName: String) -> String {
        let key = "quranRemote.peerSuffix"
        let defaults = UserDefaults.standard
        let suffix: String
        if let stored = defaults.string(forKey: key) {
            suffix = stored
        } else {
            suffix = String(UUID().uuidString.prefix(4))
            defaults.set(suffix, forKey: key)
        }
        // MCPeerID display names are limited to 63 bytes.
        let trimmed = String(displayName.prefix(40))
        return "\(trimmed)#\(suffix)"
    }

    /// Strips the disambiguating suffix for display.
    public static func friendlyName(_ peerName: String) -> String {
        peerName.split(separator: "#").first.map(String.init) ?? peerName
    }

    private func refreshPeers() {
        let names = (session?.connectedPeers ?? []).map { Self.friendlyName($0.displayName) }
        publishOnMain { self.connectedDeviceNames = names }
    }

    private func handle(data: Data) {
        guard let message = RemoteMessage(data: data) else { return }
        publishOnMain {
            switch message {
            case .command(let command): self.commandSubject.send(command)
            case .state(let state): self.stateSubject.send(state)
            }
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

extension NearbyLink: MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        refreshPeers()
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        handle(data: data)
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyLink: MCNearbyServiceAdvertiserDelegate {

    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Only ever one session, and only peers advertising this app's service
        // can get here, so accept.
        invitationHandler(true, session)
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        publishOnMain { self.isRunning = false }
    }
}

extension NearbyLink: MCNearbyServiceBrowserDelegate {

    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard let session = self.session, let me = self.peerID else { return }
        guard info?["app"] == "quranRemote" else { return }
        guard !session.connectedPeers.contains(peerID) else { return }
        // Both sides discover each other; let only one side invite so the two
        // devices do not tear each other's session down.
        guard me.displayName < peerID.displayName else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        refreshPeers()
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        publishOnMain { self.isRunning = false }
    }
}

#endif
