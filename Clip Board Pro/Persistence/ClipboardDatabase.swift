//
//  ClipboardDatabase.swift
//  Clip Board Pro
//

import Foundation
import SQLite3

struct StorageOptimizationResult: Sendable, Equatable {
    let deletedByAge: Int
    let deletedBySize: Int
    let databaseBytesAfter: Int64

    var totalDeleted: Int { deletedByAge + deletedBySize }
}

/// Low-level CRUD operations against the `clipboard_items` table.
final class ClipboardDatabase: @unchecked Sendable {

    private let sqlite: SQLiteManager

    init(sqlite: SQLiteManager) throws {
        self.sqlite = sqlite
        try sqlite.performSync { connection in
            try Self.migrate(connection)
        }
    }

    // MARK: - Async API (background serial queue)

    func insert(_ item: StoredClipboardItem) async throws {
        try await sqlite.perform { db in
            try self.insert(item, connection: db)
        }
    }

    func fetchRecent(limit: Int) async throws -> [StoredClipboardItem] {
        try await sqlite.perform { db in
            try self.fetchRecent(limit: limit, connection: db)
        }
    }

    func count() async throws -> Int {
        try await sqlite.perform { db in
            try self.count(connection: db)
        }
    }

    func optimizeStorage() async throws -> StorageOptimizationResult {
        try await sqlite.perform { db in
            let deletedByAge = try self.deleteItemsOlderThan(
                ClipboardStorageConfiguration.retentionCutoffDate,
                connection: db
            )

            var deletedBySize = 0
            while self.sqlite.fileSizeOnDisk() > ClipboardStorageConfiguration.maxDatabaseBytes {
                guard let oldest = try self.fetchOldestItem(connection: db) else { break }
                try self.deleteItem(oldest, connection: db)
                deletedBySize += 1
            }

            if deletedByAge + deletedBySize > 0 {
                try self.vacuum(connection: db)
            }

            return StorageOptimizationResult(
                deletedByAge: deletedByAge,
                deletedBySize: deletedBySize,
                databaseBytesAfter: self.sqlite.fileSizeOnDisk()
            )
        }
    }

    func clearAllHistory() async throws -> Int {
        try await sqlite.perform { db in
            let sql = "SELECT kind, content FROM clipboard_items;"
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw ClipboardPersistenceError.sqliteError(self.errorMessage(from: db))
            }

            var deletedCount = 0
            while sqlite3_step(statement) == SQLITE_ROW {
                deletedCount += 1
                let kind = ClipboardItemKind(rawValue: Int(sqlite3_column_int(statement, 0))) ?? .text
                if kind == .image {
                    let path = String(cString: sqlite3_column_text(statement, 1))
                    ImageFileStore.deleteImage(atPath: path)
                }
            }

            var errorMessage: UnsafeMutablePointer<CChar>?
            let deleteStatus = sqlite3_exec(db, "DELETE FROM clipboard_items;", nil, nil, &errorMessage)
            if deleteStatus != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "Delete failed"
                sqlite3_free(errorMessage)
                throw ClipboardPersistenceError.sqliteError(message)
            }

            try self.vacuum(connection: db)
            return deletedCount
        }
    }

    // MARK: - Schema

    private static func migrate(_ db: OpaquePointer) throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS clipboard_items (
            id TEXT PRIMARY KEY NOT NULL,
            kind INTEGER NOT NULL,
            content TEXT NOT NULL,
            source_bundle_id TEXT,
            created_at REAL NOT NULL,
            byte_size INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_clipboard_items_created_at
            ON clipboard_items(created_at ASC);
        """

        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if status != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Migration failed"
            sqlite3_free(errorMessage)
            throw ClipboardPersistenceError.sqliteError(message)
        }
    }

    // MARK: - Sync helpers (run inside sqlite.perform)

    private func insert(_ item: StoredClipboardItem, connection db: OpaquePointer) throws {
        let sql = """
        INSERT INTO clipboard_items
            (id, kind, content, source_bundle_id, created_at, byte_size)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }

        sqlite3_bind_text(statement, 1, item.id.uuidString, -1, Self.transient)
        sqlite3_bind_int(statement, 2, Int32(item.kind.rawValue))
        sqlite3_bind_text(statement, 3, item.content, -1, Self.transient)
        bindOptionalText(statement, index: 4, value: item.sourceBundleIdentifier)
        sqlite3_bind_double(statement, 5, item.createdAt.timeIntervalSinceReferenceDate)
        sqlite3_bind_int64(statement, 6, Int64(item.byteSize))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }
    }

    private func fetchRecent(limit: Int, connection db: OpaquePointer) throws -> [StoredClipboardItem] {
        let sql = """
        SELECT id, kind, content, source_bundle_id, created_at, byte_size
        FROM clipboard_items
        ORDER BY created_at DESC
        LIMIT ?;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var items: [StoredClipboardItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            items.append(try mapRow(statement))
        }
        return items
    }

    private func count(connection db: OpaquePointer) throws -> Int {
        let sql = "SELECT COUNT(*) FROM clipboard_items;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }

        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func deleteItemsOlderThan(_ cutoff: Date, connection db: OpaquePointer) throws -> Int {
        let sql = "SELECT id, kind, content FROM clipboard_items WHERE created_at < ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }

        sqlite3_bind_double(statement, 1, cutoff.timeIntervalSinceReferenceDate)

        var idsToDelete: [(UUID, ClipboardItemKind, String)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let idString = String(cString: sqlite3_column_text(statement, 0))
            guard let id = UUID(uuidString: idString) else { continue }
            let kind = ClipboardItemKind(rawValue: Int(sqlite3_column_int(statement, 1))) ?? .text
            let content = String(cString: sqlite3_column_text(statement, 2))
            idsToDelete.append((id, kind, content))
        }

        for (id, kind, content) in idsToDelete {
            if kind == .image {
                ImageFileStore.deleteImage(atPath: content)
            }
            try executeDelete(id: id, connection: db)
        }

        return idsToDelete.count
    }

    private func fetchOldestItem(connection db: OpaquePointer) throws -> StoredClipboardItem? {
        let sql = """
        SELECT id, kind, content, source_bundle_id, created_at, byte_size
        FROM clipboard_items
        ORDER BY created_at ASC
        LIMIT 1;
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return try mapRow(statement)
    }

    private func deleteItem(_ item: StoredClipboardItem, connection db: OpaquePointer) throws {
        if item.kind == .image {
            ImageFileStore.deleteImage(atPath: item.content)
        }
        try executeDelete(id: item.id, connection: db)
    }

    private func executeDelete(id: UUID, connection db: OpaquePointer) throws {
        let sql = "DELETE FROM clipboard_items WHERE id = ?;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, Self.transient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw ClipboardPersistenceError.sqliteError(errorMessage(from: db))
        }
    }

    private func vacuum(connection db: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, "VACUUM;", nil, nil, &errorMessage)
        if status != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "VACUUM failed"
            sqlite3_free(errorMessage)
            throw ClipboardPersistenceError.sqliteError(message)
        }
    }

    private func mapRow(_ statement: OpaquePointer?) throws -> StoredClipboardItem {
        guard let statement else { throw ClipboardPersistenceError.databaseUnavailable }

        let idString = String(cString: sqlite3_column_text(statement, 0))
        guard let id = UUID(uuidString: idString) else {
            throw ClipboardPersistenceError.sqliteError("Invalid UUID in database row.")
        }

        let kindRaw = Int(sqlite3_column_int(statement, 1))
        let kind = ClipboardItemKind(rawValue: kindRaw) ?? .text
        let content = String(cString: sqlite3_column_text(statement, 2))

        let sourceBundleID: String?
        if let bundleColumn = sqlite3_column_text(statement, 3) {
            sourceBundleID = String(cString: bundleColumn)
        } else {
            sourceBundleID = nil
        }

        let createdAt = Date(timeIntervalSinceReferenceDate: sqlite3_column_double(statement, 4))
        let byteSize = Int(sqlite3_column_int64(statement, 5))

        return StoredClipboardItem(
            id: id,
            kind: kind,
            content: content,
            sourceBundleIdentifier: sourceBundleID,
            createdAt: createdAt,
            byteSize: byteSize
        )
    }

    private func bindOptionalText(_ statement: OpaquePointer?, index: Int32, value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, Self.transient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func errorMessage(from db: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(db))
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
