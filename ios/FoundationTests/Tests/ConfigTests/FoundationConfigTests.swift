import XCTest
@testable import FoundationMobile

/// Guards the fork's build configuration against two regressions:
///  1. re-inheriting Rarimo's hosted endpoints (analytics/referrals would
///     flow into Rarimo's systems), and
///  2. re-inheriting Rarimo's checked-in private keys.
final class FoundationConfigTests: XCTestCase {
    private func configValue(_ key: String) -> String {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        // Xcode's Info.plist ${VAR} substitution embeds the xcconfig value's
        // literal quote characters (KEY="" resolves to the 2-char string `""`,
        // not a truly empty string). ConfigManager.normalizeInfoPlistString
        // works around the same quirk for the app; mirror it here so these
        // assertions compare actual config content, not raw plist text.
        return raw.starts(with: "\"") ? String(raw.dropFirst().dropLast()) : raw
    }

    func testAppsFlyerIsRemoved() {
        // Task B5 removed the AppsFlyer SDK outright, so the key must be absent
        // from the built Info.plist - not merely blank. Asserting on the blank
        // value would pass vacuously once the key is gone.
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "APPSFLYER_DEV_KEY"))
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "APPSFLYER_APP_ID"))
    }

    func testNoRarimoReferralCode() {
        XCTAssertEqual(configValue("DEFAULT_REFERRAL_CODE"), "")
    }

    func testFeedbackEmailIsFoundations() {
        XCTAssertFalse(configValue("FEEDBACK_EMAIL").contains("rarilabs"))
        XCTAssertFalse(configValue("FEEDBACK_EMAIL").isEmpty)
    }

    func testLegalUrlsAreFoundations() {
        XCTAssertFalse(configValue("TERMS_OF_USE_URL").contains("rarime.com"))
        XCTAssertFalse(configValue("PRIVACY_POLICY_URL").contains("rarime.com"))
    }

    func testNoInheritedPrivateKeys() {
        // Upstream committed real keys here. Blanked in the fork.
        XCTAssertEqual(configValue("LIGHT_SIGNATURE_PRIVATE_KEY"), "")
        XCTAssertEqual(configValue("JOIN_REWARDS_KEY"), "")
    }

    func testFoundationFunctionsRegionIsSet() {
        XCTAssertEqual(configValue("FOUNDATION_FUNCTIONS_REGION"), "us-east1")
    }

    func testAppSchemeIsFoundations() {
        XCTAssertEqual(configValue("FOUNDATION_APP_SCHEME"), "foundationmobile")
    }
}
