//
//  OnboardingWindowController.swift
//  Clip Board Pro
//

import AppKit
import SwiftUI

/// Presents the first-launch Accessibility onboarding window.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {

    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func presentIfNeeded() {
        guard window == nil else { return }

        if UserDefaults.standard.bool(forKey: UserPreferences.hasCompletedAccessibilityOnboardingKey) {
            return
        }

        if AutoPasteService.isAccessibilityTrusted {
            markOnboardingComplete()
            return
        }

        let onboardingView = PermissionsOnboardingView { [weak self] in
            self?.markOnboardingComplete()
            self?.dismiss(animated: true)
        }

        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "Welcome to Clip Board Pro"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss(animated: Bool) {
        guard let window else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                window.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                window.orderOut(nil)
                self?.window = nil
            }
        } else {
            window.orderOut(nil)
            self.window = nil
        }
    }

    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: UserPreferences.hasCompletedAccessibilityOnboardingKey)
    }

    func windowWillClose(_ notification: Notification) {
        markOnboardingComplete()
        window = nil
    }
}
