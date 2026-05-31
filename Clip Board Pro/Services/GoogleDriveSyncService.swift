//
//  GoogleDriveSyncService.swift
//  Clip Board Pro
//

import Foundation
import os

@MainActor
@Observable
final class GoogleDriveSyncService {

    static let shared = GoogleDriveSyncService()

    private let logger = Logger(subsystem: "Mostafij-Emon.Clip-Board-Pro", category: "GoogleDriveSync")

    private(set) var isSyncing = false
    private(set) var statusMessage = "Sign in with Google to sync pinned clips across your devices."
    private(set) var lastSyncDate: Date?

    private init() {}

    var isEnabled: Bool {
        GoogleAccountManager.shared.isSignedIn
            && UserDefaults.standard.bool(forKey: UserPreferences.cloudSyncEnabledKey)
    }

    func startSync() async {
        guard isEnabled else {
            statusMessage = "Sign in with Google and enable sync."
            return
        }
        guard GoogleAuthConfiguration.isConfigured else {
            statusMessage = "Add Google OAuth Client ID in Account settings."
            return
        }

        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = "Syncing with Google…"
        defer { isSyncing = false }

        do {
            let token = try await GoogleAccountManager.shared.validAccessToken()
            if GoogleAccountManager.shared.userEmail == nil {
                await fetchUserEmail(accessToken: token)
            }

            let files = try await listClipFiles(accessToken: token)
            var imported = 0

            for file in files where file.name.hasSuffix(".json") {
                if let item = try await importClipFile(file, accessToken: token), item.isPinned {
                    try await AppServices.shared.repository.importFromCloud(item)
                    imported += 1
                }
            }

            let uploaded = await uploadAllPinned(accessToken: token)
            if imported > 0 || uploaded > 0 {
                statusMessage = "Synced \(imported) pinned from cloud, uploaded \(uploaded) pinned."
            } else {
                statusMessage = "Pinned clips are up to date."
            }
            lastSyncDate = Date()
        } catch {
            statusMessage = error.localizedDescription
            logger.error("Google sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopSync() async {
        statusMessage = "Google sync paused."
    }

    func upload(_ item: StoredClipboardItem) async {
        guard isEnabled, GoogleAuthConfiguration.isConfigured, item.isPinned else { return }

        do {
            let token = try await GoogleAccountManager.shared.validAccessToken()
            var imageFileID: String?
            if item.kind == .image, FileManager.default.fileExists(atPath: item.content) {
                imageFileID = try await uploadBinaryFile(
                    name: "clip-\(item.id.uuidString)-image.dat",
                    fileURL: URL(fileURLWithPath: item.content),
                    accessToken: token
                )
            }

            let payload = ClipboardSyncPayload(item: item, driveImageFileID: imageFileID)
            let data = try JSONEncoder().encode(payload)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("clip-\(item.id.uuidString).json")
            try data.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            _ = try await uploadBinaryFile(
                name: "clip-\(item.id.uuidString).json",
                fileURL: tempURL,
                mimeType: "application/json",
                accessToken: token
            )
            logger.debug("Uploaded clip \(item.id.uuidString, privacy: .public) to Google Drive")
        } catch {
            logger.error("Google upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Drive API

    private struct DriveFile: Decodable {
        let id: String
        let name: String
    }

    private struct DriveFileList: Decodable {
        let files: [DriveFile]
    }

    private func listClipFiles(accessToken: String) async throws -> [DriveFile] {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "spaces", value: "appDataFolder"),
            URLQueryItem(name: "fields", value: "files(id,name)"),
            URLQueryItem(name: "pageSize", value: "200"),
        ]

        let request = authorizedRequest(url: components.url!, accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)

        let list = try JSONDecoder().decode(DriveFileList.self, from: data)
        return list.files.filter { $0.name.hasPrefix("clip-") }
    }

    private func importClipFile(_ file: DriveFile, accessToken: String) async throws -> StoredClipboardItem? {
        let data = try await downloadFile(id: file.id, accessToken: accessToken)
        let payload = try JSONDecoder().decode(ClipboardSyncPayload.self, from: data)

        var localImagePath: String?
        if payload.kind == .image, let imageID = payload.driveImageFileID {
            let imageData = try await downloadFile(id: imageID, accessToken: accessToken)
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("\(payload.id.uuidString).img")
            try imageData.write(to: temp, options: .atomic)
            localImagePath = ImageFileStore.importImage(from: temp)?.path
            try? FileManager.default.removeItem(at: temp)
        }

        guard payload.isPinned else { return nil }
        return payload.asStoredItem(localImagePath: localImagePath)
    }

    private func uploadAllPinned(accessToken: String) async -> Int {
        guard let pinned = try? await AppServices.shared.repository.fetchAllPinned() else { return 0 }
        var count = 0
        for item in pinned {
            await upload(item)
            count += 1
        }
        return count
    }

    private func uploadBinaryFile(
        name: String,
        fileURL: URL,
        mimeType: String = "application/octet-stream",
        accessToken: String
    ) async throws -> String {
        let boundary = "clipboardpro-\(UUID().uuidString)"
        var body = Data()

        let metadata: [String: Any] = [
            "name": name,
            "parents": ["appDataFolder"],
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(
            url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!
        )
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? ""
    }

    private func downloadFile(id: String, accessToken: String) async throws -> Data {
        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(id)?alt=media")!
        let request = authorizedRequest(url: url, accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return data
    }

    private func fetchUserEmail(accessToken: String) async {
        do {
            let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
            let request = authorizedRequest(url: url, accessToken: accessToken)
            let (data, response) = try await URLSession.shared.data(for: request)
            try validateHTTP(response: response, data: data)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let email = json?["email"] as? String {
                GoogleAccountManager.shared.storeEmail(email)
            }
        } catch {
            logger.debug("Could not fetch Google profile email.")
        }
    }

    private func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Google API error"
            throw GoogleAccountManager.GoogleAuthError.server(message)
        }
    }
}
