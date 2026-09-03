import XCTest
@testable import FoundationMobile

final class VerificationManagerTests: XCTestCase {
    func testUrlAllowlistAcceptsFoundationSchemeOnly() {
        let m = ExternalRequestsManager.shared

        XCTAssertTrue(m.isValidExternalUrl(
            URL(string: "foundationmobile://external?type=proof-request")!))
        // Rarimo's own hosts must no longer be honoured: we do not own their
        // AASA files, and a universal link to app.rarime.com opens RariMe.
        XCTAssertFalse(m.isValidExternalUrl(
            URL(string: "rarime://external?type=proof-request")!))
        XCTAssertFalse(m.isValidExternalUrl(
            URL(string: "https://app.rarime.com/external?type=proof-request")!))
    }

    func testProofRequestCanBeSetFromABareParamsUrl() {
        // AD-2: the fork never parses a deep link on the primary path - it
        // feeds getProofParamsUrl straight into the existing proof flow.
        let m = ExternalRequestsManager.shared
        m.resetRequest()
        let url = URL(string: "https://verificator.example.run.app/integrations/verificator-svc/light/v2/public/proof-params/abc")!
        m.setProofRequest(proofParamsUrl: url)

        guard case .proofRequest(let got, _)? = m.request else {
            return XCTFail("expected a proofRequest")
        }
        XCTAssertEqual(got, url)
        m.resetRequest()
    }

    // FoundationVerificationManager is @MainActor, so both its init and
    // `state` are main-actor-isolated; a nonisolated sync test body cannot
    // touch either. This is the only deviation from the brief's verbatim test.
    @MainActor
    func testStateStartsIdle() {
        XCTAssertEqual(FoundationVerificationManager().state, .idle)
    }
}
