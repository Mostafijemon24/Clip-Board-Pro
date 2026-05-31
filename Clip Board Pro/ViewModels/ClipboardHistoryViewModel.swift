//
//  ClipboardHistoryViewModel.swift
//  Clip Board Pro
//

import Foundation
import Observation

@MainActor
@Observable
final class ClipboardHistoryViewModel {

    private(set) var items: [StoredClipboardItem] = []
    private(set) var isLoading = false
    private(set) var totalCount = 0

    private let repository: ClipboardRepository
    nonisolated(unsafe) private var observer: NSObjectProtocol?

    init(repository: ClipboardRepository = AppServices.shared.repository) {
        self.repository = repository
        observer = NotificationCenter.default.addObserver(
            forName: ClipboardRepository.historyDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reload()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let recent = repository.fetchRecent(limit: 200)
            async let count = repository.itemCount()
            items = try await recent
            totalCount = try await count
        } catch {
            items = []
            totalCount = 0
        }
    }

    private func reload() async {
        await load()
    }

    func filteredItems(matching query: String) -> [StoredClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }

        let normalized = trimmed.lowercased()
        return items.filter { item in
            item.previewText.lowercased().contains(normalized)
                || item.content.lowercased().contains(normalized)
                || item.kind.displayName.lowercased().contains(normalized)
                || (item.sourceBundleIdentifier?.lowercased().contains(normalized) ?? false)
        }
    }

    func paste(_ item: StoredClipboardItem) {
        ClipboardPasteCoordinator.shared.paste(item)
    }
}
