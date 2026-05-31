//
//  MenuBarManager.swift
//  Clip Board Pro
//

import AppKit
import SwiftUI

/// Owns the menu bar status item and presents `ClipboardHistoryView` in a transient popover.
@MainActor
final class MenuBarManager: NSObject, NSPopoverDelegate {

    static let shared = MenuBarManager()
    static let popoverDidOpenNotification = Notification.Name("MenuBarManager.popoverDidOpen")

    private(set) var pasteTargetApplication: NSRunningApplication?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var contextMenu: NSMenu?
    private let historyViewModel: ClipboardHistoryViewModel

    private override init() {
        historyViewModel = ClipboardHistoryViewModel()
        super.init()
    }

    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "clipboard",
            accessibilityDescription: "Clip Board Pro"
        )
        item.button?.image?.isTemplate = true
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: NSEvent.EventTypeMask([.leftMouseUp, .rightMouseUp]))

        contextMenu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        contextMenu?.addItem(settingsItem)

        contextMenu?.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Clip Board Pro",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        contextMenu?.addItem(quitItem)

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: ClipboardHistoryView(viewModel: historyViewModel)
        )

        statusItem = item
        self.popover = popover
    }

    func closePopover() {
        popover?.performClose(nil)
    }

    var isPopoverShown: Bool {
        popover?.isShown ?? false
    }

    /// Opens the clipboard history popover (Dock/Finder launch or reopen).
    func showMainUIOnLaunch() {
        openPopover()
    }

    /// Called by the global ⌘⇧V shortcut.
    func toggleFromGlobalShortcut() {
        if isPopoverShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    // MARK: - Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }

        if event.type == .rightMouseUp {
            contextMenu?.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 4),
                in: sender
            )
            return
        }

        togglePopover(sender)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if isPopoverShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    @objc func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func openPopover() {
        guard let button = statusItem?.button, let popover else { return }

        capturePasteTargetIfNeeded()

        Task {
            await historyViewModel.load()
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Remembers the app that was active before the popover took focus (used for auto-paste).
    private func capturePasteTargetIfNeeded() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let ourBundleID = Bundle.main.bundleIdentifier
        if app.bundleIdentifier != ourBundleID {
            pasteTargetApplication = app
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidShow(_ notification: Notification) {
        NotificationCenter.default.post(name: Self.popoverDidOpenNotification, object: self)
    }
}
