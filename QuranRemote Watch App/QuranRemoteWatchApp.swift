import QuranCore
import QuranLink
import SwiftUI

@main
struct QuranRemoteWatchApp: App {

    @StateObject private var remote = RemoteViewModel()

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environmentObject(remote)
                .task { remote.start() }
        }
    }
}
