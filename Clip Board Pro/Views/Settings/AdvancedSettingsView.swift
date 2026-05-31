//
//  AdvancedSettingsView.swift
//  Clip Board Pro
//

import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage(UserPreferences.securityBlacklistKey) private var securityBlacklist = ""

    @State private var showClearConfirmation = false
    @State private var isClearing = false
    @State private var clearResultMessage: String?
    @State private var clearErrorMessage: String?

    var body: some View {
        Form {
            Section {
                Button("Clear All Unpinned", role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(isClearing)

                if isClearing {
                    ProgressView("Clearing history…")
                        .controlSize(.small)
                }

                if let clearResultMessage {
                    Text(clearResultMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let clearErrorMessage {
                    Text(clearErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Deletes unpinned items only. Up to \(ClipboardStorageConfiguration.maxPinnedItems) pinned clips are kept until you unpin them.")
            }

            Section {
                TextEditor(text: $securityBlacklist)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
            } header: {
                Text("Security Blacklist")
            } footer: {
                Text("One bundle identifier per line (e.g. com.agilebits.onepassword7). These are merged with the built-in secure app list. Changes apply immediately.")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .confirmationDialog(
            "Clear unpinned clipboard history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Unpinned", role: .destructive) {
                Task { await clearHistory() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned items are not removed.")
        }
    }

    private func clearHistory() async {
        isClearing = true
        clearResultMessage = nil
        clearErrorMessage = nil
        defer { isClearing = false }

        do {
            let deleted = try await AppServices.shared.repository.clearUnpinnedHistory()
            clearResultMessage = deleted > 0
                ? "Removed \(deleted) unpinned item(s)."
                : "Nothing to clear (pinned items were kept)."
        } catch {
            clearErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AdvancedSettingsView()
}
