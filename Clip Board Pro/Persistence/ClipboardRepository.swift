//
//  ClipboardRepository.swift
//  Clip Board Pro
//

import Foundation
import os

/// High-level persistence API. All database work runs on SQLiteManager's background queue.
final class ClipboardRepository: @unchecked Sendable {

    static let historyDidChangeNotification = Notification.Name("ClipboardRepository.historyDidChange")

    private let database: ClipboardDatabase
    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "ClipboardRepository")

    init(databaseURL: URL = ClipboardStorageConfiguration.databaseURL) throws {
        let sqlite = try SQLiteManager(databaseURL: databaseURL)
        database = try ClipboardDatabase(sqlite: sqlite)
    }

    /// Runs retention and size pruning. Call once at app launch before monitoring starts.
    func optimizeStorageOnStartup() async throws -> StorageOptimizationResult {
        let result = try await database.optimizeStorage()

        if result.totalDeleted > 0 {
            logger.info(
                "Storage optimized: \(result.deletedByAge, privacy: .public) by age, \(result.deletedBySize, privacy: .public) by size"
            )
        } else {
            logger.debug("Storage already within limits (\(result.databaseBytesAfter, privacy: .public) bytes)")
        }

        await postHistoryChanged()
        return result
    }

    /// Persists a capture on the background SQLite queue.
    func save(_ capture: ClipboardCapture) async throws -> StoredClipboardItem {
        let item = try StoredClipboardItem(from: capture)
        try await database.insert(item)
        logger.debug("Saved item \(item.id.uuidString, privacy: .public)")
        await postHistoryChanged()
        return item
    }

    /// Merges a pinned item from Google Drive into local storage.
    func importFromCloud(_ item: StoredClipboardItem) async throws {
        guard item.isPinned else { return }
        let inserted = try await database.insertIfNotExists(item)
        if inserted {
            logger.debug("Imported cloud item \(item.id.uuidString, privacy: .public)")
            await postHistoryChanged()
        }
    }

    func fetchRecent(limit: Int = 200) async throws -> [StoredClipboardItem] {
        try await database.fetchRecent(limit: limit)
    }

    func itemCount() async throws -> Int {
        try await database.count()
    }

    func pinnedCount() async throws -> Int {
        try await database.countPinned()
    }

    func setPinned(id: UUID, pinned: Bool) async throws {
        try await database.setPinned(id: id, pinned: pinned)
        await postHistoryChanged()
    }

    func fetchAllPinned() async throws -> [StoredClipboardItem] {
        try await database.fetchAllPinned()
    }

    /// Removes all items except pinned clips.
    func clearUnpinnedHistory() async throws -> Int {
        let deleted = try await database.clearUnpinnedHistory()
        logger.info("Cleared \(deleted, privacy: .public) unpinned clipboard items")
        await postHistoryChanged()
        return deleted
    }

    func clearAllHistory() async throws -> Int {
        try await clearUnpinnedHistory()
    }

    @MainActor
    private func postHistoryChanged() {
        NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: self)
    }
}
