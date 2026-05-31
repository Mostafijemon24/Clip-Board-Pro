//
//  StoredClipboardItem.swift
//  Clip Board Pro
//

import Foundation

enum ClipboardItemKind: Int, Sendable, Codable, CaseIterable {
    case text = 0
    case link = 1
    case image = 2

    var displayName: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        }
    }
}

/// A clipboard entry persisted in SQLite.
struct StoredClipboardItem: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let kind: ClipboardItemKind
    /// Text body, URL string, or on-disk image path.
    let content: String
    let sourceBundleIdentifier: String?
    let createdAt: Date
    let byteSize: Int
    let isPinned: Bool
    let pinnedAt: Date?

    init(
        id: UUID,
        kind: ClipboardItemKind,
        content: String,
        sourceBundleIdentifier: String?,
        createdAt: Date,
        byteSize: Int,
        isPinned: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.createdAt = createdAt
        self.byteSize = byteSize
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
    }

    init(from capture: ClipboardCapture) throws {
        guard let payload = capture.persistencePayload else {
            throw ClipboardPersistenceError.unsupportedContent
        }

        id = capture.id
        kind = payload.kind
        content = payload.content
        sourceBundleIdentifier = capture.sourceBundleIdentifier
        createdAt = capture.capturedAt
        byteSize = payload.byteSize
        isPinned = false
        pinnedAt = nil
    }

    func withPinState(isPinned: Bool, pinnedAt: Date?) -> StoredClipboardItem {
        StoredClipboardItem(
            id: id,
            kind: kind,
            content: content,
            sourceBundleIdentifier: sourceBundleIdentifier,
            createdAt: createdAt,
            byteSize: byteSize,
            isPinned: isPinned,
            pinnedAt: pinnedAt
        )
    }

    var previewText: String {
        switch kind {
        case .text:
            content.count > 120 ? String(content.prefix(120)) + "…" : content
        case .link:
            content
        case .image:
            URL(fileURLWithPath: content).lastPathComponent
        }
    }
}

enum ClipboardPersistenceError: Error, LocalizedError {
    case unsupportedContent
    case databaseUnavailable
    case sqliteError(String)
    case pinLimitReached

    var errorDescription: String? {
        switch self {
        case .unsupportedContent:
            "Clipboard content cannot be persisted."
        case .databaseUnavailable:
            "Database connection is unavailable."
        case .sqliteError(let message):
            message
        case .pinLimitReached:
            "You can pin up to \(ClipboardStorageConfiguration.maxPinnedItems) items. Unpin one first."
        }
    }
}

extension ClipboardCapture {
    var persistencePayload: (kind: ClipboardItemKind, content: String, byteSize: Int)? {
        switch contentType {
        case .text(let value):
            return (.text, value, value.utf8.count)
        case .url(let url):
            let value = url.absoluteString
            return (.link, value, value.utf8.count)
        case .image(let path):
            return (.image, path.path, fileSize(at: path.path))
        case .unsupported:
            return nil
        }
    }
}

private func fileSize(at path: String) -> Int {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
}
