//
//  ClipboardService.swift
//  Clip Board Pro
//

import AppKit
import os

/// Monitors `NSPasteboard.general` for changes and emits captures after security filtering.
///
/// macOS does not expose a public pasteboard-change notification, so we poll `changeCount`
/// on a background timer. This is the same technique used by Paste, Maccy, and CopyClip.
@MainActor
final class ClipboardService {

    // MARK: - Callbacks

    var onCapture: ((ClipboardCapture) -> Void)?
    var onIgnoredSecureCopy: ((String) -> Void)?

    // MARK: - Configuration

    /// Polling interval in seconds. 0.5 s balances responsiveness and CPU use.
    var pollInterval: TimeInterval = 0.5

    // MARK: - Private state

    private let pasteboard = NSPasteboard.general
    private let securityFilter: SecurityFilter
    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "ClipboardService")

    private var lastChangeCount: Int
    private var pollTimer: Timer?
    private var isMonitoring = false
    private var suppressCapturesUntil: Date?

    // MARK: - Init

    init(securityFilter: SecurityFilter = SecurityFilter()) {
        self.securityFilter = securityFilter
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastChangeCount = pasteboard.changeCount

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForPasteboardChanges()
            }
        }

        if let pollTimer {
            RunLoop.main.add(pollTimer, forMode: .common)
        }

        logger.info("Clipboard monitoring started (interval: \(self.pollInterval, privacy: .public)s)")
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        isMonitoring = false
        logger.info("Clipboard monitoring stopped")
    }

    var isRunning: Bool { isMonitoring }

    /// Prevents the monitor from re-capturing content we just wrote to the pasteboard.
    func suppressCapturesFromOutgoingPaste(for duration: TimeInterval = 2.0) {
        suppressCapturesUntil = Date().addingTimeInterval(duration)
        lastChangeCount = pasteboard.changeCount
    }

    private var shouldSuppressCapture: Bool {
        if let until = suppressCapturesUntil, Date() < until { return true }
        return false
    }

    // MARK: - Polling

    private func checkForPasteboardChanges() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        if shouldSuppressCapture {
            logger.debug("Skipping capture — outgoing paste suppression active")
            return
        }

        handlePasteboardChange()
    }

    private func handlePasteboardChange() {
        if securityFilter.shouldIgnoreClipboardEvent() {
            let bundleID = securityFilter.frontmostApplicationBundleIdentifier() ?? "unknown"
            logger.debug("Ignored secure copy from \(bundleID, privacy: .public)")
            onIgnoredSecureCopy?(bundleID)
            return
        }

        guard let contentType = extractContentType(from: pasteboard) else {
            logger.debug("Pasteboard changed but no supported content type found")
            return
        }

        let capture = ClipboardCapture(
            contentType: contentType,
            sourceBundleIdentifier: securityFilter.frontmostApplicationBundleIdentifier()
        )

        logger.info("Captured clipboard item (\(String(describing: contentType), privacy: .public))")
        onCapture?(capture)
    }

    // MARK: - Content extraction

    private func extractContentType(from pasteboard: NSPasteboard) -> ClipboardContentType? {
        if let strings = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let text = strings.first,
           !text.isEmpty {
            return .text(text)
        }

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first {
            return .url(url)
        }

        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
        ]

        if pasteboard.availableType(from: imageTypes) != nil {
            if let path = ImageFileStore.saveImageFromPasteboard(pasteboard) {
                return .image(path: path)
            }
            return nil
        }

        if pasteboard.types?.isEmpty == false {
            return .unsupported
        }

        return nil
    }
}
