//
//  ClipboardHistoryView.swift
//  Clip Board Pro
//

import SwiftUI

/// Native macOS dropdown-style clipboard history panel (translucent, rounded, searchable).
struct ClipboardHistoryView: View {
    @Bindable var viewModel: ClipboardHistoryViewModel
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredItems: [StoredClipboardItem] {
        viewModel.filteredItems(matching: searchText)
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                Divider()
                content
            }
        }
        .frame(width: 360, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary.opacity(0.6), lineWidth: 0.5)
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: MenuBarManager.popoverDidOpenNotification)) { _ in
            isSearchFocused = true
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Search clipboard…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.45))
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - List

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            loadingState
        } else if viewModel.items.isEmpty {
            emptyState(
                title: "No Clipboard Items",
                message: "Copy text, links, or images to see them here.",
                icon: "doc.on.clipboard"
            )
        } else if filteredItems.isEmpty {
            emptyState(
                title: "No Results",
                message: "Try a different search term.",
                icon: "magnifyingglass"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredItems) { item in
                        ClipboardHistoryRow(item: item) {
                            viewModel.paste(item)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.automatic)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Loading history…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(title: String, message: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ClipboardHistoryView(viewModel: ClipboardHistoryViewModel())
}
