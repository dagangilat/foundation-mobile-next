import XCTest
@testable import FoundationMobile

final class TrustTierLadderTests: XCTestCase {
    func testHighAchieved() {
        let r = TrustTierLadder.rungs(achieved: .high)
        XCTAssertEqual(r, [
            LadderRung(tier: .high,     status: .current),
            LadderRung(tier: .standard, status: .done),
            LadderRung(tier: .low,      status: .done),
        ])
    }

    func testStandardAchievedLocksHigh() {
        let r = TrustTierLadder.rungs(achieved: .standard)
        XCTAssertEqual(r, [
            LadderRung(tier: .high,     status: .locked),
            LadderRung(tier: .standard, status: .current),
            LadderRung(tier: .low,      status: .done),
        ])
    }

    func testLowAchievedLocksAbove() {
        let r = TrustTierLadder.rungs(achieved: .low)
        XCTAssertEqual(r, [
            LadderRung(tier: .high,     status: .locked),
            LadderRung(tier: .standard, status: .locked),
            LadderRung(tier: .low,      status: .current),
        ])
    }
}
