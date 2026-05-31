//
//  SettingsWindowController.swift
//  Clip Board Pro
//

import AppKit
import SwiftUI

/// Presents settings in a dedicated window (reliable for LSUIElement / menu bar apps).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private(set) var window: NSWindow?

    /// Window used for Sign in with Apple presentation.
    var anchorWindow: NSWindow {
        window ?? NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible } ?? NSWindow()
    }

    private override init() {
        super.init()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsRootView())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "Clip Board Pro Settings"
        window.minSize = NSSize(width: 560, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
