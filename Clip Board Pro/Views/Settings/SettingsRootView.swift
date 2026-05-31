//
//  SettingsRootView.swift
//  Clip Board Pro
//

import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case shortcuts
    case account
    case advanced
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .account: "Account"
        case .advanced: "Advanced"
        case .updates: "Updates"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "command"
        case .account: "person.crop.circle"
        case .advanced: "slider.horizontal.3"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

/// Sidebar settings layout — avoids blank TabView panels in menu bar apps.
struct SettingsRootView: View {
    @State private var selection: SettingsTab = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selection) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:
            GeneralSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .account:
            AccountSettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .updates:
            UpdatesSettingsView()
        }
    }
}

#Preview {
    SettingsRootView()
}
