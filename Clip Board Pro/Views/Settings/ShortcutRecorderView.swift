//
//  ShortcutRecorderView.swift
//  Clip Board Pro
//

import AppKit
import SwiftUI

struct ShortcutRecorderView: View {
    @AppStorage(UserPreferences.globalShortcutKeyCodeKey) private var keyCode = UserPreferences.defaultShortcutKeyCode
    @AppStorage(UserPreferences.globalShortcutModifiersKey) private var modifiers = UserPreferences.defaultShortcutModifiers

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayShortcut: String {
        ShortcutFormatting.displayString(keyCode: keyCode, modifiers: modifiers)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(displayShortcut)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 120, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                }

            Button(isRecording ? "Recording…" : "Change") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }

            Button("Reset") {
                resetToDefault()
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stopRecording()
                return nil
            }

            let carbonModifiers = ShortcutFormatting.carbonModifiers(from: event.modifierFlags)
            guard carbonModifiers != 0 else { return event }

            keyCode = Int(event.keyCode)
            modifiers = Int(carbonModifiers)
            stopRecording()
            GlobalShortcutManager.shared.registerFromPreferences()
            NotificationCenter.default.post(name: UserPreferences.shortcutDidChangeNotification, object: nil)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func resetToDefault() {
        keyCode = UserPreferences.defaultShortcutKeyCode
        modifiers = UserPreferences.defaultShortcutModifiers
        GlobalShortcutManager.shared.registerFromPreferences()
        NotificationCenter.default.post(name: UserPreferences.shortcutDidChangeNotification, object: nil)
    }
}

#Preview {
    ShortcutRecorderView()
        .padding()
}
