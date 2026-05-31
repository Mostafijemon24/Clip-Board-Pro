//
//  ClipboardHistoryRow.swift
//  Clip Board Pro
//

import SwiftUI

struct ClipboardHistoryRow: View {
    let item: StoredClipboardItem
    let onSelect: () -> Void
    let onTogglePin: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leadingVisual
                .padding(.top, 1)

            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.previewText)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(item.kind == .image ? 1 : 2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        Text(item.kind.displayName)
                        Text("·")
                        Text(item.createdAt, format: .relative(presentation: .named))
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            if isHovered || item.isPinned {
                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.isPinned ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin" : "Pin (max \(ClipboardStorageConfiguration.maxPinnedItems))")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        switch item.kind {
        case .image:
            ClipboardImageThumbnail(path: item.content, size: 44)
        default:
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44, alignment: .center)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isHovered ? hoverFill : (item.isPinned ? pinnedFill : .clear))
    }

    private var hoverFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var pinnedFill: Color {
        colorScheme == .dark
            ? Color.orange.opacity(0.12)
            : Color.orange.opacity(0.08)
    }

    private var iconName: String {
        switch item.kind {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        }
    }
}
