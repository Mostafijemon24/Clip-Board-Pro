//
//  ClipboardSyncPayload.swift
//  Clip Board Pro
//

import Foundation

/// JSON document stored in Google Drive app data for each clipboard item.
struct ClipboardSyncPayload: Codable, Sendable {
    let id: UUID
    let kind: ClipboardItemKind
    let content: String
    let sourceBundleIdentifier: String?
    let createdAt: Date
    let byteSize: Int
    let isPinned: Bool
    let pinnedAt: Date?
    let driveImageFileID: String?

    init(item: StoredClipboardItem, driveImageFileID: String? = nil) {
        id = item.id
        kind = item.kind
        content = item.content
        sourceBundleIdentifier = item.sourceBundleIdentifier
        createdAt = item.createdAt
        byteSize = item.byteSize
        isPinned = item.isPinned
        pinnedAt = item.pinnedAt
        self.driveImageFileID = driveImageFileID
    }

    func asStoredItem(localImagePath: String? = nil) -> StoredClipboardItem {
        let resolvedContent: String
        if kind == .image, let localImagePath {
            resolvedContent = localImagePath
        } else {
            resolvedContent = content
        }

        return StoredClipboardItem(
            id: id,
            kind: kind,
            content: resolvedContent,
            sourceBundleIdentifier: sourceBundleIdentifier,
            createdAt: createdAt,
            byteSize: byteSize,
            isPinned: isPinned,
            pinnedAt: pinnedAt
        )
    }
}
