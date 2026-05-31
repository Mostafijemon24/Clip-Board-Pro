//
//  OAuthPKCE.swift
//  Clip Board Pro
//

import CryptoKit
import Foundation

struct OAuthPKCE {
    let verifier: String
    let challenge: String

    static func make() -> OAuthPKCE {
        let verifier = randomURLSafeString(length: 64)
        let hash = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return OAuthPKCE(verifier: verifier, challenge: challenge)
    }

    private static func randomURLSafeString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
