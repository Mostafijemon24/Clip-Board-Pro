//
//  AppDelegate.swift
//  Clip Board Pro
//

import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarManager.shared.setup()
        GlobalShortcutManager.shared.registerFromPreferences()

        let launchAtLogin = UserDefaults.standard.bool(forKey: UserPreferences.launchAtLoginEnabledKey)
        LaunchAtLoginManager.applyStoredPreference(launchAtLogin)

        AppServices.shared.start()

#if os(macOS)
        _ = SparkleUpdateManager.shared
#endif

        OnboardingWindowController.shared.presentIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalShortcutManager.shared.unregister()
        MenuBarManager.shared.closePopover()
        AppServices.shared.stop()
    }
}
