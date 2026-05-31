//
//  UpdatesSettingsView.swift
//  Clip Board Pro
//

import SwiftUI

struct UpdatesSettingsView: View {
#if os(macOS)
    @State private var automaticallyChecks = SparkleUpdateManager.shared.automaticallyChecksForUpdates
    @State private var automaticallyDownloads = SparkleUpdateManager.shared.automaticallyDownloadsUpdates
#endif

    var body: some View {
#if os(macOS)
        macOSContent
#else
        Text("Updates are managed on macOS.")
            .foregroundStyle(.secondary)
            .padding(20)
#endif
    }

#if os(macOS)
    private var macOSContent: some View {
        Form {
            Section {
                LabeledContent("Version", value: SparkleUpdateManager.shared.currentVersionString)
                LabeledContent("Build", value: SparkleUpdateManager.shared.currentBuildString)

                if let feed = SparkleUpdateManager.shared.feedURLString {
                    LabeledContent("Feed") {
                        Text(feed)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            }

            Section {
                Toggle("Automatically check for updates", isOn: $automaticallyChecks)
                    .onChange(of: automaticallyChecks) { _, value in
                        SparkleUpdateManager.shared.automaticallyChecksForUpdates = value
                    }

                Toggle("Automatically download updates", isOn: $automaticallyDownloads)
                    .onChange(of: automaticallyDownloads) { _, value in
                        SparkleUpdateManager.shared.automaticallyDownloadsUpdates = value
                    }

                Button("Check for Updates…") {
                    SparkleUpdateManager.shared.checkForUpdates()
                }
                .disabled(!SparkleUpdateManager.shared.canCheckForUpdates)
            } footer: {
                Text("Clip Board Pro uses Sparkle to deliver signed updates from your appcast feed.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            automaticallyChecks = SparkleUpdateManager.shared.automaticallyChecksForUpdates
            automaticallyDownloads = SparkleUpdateManager.shared.automaticallyDownloadsUpdates
        }
    }
#endif
}

#Preview {
    UpdatesSettingsView()
}
