//
//  ClipboardRepositoryTests.swift
//  Clip Board ProTests
//

import Foundation
import Testing
@testable import Clip_Board_Pro

struct ClipboardRepositoryTests {

    private func makeTemporaryRepository() throws -> (ClipboardRepository, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipBoardProTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("test.db")
        let repository = try ClipboardRepository(databaseURL: databaseURL)
        return (repository, directory)
    }

    @Test func savesTextCapture() async throws {
        let (repository, tempDirectory) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let capture = ClipboardCapture(
            contentType: .text("Hello, Clip Board Pro!"),
            sourceBundleIdentifier: "com.apple.Safari"
        )

        let saved = try await repository.save(capture)
        #expect(saved.kind == .text)
        #expect(saved.content == "Hello, Clip Board Pro!")

        let items = try await repository.fetchRecent(limit: 10)
        #expect(items.count == 1)
        #expect(items.first?.id == saved.id)
    }

    @Test func savesLinkCapture() async throws {
        let (repository, tempDirectory) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let url = URL(string: "https://apple.com")!
        let capture = ClipboardCapture(
            contentType: .url(url),
            sourceBundleIdentifier: nil
        )

        let saved = try await repository.save(capture)
        #expect(saved.kind == .link)
        #expect(saved.content == "https://apple.com")
    }

    @Test func optimizeStorageDeletesOldEntries() async throws {
        let (repository, tempDirectory) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let oldDate = Calendar.current.date(byAdding: .day, value: -45, to: .now)!
        let oldCapture = ClipboardCapture(
            contentType: .text("expired"),
            capturedAt: oldDate,
            sourceBundleIdentifier: nil
        )

        _ = try await repository.save(oldCapture)
        _ = try await repository.save(
            ClipboardCapture(contentType: .text("fresh"), sourceBundleIdentifier: nil)
        )

        let result = try await repository.optimizeStorageOnStartup()
        #expect(result.deletedByAge >= 1)

        let remaining = try await repository.fetchRecent(limit: 10)
        #expect(remaining.count == 1)
        #expect(remaining.first?.content == "fresh")
    }

    @Test func optimizeStorageEnforcesDatabaseSizeLimit() async throws {
        let (repository, tempDirectory) = try makeTemporaryRepository()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let largeText = String(repeating: "A", count: 512_000)
        for index in 0..<220 {
            let capture = ClipboardCapture(
                contentType: .text("\(index)-\(largeText)"),
                sourceBundleIdentifier: nil
            )
            _ = try await repository.save(capture)
        }

        let result = try await repository.optimizeStorageOnStartup()
        #expect(result.deletedBySize >= 1)

        let count = try await repository.itemCount()
        #expect(count < 220)
    }
}
