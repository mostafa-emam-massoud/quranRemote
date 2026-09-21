import QuranCore
import QuranLink
import SwiftUI

@main
struct QuranRemoteApp: App {

    @StateObject private var reader = ReaderViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ReaderView()
                .environmentObject(reader)
                .task { reader.start() }
                .onChange(of: scenePhase) { _, phase in
                    reader.scenePhaseChanged(to: phase)
                }
        }
    }
}
