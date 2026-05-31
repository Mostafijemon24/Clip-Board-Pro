//
//  ClipboardPasteCoordinator.swift
//  Clip Board Pro
//

import AppKit
import os

/// Orchestrates popover dismissal, pasteboard write, target-app activation, and auto-paste.
@MainActor
final class ClipboardPasteCoordinator {

    static let shared = ClipboardPasteCoordinator()

    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "PasteCoordinator")

    private init() {}

    func paste(_ item: StoredClipboardItem) {
        MenuBarManager.shared.closePopover()

        let targetApp = MenuBarManager.shared.pasteTargetApplication

        AppServices.shared.clipboardService.suppressCapturesFromOutgoingPaste()

        do {
            try PasteboardWriter.write(item)
        } catch {
            logger.error("Pasteboard write failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        if !AutoPasteService.isAccessibilityTrusted {
            AutoPasteService.requestAccessibilityPermission()
            logger.notice("Accessibility permission required for auto-paste.")
        }

        if let targetApp {
            targetApp.activate(options: [.activateIgnoringOtherApps])
        } else {
            NSApp.hide(nil)
        }

        AutoPasteService.performCommandV()
        logger.info("Pasted item \(item.id.uuidString, privacy: .public)")
    }
}
