//
//  AccessibilityPermissionMonitor.swift
//  Clip Board Pro
//

import ApplicationServices
import AppKit
import Foundation
import Observation

/// Observes Accessibility trust status and opens the correct System Settings pane.
@MainActor
@Observable
final class AccessibilityPermissionMonitor {

    private(set) var isTrusted = AXIsProcessTrusted()

    private var pollTimer: Timer?
    private var onGranted: (() -> Void)?

    func startMonitoring(onGranted: @escaping () -> Void) {
        self.onGranted = onGranted
        refreshTrustStatus()

        guard !isTrusted else {
            onGranted()
            return
        }

        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTrustStatus()
            }
        }

        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        onGranted = nil
    }

    func refreshTrustStatus() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }

        isTrusted = trusted
        if trusted {
            onGranted?()
        }
    }

    func openAccessibilitySettings() {
        AutoPasteService.openAccessibilitySettings()
    }
}
