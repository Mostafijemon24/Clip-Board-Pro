//
//  AccountManager.swift
//  Clip Board Pro
//

import AuthenticationServices
import Foundation
import Observation

/// Sign in with Apple and session state for iCloud clipboard sync.
@MainActor
@Observable
final class AccountManager {

    static let shared = AccountManager()

    private(set) var isSignedIn = false
    private(set) var userIdentifier: String?
    private(set) var userEmail: String?
    private(set) var userFullName: String?
    private(set) var lastErrorMessage: String?

    private init() {
        restoreSession()
    }

    var displayName: String {
        if let userFullName, !userFullName.isEmpty { return userFullName }
        if let userEmail, !userEmail.isEmpty { return userEmail }
        if isSignedIn { return "Apple ID" }
        return "Not signed in"
    }

    func handleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        lastErrorMessage = nil
        persistCredential(credential)

        if UserDefaults.standard.bool(forKey: UserPreferences.iCloudSyncEnabledKey) {
            Task { await CloudSyncService.shared.startSync() }
        }
    }

    func reportSignInError(_ error: Error) {
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            return
        }
        lastErrorMessage = error.localizedDescription
    }

    func signOut() {
        userIdentifier = nil
        userEmail = nil
        userFullName = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: UserPreferences.appleUserIdentifierKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.appleUserEmailKey)
        UserDefaults.standard.removeObject(forKey: UserPreferences.appleUserFullNameKey)
        UserDefaults.standard.set(false, forKey: UserPreferences.iCloudSyncEnabledKey)

        Task { await CloudSyncService.shared.stopSync() }
    }

    private func restoreSession() {
        guard let storedID = UserDefaults.standard.string(forKey: UserPreferences.appleUserIdentifierKey),
              !storedID.isEmpty else {
            return
        }

        userIdentifier = storedID
        userEmail = UserDefaults.standard.string(forKey: UserPreferences.appleUserEmailKey)
        userFullName = UserDefaults.standard.string(forKey: UserPreferences.appleUserFullNameKey)

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: storedID) { [weak self] state, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .authorized:
                    self.isSignedIn = true
                    if UserDefaults.standard.bool(forKey: UserPreferences.iCloudSyncEnabledKey) {
                        await CloudSyncService.shared.startSync()
                    }
                case .revoked, .notFound:
                    self.signOut()
                default:
                    break
                }
            }
        }
    }

    private func persistCredential(_ credential: ASAuthorizationAppleIDCredential) {
        let identifier = credential.user
        userIdentifier = identifier
        isSignedIn = true

        UserDefaults.standard.set(identifier, forKey: UserPreferences.appleUserIdentifierKey)

        if let email = credential.email {
            userEmail = email
            UserDefaults.standard.set(email, forKey: UserPreferences.appleUserEmailKey)
        }

        if let fullName = credential.fullName {
            let formatted = PersonNameComponentsFormatter().string(from: fullName)
            if !formatted.isEmpty {
                userFullName = formatted
                UserDefaults.standard.set(formatted, forKey: UserPreferences.appleUserFullNameKey)
            }
        }

        if UserDefaults.standard.object(forKey: UserPreferences.iCloudSyncEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: UserPreferences.iCloudSyncEnabledKey)
        }
    }
}
