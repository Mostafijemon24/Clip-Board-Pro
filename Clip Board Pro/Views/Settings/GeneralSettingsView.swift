//
//  GeneralSettingsView.swift
//  Clip Board Pro
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(UserPreferences.launchAtLoginEnabledKey) private var launchAtLoginEnabled = false
    @State private var launchAtLoginError: String?

    private var historyShortcutLabel: String {
        ShortcutFormatting.displayString(
            keyCode: UserPreferences.globalShortcutKeyCode,
            modifiers: UserPreferences.globalShortcutModifiers
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Open clipboard history") {
                    Text(historyShortcutLabel)
                        .font(.system(.body, design: .monospaced))
                }
            } footer: {
                Text("Press this shortcut from any app to open your full copy list. macOS reserves plain ⌘V for Paste, so Clip Board Pro uses ⌘⇧V by default (customizable in Shortcuts).")
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                    .onChange(of: launchAtLoginEnabled) { _, enabled in
                        applyLaunchAtLogin(enabled)
                    }
            } footer: {
                Text("Clip Board Pro starts automatically when you log in to your Mac.")
            }

            if let launchAtLoginError {
                Section {
                    Text(launchAtLoginError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .onAppear {
            launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        }
    }
}

#Preview {
    GeneralSettingsView()
}
