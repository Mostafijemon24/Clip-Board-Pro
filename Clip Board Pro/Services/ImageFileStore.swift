//
//  ImageFileStore.swift
//  Clip Board Pro
//

import AppKit
import Foundation

/// Writes clipboard image bytes directly to disk without retaining them in memory.
enum ImageFileStore {

    static func saveImageFromPasteboard(_ pasteboard: NSPasteboard) -> URL? {
        let candidates: [(NSPasteboard.PasteboardType, String)] = [
            (.png, "png"),
            (.tiff, "tiff"),
            (NSPasteboard.PasteboardType("public.jpeg"), "jpg"),
        ]

        for (type, fileExtension) in candidates {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            if let url = try? writeData(data, fileExtension: fileExtension) {
                return url
            }
        }
        return nil
    }

    @discardableResult
    static func deleteImage(atPath path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private

    private static func writeData(_ data: Data, fileExtension: String) throws -> URL {
        let directory = ClipboardStorageConfiguration.imagesDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
