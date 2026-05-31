//
//  GoogleAccountManager.swift
//  Clip Board Pro
//

import AppKit
import AuthenticationServices
import Foundation
import Observation

struct GoogleOAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

@MainActor
@Observable
final class GoogleAccountManager {

    static let shared = GoogleAccountManager()

    private(set) var isSignedIn = false
    private(set) var userEmail: String?
    private(set) var lastErrorMessage: String?

    private let keychainAccount = "googleOAuthTokens"
    private let emailAccount = "googleUserEmail"

    private init() {
        restoreSession()
    }

    var displayName: String {
        userEmail ?? (isSignedIn ? "Google account" : "Not signed in")
    }

    func signIn() {
        lastErrorMessage = nil

        guard GoogleAuthConfiguration.isConfigured, let clientID = GoogleAuthConfiguration.clientID else {
            lastErrorMessage = "Google sign-in is not configured in this build."
            return
        }

        let pkce = OAuthPKCE.make()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleAuthConfiguration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "\(GoogleAuthConfiguration.driveAppDataScope) \(GoogleAuthConfiguration.emailScope)"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components.url else {
            lastErrorMessage = "Failed to build Google sign-in URL."
            return
        }

        Task {
            await self.runSignIn(
                authURL: authURL,
                clientID: clientID,
                codeVerifier: pkce.verifier
            )
        }
    }

    private func runSignIn(authURL: URL, clientID: String, codeVerifier: String) async {
        let loopbackServer = OAuthLoopbackRedirectServer()

        async let redirectURL = loopbackServer.waitForRedirect(
            port: UInt16(GoogleAuthConfiguration.loopbackPort),
            expectedPath: "/oauth2callback"
        )

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: GoogleAuthConfiguration.callbackScheme
        ) { _, _ in }

        session.presentationContextProvider = WebAuthContextProvider.shared
        session.prefersEphemeralWebBrowserSession = false

        guard session.start() else {
            loopbackServer.stop()
            lastErrorMessage = "Could not open the Google sign-in window."
            return
        }

        do {
            let callbackURL = try await redirectURL
            loopbackServer.stop()

            guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value else {
                lastErrorMessage = "Google sign-in did not return an authorization code."
                return
            }
            await exchangeCode(code, clientID: clientID, codeVerifier: codeVerifier)
        } catch {
            loopbackServer.stop()
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            lastErrorMessage = error.localizedDescription
        }
    }

    func signOut(silent: Bool = false) {
        isSignedIn = false
        userEmail = nil
        try? KeychainStore.delete(account: keychainAccount)
        try? KeychainStore.delete(account: emailAccount)
        UserDefaults.standard.set(false, forKey: UserPreferences.cloudSyncEnabledKey)
        Task { await GoogleDriveSyncService.shared.stopSync() }
        if !silent {
            lastErrorMessage = nil
        }
    }

    func validAccessToken() async throws -> String {
        guard let tokens = loadTokens() else {
            throw GoogleAuthError.notSignedIn
        }
        if tokens.expiresAt > Date().addingTimeInterval(60) {
            return tokens.accessToken
        }
        guard let refresh = tokens.refreshToken else {
            throw GoogleAuthError.notSignedIn
        }
        let refreshed = try await refreshTokens(refreshToken: refresh)
        return refreshed.accessToken
    }

    private func exchangeCode(_ code: String, clientID: String, codeVerifier: String) async {
        do {
            let tokens = try await requestTokens(
                body: [
                    "code": code,
                    "client_id": clientID,
                    "redirect_uri": GoogleAuthConfiguration.redirectURI,
                    "grant_type": "authorization_code",
                    "code_verifier": codeVerifier,
                ]
            )
            try saveTokens(tokens)
            isSignedIn = true
            UserDefaults.standard.set(true, forKey: UserPreferences.cloudSyncEnabledKey)
            await GoogleDriveSyncService.shared.startSync()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshTokens(refreshToken: String) async throws -> GoogleOAuthTokens {
        guard let clientID = GoogleAuthConfiguration.clientID else {
            throw GoogleAuthError.notConfigured
        }
        let tokens = try await requestTokens(
            body: [
                "refresh_token": refreshToken,
                "client_id": clientID,
                "grant_type": "refresh_token",
            ]
        )
        let merged = GoogleOAuthTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken ?? refreshToken,
            expiresAt: tokens.expiresAt
        )
        try saveTokens(merged)
        return merged
    }

    private func requestTokens(body: [String: String]) async throws -> GoogleOAuthTokens {
        var fields = body
        if let secret = GoogleAuthConfiguration.clientSecret {
            fields["client_secret"] = secret
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Token request failed"
            throw GoogleAuthError.server(message)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["access_token"] as? String,
              let expiresIn = json?["expires_in"] as? Double else {
            throw GoogleAuthError.server("Invalid token response")
        }

        let refresh = json?["refresh_token"] as? String
        return GoogleOAuthTokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }

    private func restoreSession() {
        guard loadTokens() != nil else { return }
        isSignedIn = true
        userEmail = KeychainStore.load(account: emailAccount).flatMap { String(data: $0, encoding: .utf8) }
        if UserDefaults.standard.bool(forKey: UserPreferences.cloudSyncEnabledKey) {
            Task { await GoogleDriveSyncService.shared.startSync() }
        }
    }

    private func saveTokens(_ tokens: GoogleOAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try KeychainStore.save(data, account: keychainAccount)
    }

    private func loadTokens() -> GoogleOAuthTokens? {
        guard let data = KeychainStore.load(account: keychainAccount) else { return nil }
        return try? JSONDecoder().decode(GoogleOAuthTokens.self, from: data)
    }

    func storeEmail(_ email: String) {
        userEmail = email
        if let data = email.data(using: .utf8) {
            try? KeychainStore.save(data, account: emailAccount)
        }
    }

    func reportSignInError(_ error: Error) {
        if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
            return
        }
        lastErrorMessage = error.localizedDescription
    }

    enum GoogleAuthError: LocalizedError {
        case notConfigured
        case notSignedIn
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: "Google OAuth is not configured."
            case .notSignedIn: "Sign in with Google first."
            case .server(let message): message
            }
        }
    }
}
