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

    /// Copies image bytes from a temporary or CloudKit asset URL into app storage.
    static func importImage(from sourceURL: URL) -> URL? {
        guard let data = try? Data(contentsOf: sourceURL), !data.isEmpty else { return nil }
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        return try? writeData(data, fileExtension: ext)
    }

    /// Returns a small preview suitable for list rows (loaded off the main thread).
    static func thumbnail(atPath path: String) async -> NSImage? {
        await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: path),
                  let source = NSImage(contentsOfFile: path) else {
                return nil
            }
            return downscaledImage(source, maxPixels: ClipboardStorageConfiguration.imageThumbnailMaxPixels)
        }.value
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

    private static func downscaledImage(_ image: NSImage, maxPixels: Int) -> NSImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(
            CGFloat(maxPixels) / size.width,
            CGFloat(maxPixels) / size.height,
            1
        )
        let target = NSSize(width: size.width * scale, height: size.height * scale)

        let output = NSImage(size: target)
        output.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        output.unlockFocus()
        return output
    }

    private static func writeData(_ data: Data, fileExtension: String) throws -> URL {
        let directory = ClipboardStorageConfiguration.imagesDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
