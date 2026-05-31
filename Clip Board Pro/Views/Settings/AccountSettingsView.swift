//
//  AccountSettingsView.swift
//  Clip Board Pro
//

import SwiftUI

struct AccountSettingsView: View {
    @Bindable private var cloud = CloudAccountCoordinator.shared
    @Bindable private var googleAccount = GoogleAccountManager.shared
    @AppStorage(UserPreferences.cloudSyncEnabledKey) private var syncEnabled = true

    var body: some View {
        Form {
            if cloud.isConnected {
                connectedSection
            } else {
                connectSection
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }

    private var connectSection: some View {
        Group {
            Section {
                Text("Only **pinned** clips sync to Google Drive (up to \(ClipboardStorageConfiguration.maxPinnedItems)). Regular copies stay on this Mac only.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    cloud.connectGoogle()
                } label: {
                    Label("Connect Google Account", systemImage: "g.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } footer: {
                Text("One tap — no API keys to paste. Sign in and allow access.")
            }

            if let error = cloud.lastErrorMessage ?? googleAccount.lastErrorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var connectedSection: some View {
        Section {
            LabeledContent("Google account", value: cloud.connectedAccountLabel)

            Toggle("Sync pinned clips", isOn: $syncEnabled)
                .onChange(of: syncEnabled) { _, enabled in
                    UserDefaults.standard.set(enabled, forKey: UserPreferences.cloudSyncEnabledKey)
                    Task {
                        if enabled {
                            await cloud.syncNow()
                        } else {
                            await GoogleDriveSyncService.shared.stopSync()
                        }
                    }
                }

            LabeledContent("Status") {
                Text(cloud.statusMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            Button("Sync Pinned Now") {
                Task { await cloud.syncNow() }
            }
            .disabled(!syncEnabled || cloud.isSyncing)

            Button("Disconnect Google", role: .destructive) {
                cloud.disconnect()
            }
        } footer: {
            Text("Pin important clips in your history (⌘⇧V list). Only pinned items upload and download. Max \(ClipboardStorageConfiguration.maxPinnedItems) pins.")
        }
    }
}

#Preview {
    AccountSettingsView()
}
