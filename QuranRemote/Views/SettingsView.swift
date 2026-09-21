import QuranCore
import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var reader: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                readingSection
                watchSection
                nearbySection
                offlineSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Reading

    private var readingSection: some View {
        Section("Reading") {
            Picker("Layout", selection: $reader.preferences.displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Picker("Theme", selection: $reader.preferences.theme) {
                ForEach(ReaderTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Text size")
                    Spacer()
                    Text(String(format: "%.0f%%", reader.preferences.clampedFontScale * 100))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $reader.preferences.fontScale,
                    in: ReaderPreferences.fontScaleRange,
                    step: 0.05
                )
                Text(sampleText)
                    .font(MushafFont.arabic(size: MushafFont.size(base: 22, scale: reader.preferences.clampedFontScale)))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .environment(\.layoutDirection, .rightToLeft)
            }

            Toggle("Keep the screen awake", isOn: $reader.preferences.keepScreenAwake)
            Toggle("Highlight the verse I am on", isOn: $reader.preferences.highlightFocusedVerse)
            Toggle("Vibrate when the watch turns a page", isOn: $reader.preferences.hapticOnPageTurn)
            Toggle("Two pages side by side on iPad", isOn: $reader.preferences.twoPageSpreadOnPad)
        }
    }

    private var sampleText: String {
        QuranText.basmalah
    }

    // MARK: - Watch

    private var watchSection: some View {
        Section {
            LabeledContent("Watch app") {
                Text(reader.watchAppIsInstalled ? "Installed" : "Not installed")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Connection") {
                Text(reader.watchIsReachable ? "Connected" : "Waiting")
                    .foregroundStyle(reader.watchIsReachable ? .green : .secondary)
            }
        } header: {
            Text("Apple Watch")
        } footer: {
            Text("Open Quran Remote on the watch to turn pages from your wrist: the buttons and the Digital Crown both work, and the watch has its own setting for what the crown does.")
        }
    }

    // MARK: - Nearby devices

    private var nearbySection: some View {
        Section {
            Toggle("Link nearby iPhone and iPad", isOn: $reader.preferences.nearbyLinkEnabled)
            if reader.nearbyDeviceNames.isEmpty {
                Text(reader.preferences.nearbyLinkEnabled ? "Looking for other devices…" : "Off")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reader.nearbyDeviceNames, id: \.self) { name in
                    Label(name, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("Reading on the iPad")
        } footer: {
            Text("An Apple Watch can only pair with an iPhone. Turn this on, on both devices, and the iPhone will pass the watch's page turns to the iPad over the local network — so the mushaf can be on the big screen while your wrist does the turning.")
        }
    }

    // MARK: - Offline

    private var offlineSection: some View {
        Section {
            LabeledContent("Downloaded") {
                Text("\(reader.downloadedPageCount) of \(Mushaf.pageCount) pages")
                    .foregroundStyle(.secondary)
            }

            switch reader.downloadState {
            case .running(let completed, let total):
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(completed), total: Double(total))
                    HStack {
                        Text("\(completed) of \(total)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Stop") { reader.cancelDownload() }
                    }
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Download stopped")
                        .font(.footnote.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Try again") { reader.downloadWholeMushaf() }
                }
            case .finished:
                Label("The whole mushaf is on this device", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            case .idle:
                Button("Download the whole mushaf") {
                    reader.downloadWholeMushaf()
                }
            }

            Button("Remove downloaded pages", role: .destructive) {
                reader.clearDownloads()
            }
        } header: {
            Text("Offline")
        } footer: {
            Text("Pages are cached as you read them. Downloading all 604 pages takes a few minutes and a few megabytes, and means the mushaf works with no signal at all.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Arabic font", value: MushafFont.installedFamily ?? "System serif")
            LabeledContent("Text source", value: "alquran.cloud / quran.com")
        } header: {
            Text("About")
        } footer: {
            Text("Qur'an text is Uthmani script fetched from public Qur'an APIs and cached on the device. Please report anything that looks wrong in the text.")
        }
    }
}
