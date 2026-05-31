//
//  ClipboardCapture.swift
//  Clip Board Pro
//

import Foundation

/// Describes the kind of payload on the general pasteboard.
enum ClipboardContentType: Sendable, Equatable {
    case text(String)
    case url(URL)
    /// On-disk image reference; raw bytes are never held in memory.
    case image(path: URL)
    case unsupported
}

/// A single clipboard event that passed security filtering and is ready for persistence.
struct ClipboardCapture: Sendable, Identifiable, Equatable {
    let id: UUID
    let contentType: ClipboardContentType
    let capturedAt: Date
    let sourceBundleIdentifier: String?

    init(
        id: UUID = UUID(),
        contentType: ClipboardContentType,
        capturedAt: Date = .now,
        sourceBundleIdentifier: String?
    ) {
        self.id = id
        self.contentType = contentType
        self.capturedAt = capturedAt
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }
}
