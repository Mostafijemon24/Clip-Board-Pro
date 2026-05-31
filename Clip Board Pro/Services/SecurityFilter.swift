//
//  SecurityFilter.swift
//  Clip Board Pro
//

import AppKit

/// Process-based filtering: ignores clipboard events originating from sensitive applications.
struct SecurityFilter: Sendable {

    /// Built-in bundle identifiers always excluded from capture.
    static let defaultSecureBundleIDs: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword8",
        "com.1password.1password",
        "com.agilebits.onepassword",
        "com.bitwarden.desktop",
        "com.apple.securityagent",
        "com.apple.keychainaccess",
        "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal",
        "com.dashlane.Dashlane",
        "org.keepassx.keepassxc",
        "com.apple.Passwords",
    ]

    private let overrideBundleIDs: Set<String>?

    init(secureBundleIDs: Set<String>? = nil) {
        self.overrideBundleIDs = secureBundleIDs
    }

    private var activeSecureBundleIDs: Set<String> {
        overrideBundleIDs ?? UserPreferences.resolvedSecureBundleIDs()
    }

    func frontmostApplicationBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func frontmostApplicationName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    func shouldIgnoreClipboardEvent() -> Bool {
        guard let bundleID = frontmostApplicationBundleIdentifier() else {
            return false
        }
        return activeSecureBundleIDs.contains(bundleID)
    }

    func isSecureApplication(bundleIdentifier: String) -> Bool {
        activeSecureBundleIDs.contains(bundleIdentifier)
    }
}
