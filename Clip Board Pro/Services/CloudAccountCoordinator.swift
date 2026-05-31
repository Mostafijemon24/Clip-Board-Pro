//
//  CloudAccountCoordinator.swift
//  Clip Board Pro
//

import Foundation
import Observation

@MainActor
@Observable
final class CloudAccountCoordinator {

    static let shared = CloudAccountCoordinator()

    private(set) var lastErrorMessage: String?

    private init() {}

    var isConnected: Bool { GoogleAccountManager.shared.isSignedIn }

    var connectedAccountLabel: String {
        GoogleAccountManager.shared.displayName
    }

    var statusMessage: String {
        GoogleDriveSyncService.shared.statusMessage
    }

    var isSyncing: Bool {
        GoogleDriveSyncService.shared.isSyncing
    }

    var canConnectGoogle: Bool { AppCloudConfig.isGoogleConfigured }

    func connectGoogle() {
        lastErrorMessage = nil
        guard canConnectGoogle else {
            lastErrorMessage = "Google sign-in is not configured in this build."
            return
        }
        GoogleAccountManager.shared.signIn()
    }

    func disconnect() {
        GoogleAccountManager.shared.signOut(silent: false)
        UserDefaults.standard.set(false, forKey: UserPreferences.cloudSyncEnabledKey)
    }

    func syncNow() async {
        lastErrorMessage = nil
        guard isConnected else {
            lastErrorMessage = "Connect Google first."
            return
        }
        await GoogleDriveSyncService.shared.startSync()
    }

    func startupSyncIfNeeded() async {
        guard isConnected,
              UserDefaults.standard.bool(forKey: UserPreferences.cloudSyncEnabledKey) else { return }
        await GoogleDriveSyncService.shared.startSync()
    }
}
