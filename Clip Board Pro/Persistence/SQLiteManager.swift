//
//  SQLiteManager.swift
//  Clip Board Pro
//

import Foundation
import SQLite3

/// Thread-safe SQLite access via a dedicated serial background queue.
final class SQLiteManager: @unchecked Sendable {

    private var connection: OpaquePointer?
    private let queue = DispatchQueue(label: "com.clipboardpro.sqlite", qos: .utility)
    let databaseURL: URL

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try queue.sync {
            try openConnection()
        }
    }

    deinit {
        queue.sync {
            if let connection {
                sqlite3_close(connection)
            }
        }
    }

    func perform<T>(_ work: @escaping (OpaquePointer) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let connection = self.connection else {
                    continuation.resume(throwing: ClipboardPersistenceError.databaseUnavailable)
                    return
                }

                do {
                    let value = try work(connection)
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func performSync<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            guard let connection else {
                throw ClipboardPersistenceError.databaseUnavailable
            }
            return try work(connection)
        }
    }

    func fileSizeOnDisk() -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: databaseURL.path)[.size] as? Int64) ?? 0
    }

    // MARK: - Private

    private func openConnection() throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(databaseURL.path, &connection, flags, nil)
        guard status == SQLITE_OK else {
            throw ClipboardPersistenceError.sqliteError(lastErrorMessage())
        }

        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
    }

    private func execute(_ sql: String) throws {
        guard let connection else {
            throw ClipboardPersistenceError.databaseUnavailable
        }

        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
        if status != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorMessage)
            throw ClipboardPersistenceError.sqliteError(message)
        }
    }

    private func lastErrorMessage() -> String {
        guard let connection else { return "Unknown SQLite error" }
        return String(cString: sqlite3_errmsg(connection))
    }
}
