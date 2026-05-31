//
//  KeychainStore.swift
//  Clip Board Pro
//

import Foundation
import Security

enum KeychainStore {

    static func save(_ data: Data, account: String) throws {
        try delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "ClipBoardPro",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "ClipBoardPro",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "ClipBoardPro",
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                "Keychain save failed (\(status))."
            }
        }
    }
}
