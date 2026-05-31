//
//  ClipboardSyncCoordinator.swift
//  Clip Board Pro
//

import Foundation

@MainActor
enum ClipboardSyncCoordinator {

    /// Only pinned clips are uploaded to Google Drive.
    static func uploadPinnedIfNeeded(_ item: StoredClipboardItem) async {
        guard item.isPinned else { return }
        guard GoogleAccountManager.shared.isSignedIn,
              UserDefaults.standard.bool(forKey: UserPreferences.cloudSyncEnabledKey) else {
            return
        }
        await GoogleDriveSyncService.shared.upload(item)
    }
}
