//
//  SecurityFilterTests.swift
//  Clip Board ProTests
//

import Testing
@testable import Clip_Board_Pro

struct SecurityFilterTests {

    @Test func secureBundleIDIsRecognized() {
        let filter = SecurityFilter(secureBundleIDs: ["com.agilebits.onepassword7"])
        #expect(filter.isSecureApplication(bundleIdentifier: "com.agilebits.onepassword7"))
        #expect(!filter.isSecureApplication(bundleIdentifier: "com.apple.Safari"))
    }

    @Test func defaultDenyListIncludesOnePassword() {
        #expect(SecurityFilter.defaultSecureBundleIDs.contains("com.agilebits.onepassword7"))
    }
}
