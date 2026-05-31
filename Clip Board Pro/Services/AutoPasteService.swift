//
//  AutoPasteService.swift
//  Clip Board Pro
//

import AppKit
import ApplicationServices
import Carbon
import Foundation
import os

/// Posts a synthetic ⌘V keystroke on a background queue so the main thread stays responsive.
enum AutoPasteService {

    private static let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "AutoPaste")
    private static let pasteQueue = DispatchQueue(label: "com.clipboardpro.autopaste", qos: .userInitiated)

    /// Default delay after activating the target app before posting the keystroke.
    static let defaultActivationDelay: TimeInterval = 0.12

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: false] as CFDictionary)
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    @discardableResult
    static func openAccessibilitySettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]

        for urlString in candidates {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    /// Schedules ⌘V on a background queue after a short activation delay.
    static func performCommandV(afterDelay delay: TimeInterval = defaultActivationDelay) {
        pasteQueue.async {
            Thread.sleep(forTimeInterval: delay)

            guard isAccessibilityTrusted else {
                logger.warning("Accessibility permission missing — cannot auto-paste.")
                return
            }

            guard postCommandV() else {
                logger.error("Failed to post ⌘V keystroke.")
                return
            }

            logger.debug("Auto-paste keystroke posted.")
        }
    }

    @discardableResult
    private static func postCommandV() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let virtualKey = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return false
        }

        keyDown.flags = CGEventFlags.maskCommand
        keyUp.flags = CGEventFlags.maskCommand

        keyDown.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp.post(tap: CGEventTapLocation.cghidEventTap)
        return true
    }
}
