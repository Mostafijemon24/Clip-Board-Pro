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
                Text("Click Change, then press the desired key combination. At least one modifier (⌘, ⌥, ⇧, or ⌃) is required.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

#Preview {
    ShortcutsSettingsView()
}
