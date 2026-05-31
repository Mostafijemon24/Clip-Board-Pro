//
//  UserPreferences.swift
//  Clip Board Pro
//

import Carbon
import Foundation

/// Central keys and helpers for `@AppStorage` / `UserDefaults` persistence.
enum UserPreferences {
    static let launchAtLoginEnabledKey = "launchAtLoginEnabled"
    static let globalShortcutKeyCodeKey = "globalShortcutKeyCode"
    static let globalShortcutModifiersKey = "globalShortcutModifiers"
    static let securityBlacklistKey = "securityBlacklistBundleIDs"
    static let hasCompletedAccessibilityOnboardingKey = "hasCompletedAccessibilityOnboarding"
    static let appleUserIdentifierKey = "appleUserIdentifier"
    static let appleUserEmailKey = "appleUserEmail"
    static let appleUserFullNameKey = "appleUserFullName"
    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    static let cloudSyncEnabledKey = "cloudSyncEnabled"

    static let defaultShortcutKeyCode = Int(kVK_ANSI_V)
    static let defaultShortcutModifiers = Int(cmdKey | shiftKey)

    static let shortcutDidChangeNotification = Notification.Name("UserPreferences.shortcutDidChange")

    static var globalShortcutKeyCode: Int {
        let stored = UserDefaults.standard.integer(forKey: globalShortcutKeyCodeKey)
        return stored == 0 ? defaultShortcutKeyCode : stored
    }

    static var globalShortcutModifiers: Int {
        let stored = UserDefaults.standard.object(forKey: globalShortcutModifiersKey) as? Int
        return stored ?? defaultShortcutModifiers
    }

    static func parsedCustomBlacklist(from raw: String) -> Set<String> {
        Set(
            raw
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    static func resolvedSecureBundleIDs(customBlacklist: String? = nil) -> Set<String> {
        let raw = customBlacklist ?? UserDefaults.standard.string(forKey: securityBlacklistKey) ?? ""
        return SecurityFilter.defaultSecureBundleIDs.union(parsedCustomBlacklist(from: raw))
    }
}
