//
//  Clip_Board_ProApp.swift
//  Clip Board Pro
//

import SwiftUI

@main
struct Clip_Board_ProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView()
        }
    }
}
