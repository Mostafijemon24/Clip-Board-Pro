//
//  CloudSyncService.swift
//  Clip Board Pro
//

import CloudKit
import Foundation
import os

/// Syncs clipboard items across devices for the same Apple ID using CloudKit.
@MainActor
@Observable
final class CloudSyncService {

    static let shared = CloudSyncService()

    static let containerIdentifier = "iCloud.Mostafij-Emon.Clip-Board-Pro"

    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "CloudSync")
    private let container = CKContainer(identifier: containerIdentifier)
    private var database: CKDatabase { container.privateCloudDatabase }

    private(set) var isSyncing = false
    private(set) var statusMessage = "Sign in with Apple to sync across your devices."
    private(set) var lastSyncDate: Date?

    private enum Record {
        static let type = "ClipboardItem"
        static let itemID = "itemID"
        static let kind = "kind"
        static let content = "content"
        static let sourceBundleID = "sourceBundleID"
        static let createdAt = "createdAt"
        static let byteSize = "byteSize"
        static let ownerUserID = "ownerUserID"
        static let imageAsset = "imageAsset"
    }

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserPreferences.iCloudSyncEnabledKey)
            && AccountManager.shared.isSignedIn
    }

    func startSync() async {
        guard isEnabled, let ownerID = AccountManager.shared.userIdentifier else {
            statusMessage = "Sign in with Apple and enable sync."
            return
        }

        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = "Syncing…"
        defer { isSyncing = false }

        let accountStatus = try? await container.accountStatus()
        if accountStatus != .available {
            statusMessage = cloudKitUnavailableMessage
            return
        }

        do {
            let records = try await fetchRecords(ownerID: ownerID)
            var imported = 0
            for record in records {
                if let item = try await mapRecordToItem(record) {
                    try await AppServices.shared.repository.importFromCloud(item)
                    imported += 1
                }
            }
            statusMessage = imported > 0 ? "Synced \(imported) item(s) from iCloud." : "Synced with iCloud."
            lastSyncDate = Date()
        } catch let error as CKError where error.code == .notAuthenticated || error.code == .permissionFailure {
            statusMessage = cloudKitUnavailableMessage
            logger.error("CloudKit unavailable: \(error.localizedDescription, privacy: .public)")
        } catch {
            statusMessage = error.localizedDescription
            logger.error("Sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var cloudKitUnavailableMessage: String {
        "iCloud sync needs Sign in with Apple + CloudKit enabled in Xcode (paid Apple Developer Program)."
    }

    func stopSync() async {
        statusMessage = "Sync paused."
    }

    func uploadIfNeeded(_ item: StoredClipboardItem) async {
        guard isEnabled, let ownerID = AccountManager.shared.userIdentifier else { return }

        let recordID = CKRecord.ID(recordName: item.id.uuidString)
        let record = CKRecord(recordType: Record.type, recordID: recordID)
        record[Record.itemID] = item.id.uuidString as CKRecordValue
        record[Record.kind] = item.kind.rawValue as CKRecordValue
        record[Record.content] = item.content as CKRecordValue
        record[Record.createdAt] = item.createdAt as CKRecordValue
        record[Record.byteSize] = item.byteSize as CKRecordValue
        record[Record.ownerUserID] = ownerID as CKRecordValue

        if let bundleID = item.sourceBundleIdentifier {
            record[Record.sourceBundleID] = bundleID as CKRecordValue
        }

        if item.kind == .image {
            let path = item.content
            if FileManager.default.fileExists(atPath: path) {
                record[Record.imageAsset] = CKAsset(fileURL: URL(fileURLWithPath: path))
            }
        }

        do {
            _ = try await database.save(record)
            logger.debug("Uploaded item \(item.id.uuidString, privacy: .public)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            logger.debug("Record already exists in iCloud.")
        } catch {
            logger.error("Upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fetchRecords(ownerID: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@", Record.ownerUserID, ownerID)
        let query = CKQuery(recordType: Record.type, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Record.createdAt, ascending: false)]

        let db = database
        return try await withCheckedThrowingContinuation { continuation in
            var collected: [CKRecord] = []

            func perform(_ operation: CKQueryOperation) {
                operation.recordMatchedBlock = { _, result in
                    if case .success(let record) = result {
                        collected.append(record)
                    }
                }
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        if let cursor {
                            perform(CKQueryOperation(cursor: cursor))
                        } else {
                            continuation.resume(returning: collected)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                db.add(operation)
            }

            perform(CKQueryOperation(query: query))
        }
    }

    private func mapRecordToItem(_ record: CKRecord) async throws -> StoredClipboardItem? {
        guard let idString = record[Record.itemID] as? String,
              let id = UUID(uuidString: idString),
              let kindRaw = record[Record.kind] as? Int,
              let kind = ClipboardItemKind(rawValue: kindRaw),
              let createdAt = record[Record.createdAt] as? Date else {
            return nil
        }

        var content = record[Record.content] as? String ?? ""
        let byteSize = (record[Record.byteSize] as? Int) ?? content.utf8.count
        let sourceBundleID = record[Record.sourceBundleID] as? String

        if kind == .image, let asset = record[Record.imageAsset] as? CKAsset,
           let sourceURL = asset.fileURL,
           let saved = ImageFileStore.importImage(from: sourceURL) {
            content = saved.path
        }

        guard !content.isEmpty else { return nil }

        return StoredClipboardItem(
            id: id,
            kind: kind,
            content: content,
            sourceBundleIdentifier: sourceBundleID,
            createdAt: createdAt,
            byteSize: byteSize
        )
    }
}
