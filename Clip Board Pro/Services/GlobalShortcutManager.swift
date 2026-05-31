//
//  GlobalShortcutManager.swift
//  Clip Board Pro
//

import AppKit
import Carbon
import os

/// Registers a system-wide hotkey to toggle the clipboard popover.
@MainActor
final class GlobalShortcutManager {

    static let shared = GlobalShortcutManager()

    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "GlobalShortcut")
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isHandlerInstalled = false

    private enum HotKeyID {
        static let signature: OSType = 0x4342_5052 // "CBPR"
        static let togglePopover: UInt32 = 1
    }

    private init() {}

    func registerFromPreferences() {
        unregisterHotKey()
        installEventHandlerIfNeeded()

        let keyCode = UInt32(UserPreferences.globalShortcutKeyCode)
        let modifiers = UInt32(UserPreferences.globalShortcutModifiers)
        let hotKeyID = EventHotKeyID(signature: HotKeyID.signature, id: HotKeyID.togglePopover)

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            logger.error("Failed to register global shortcut (\(registerStatus))")
            return
        }

        let label = ShortcutFormatting.displayString(
            keyCode: Int(keyCode),
            modifiers: Int(modifiers)
        )
        logger.info("Global shortcut registered: \(label, privacy: .public)")
    }

    func unregister() {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
            isHandlerInstalled = false
        }
    }

    // MARK: - Private

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            logger.error("Failed to install hotkey handler (\(installStatus))")
            return
        }

        isHandlerInstalled = true
    }

    private static let hotKeyEventHandler: EventHandlerUPP = { _, event, _ -> OSStatus in
        var hotKeyID = EventHotKeyID()
        let paramSize = MemoryLayout<EventHotKeyID>.size

        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            paramSize,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.id == HotKeyID.togglePopover else {
            return noErr
        }

        Task { @MainActor in
            MenuBarManager.shared.toggleFromGlobalShortcut()
        }

        return noErr
    }
}
