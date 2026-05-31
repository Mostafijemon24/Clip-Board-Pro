//
//  ClipboardStorageConfiguration.swift
//  Clip Board Pro
//

import Foundation

enum ClipboardStorageConfiguration: Sendable {
    static let retentionDays = 30
    static let maxDatabaseBytes: Int64 = 100 * 1024 * 1024 // 100 MB
    static let databaseFileName = "clipboard.db"
    static let appSupportFolderName = "Clip Board Pro"
    static let imagesFolderName = "Images"
    static let maxPinnedItems = 50
    static let imageThumbnailMaxPixels = 96

    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent(appSupportFolderName, isDirectory: true)
    }

    static var databaseURL: URL {
        applicationSupportDirectory.appendingPathComponent(databaseFileName)
    }

    static var imagesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent(imagesFolderName, isDirectory: true)
    }

    static var retentionCutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -retentionDays, to: .now) ?? .now
    }
}
