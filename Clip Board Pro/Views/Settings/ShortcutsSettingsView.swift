//
//  ShortcutsSettingsView.swift
//  Clip Board Pro
//

import SwiftUI

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Toggle Clipboard History") {
                    ShortcutRecorderView()
                }
            } footer: {
                Text("Opens the clipboard history list with all saved copies. Click Change, then press your shortcut. At least one modifier (⌘, ⌥, ⇧, or ⌃) is required — plain ⌘V cannot be used because macOS uses it for Paste.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

#Preview {
    ShortcutsSettingsView()
}
