//
//  GoogleAuthConfiguration.swift
//  Clip Board Pro
//

import Foundation

enum GoogleAuthConfiguration {
    static let loopbackPort = 8765

    static var redirectURI: String {
        "http://127.0.0.1:\(loopbackPort)/oauth2callback"
    }

    static let callbackScheme = "http"
    static let driveAppDataScope = "https://www.googleapis.com/auth/drive.appdata"
    static let emailScope = "email"

    static var clientID: String? { AppCloudConfig.googleClientID }
    static var clientSecret: String? { AppCloudConfig.googleClientSecret }
    static var isConfigured: Bool { AppCloudConfig.isGoogleConfigured }

    static var consoleRedirectURIHint: String { redirectURI }
}
