//
//  LaunchAtLoginManager.swift
//  Clip Board Pro
//

import Foundation
import ServiceManagement
import os

@MainActor
enum LaunchAtLoginManager {

    private static let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "LaunchAtLogin")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            logger.info("Launch at Login enabled")
        } else {
            try SMAppService.mainApp.unregister()
            logger.info("Launch at Login disabled")
        }
    }

    /// Applies the stored preference on launch and reconciles toggle state with system status.
    static func applyStoredPreference(_ enabled: Bool) {
        do {
            if enabled && !isEnabled {
                try setEnabled(true)
            } else if !enabled && isEnabled {
                try setEnabled(false)
            }
        } catch {
            logger.error("Launch at Login sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
