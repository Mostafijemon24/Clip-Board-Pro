//
//  ClipboardImageThumbnail.swift
//  Clip Board Pro
//

import AppKit
import SwiftUI

/// Loads a downscaled image preview from disk without keeping full image data in memory.
struct ClipboardImageThumbnail: View {
    let path: String
    let size: CGFloat

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
        }
        .task(id: path) {
            thumbnail = await ImageFileStore.thumbnail(atPath: path)
        }
    }
}
