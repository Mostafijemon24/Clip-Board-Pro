//
//  AppServices.swift
//  Clip Board Pro
//

import Foundation
import os

/// Central dependency container for long-lived app services.
@MainActor
final class AppServices {

    static let shared: AppServices = {
        do {
            return try AppServices()
        } catch {
            fatalError("Failed to initialize AppServices: \(error)")
        }
    }()

    let repository: ClipboardRepository
    let clipboardService: ClipboardService

    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "AppServices")

    init(repository: ClipboardRepository? = nil) throws {
        self.repository = try repository ?? ClipboardRepository()
        self.clipboardService = ClipboardService()
    }

    func start() {
        clipboardService.onCapture = { [weak self] capture in
            guard let self else { return }
            Task {
                do {
                    _ = try await self.repository.save(capture)
                } catch {
                    self.logger.error("Failed to save capture: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        clipboardService.onIgnoredSecureCopy = { [weak self] bundleID in
            self?.logger.debug("Secure copy blocked from \(bundleID, privacy: .public)")
        }

        Task {
            do {
                _ = try await repository.optimizeStorageOnStartup()
            } catch {
                logger.error("Storage optimization failed: \(error.localizedDescription, privacy: .public)")
            }

            clipboardService.startMonitoring()
            logger.info("App services started")

            await CloudAccountCoordinator.shared.startupSyncIfNeeded()
        }
    }

    func stop() {
        clipboardService.stopMonitoring()
    }
}
