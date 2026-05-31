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

    func fetchRecent(limit: Int = 200) async throws -> [StoredClipboardItem] {
        try await database.fetchRecent(limit: limit)
    }

    func itemCount() async throws -> Int {
        try await database.count()
    }

    func clearAllHistory() async throws -> Int {
        let deleted = try await database.clearAllHistory()
        logger.info("Cleared \(deleted, privacy: .public) clipboard items")
        await postHistoryChanged()
        return deleted
    }

    @MainActor
    private func postHistoryChanged() {
        NotificationCenter.default.post(name: Self.historyDidChangeNotification, object: self)
    }
}
