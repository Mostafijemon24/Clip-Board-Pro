//
//  AppCloudConfig.swift
//  Clip Board Pro
//

import Foundation

/// OAuth credentials from `OAuth-Info.plist` in the app bundle (publisher configures once).
enum AppCloudConfig {

    static let googleClientIDInfoKey = "GoogleOAuthClientID"
    static let googleClientSecretInfoKey = "GoogleOAuthClientSecret"
    static let oauthPlistResourceName = "OAuth-Info"

    static var googleClientID: String? {
        credential(forKey: googleClientIDInfoKey)
    }

    static var googleClientSecret: String? {
        credential(forKey: googleClientSecretInfoKey)
    }

    static var isGoogleConfigured: Bool { googleClientID != nil }

    private static let oauthPlistCache: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: oauthPlistResourceName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }
        return dict
    }()

    private static func credential(forKey key: String) -> String? {
        if let fromOAuthPlist = oauthPlistCache?[key] as? String,
           let validated = validatedCredential(from: fromOAuthPlist) {
            return validated
        }
        return validatedCredential(from: Bundle.main.object(forInfoDictionaryKey: key) as? String)
    }

    private static func validatedCredential(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.localizedCaseInsensitiveContains("YOUR_"),
              !trimmed.localizedCaseInsensitiveContains("REPLACE") else {
            return nil
        }
        return trimmed
    }
}
