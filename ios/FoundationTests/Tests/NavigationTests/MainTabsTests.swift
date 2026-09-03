import XCTest
@testable import FoundationMobile

final class MainTabsTests: XCTestCase {
    func testTabSetIsFoundations() {
        // Wallet is removed: Foundation's mobile app never holds a keypair.
        XCTAssertEqual(MainTabs.allCases, [.home, .identity, .scanQr, .profile])
    }

    func testNoWalletTab() {
        XCTAssertFalse(MainTabs.allCases.contains { "\($0)" == "wallet" })
    }

    func testHomeWidgetsAreFoundations() {
        // Earn / HiddenKeys / Likeness / Freedomtool widgets are all stripped.
        let names = HomeWidget.allCases.map { "\($0)".lowercased() }
        for banned in ["earn", "hiddenkeys", "likeness", "freedomtool"] {
            XCTAssertFalse(names.contains(banned), "widget \(banned) should be stripped")
        }
    }
}
