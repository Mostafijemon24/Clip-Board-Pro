//
//  OAuthWebAuthContext.swift
//  Clip Board Pro
//

import AppKit
import AuthenticationServices

final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        SettingsWindowController.shared.anchorWindow
    }
}
