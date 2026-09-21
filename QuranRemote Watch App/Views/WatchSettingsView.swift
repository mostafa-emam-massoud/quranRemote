import QuranCore
import SwiftUI

struct WatchSettingsView: View {

    @EnvironmentObject private var remote: RemoteViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Digital Crown") {
                    Picker("Crown", selection: $remote.crownAction) {
                        ForEach(CrownAction.allCases) { action in
                            Text(action.displayName).tag(action)
                        }
                    }
                    .labelsHidden()
                    Text(crownExplanation)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section("Prayer mode") {
                    Toggle("Stay on screen", isOn: prayerModeBinding)
                    Text("Keeps the remote frontmost for up to an hour, so it is still there between rak'ahs.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section("iPhone") {
                    LabeledContent("App") {
                        Text(remote.isPhoneAppInstalled ? "Installed" : "Missing")
                    }
                    LabeledContent("Link") {
                        Text(remote.isPhoneReachable ? "Connected" : "Waiting")
                            .foregroundStyle(remote.isPhoneReachable ? .green : .secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var prayerModeBinding: Binding<Bool> {
        Binding(
            get: { remote.isPrayerModeActive },
            set: { newValue in
                guard newValue != remote.isPrayerModeActive else { return }
                remote.togglePrayerMode()
            }
        )
    }

    private var crownExplanation: String {
        switch remote.crownAction {
        case .turnPages: return "One notch, one page."
        case .scrubMushaf: return "Spin quickly across the whole mushaf."
        case .stepVerses: return "One notch moves one verse down the page."
        }
    }
}
