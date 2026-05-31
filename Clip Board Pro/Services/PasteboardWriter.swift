//
//  PasteboardWriter.swift
//  Clip Board Pro
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum PasteboardWriter {

    enum Error: Swift.Error, LocalizedError {
        case emptyContent
        case imageFileMissing

        var errorDescription: String? {
            switch self {
            case .emptyContent: "Clipboard item has no pasteable content."
            case .imageFileMissing: "Image file no longer exists on disk."
            }
        }
    }

    /// Writes a stored item to the general pasteboard. Must run on the main thread.
    @MainActor
    static func write(_ item: StoredClipboardItem) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            guard !item.content.isEmpty else { throw Error.emptyContent }
            pasteboard.setString(item.content, forType: .string)

        case .link:
            guard !item.content.isEmpty else { throw Error.emptyContent }
            pasteboard.setString(item.content, forType: .string)
            if let url = URL(string: item.content) {
                pasteboard.writeObjects([url as NSURL])
            }

        case .image:
            let fileURL = URL(fileURLWithPath: item.content)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw Error.imageFileMissing
            }

            let ext = fileURL.pathExtension.lowercased()
            if let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) {
                switch ext {
                case "png":
                    pasteboard.setData(data, forType: .png)
                case "jpg", "jpeg":
                    pasteboard.setData(data, forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier))
                case "tiff", "tif":
                    pasteboard.setData(data, forType: .tiff)
                default:
                    if let image = NSImage(contentsOf: fileURL),
                       let tiff = image.tiffRepresentation {
                        pasteboard.setData(tiff, forType: .tiff)
                    }
                }
            }

            pasteboard.writeObjects([fileURL as NSURL])
        }
    }
}
