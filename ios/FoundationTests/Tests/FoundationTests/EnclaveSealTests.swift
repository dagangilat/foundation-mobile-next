import XCTest
@testable import FoundationMobile

final class EnclaveSealTests: XCTestCase {
    private func artifact(_ kind: ProofArtifact.Kind, at ms: Int64) -> ProofArtifact {
        ProofArtifact(
            kind: kind,
            producedAtMs: ms,
            payloadHashHex: String(repeating: "a", count: 64),
            signatureBase64: "c2ln"
        )
    }

    func testCanonicalBytesFormatIsFrozen() {
        let a = artifact(.appAttest, at: 1_700_000_000_000)
        let expected = "appAttest:1700000000000:\(String(repeating: "a", count: 64)):c2ln"
        XCTAssertEqual(String(data: a.canonicalBytes(), encoding: .utf8), expected)
    }

    func testSealBindsUidAndIsOrderIndependent() {
        let one = EnclaveSeal.seal(uid: "u1", artifacts: [
            artifact(.appAttest, at: 1), artifact(.nfcZk, at: 2),
        ])
        let two = EnclaveSeal.seal(uid: "u1", artifacts: [
            artifact(.nfcZk, at: 2), artifact(.appAttest, at: 1),
        ])
        XCTAssertEqual(one.commitmentHashHex, two.commitmentHashHex)

        let other = EnclaveSeal.seal(uid: "u2", artifacts: [
            artifact(.appAttest, at: 1), artifact(.nfcZk, at: 2),
        ])
        XCTAssertNotEqual(one.commitmentHashHex, other.commitmentHashHex,
                          "a commitment must not be replayable under another uid")
    }

    func testCommitmentHashIs64LowercaseHex() {
        let c = EnclaveSeal.seal(uid: "u1", artifacts: [artifact(.appAttest, at: 1)])
        XCTAssertEqual(c.commitmentHashHex.count, 64)
        XCTAssertEqual(c.commitmentHashHex, c.commitmentHashHex.lowercased())
    }

    func testOnlyServerAllowedKindsExist() {
        // Server: ALLOWED_ARTIFACT_KINDS = appAttest, liveness, nfcZk,
        // antiSpoof, faceMatch. The fork emits a subset.
        let allowed: Set<String> = ["appAttest", "liveness", "nfcZk", "antiSpoof", "faceMatch"]
        for k in ProofArtifact.Kind.allCases {
            XCTAssertTrue(allowed.contains(k.rawValue), "\(k.rawValue) is not server-allowed")
        }
    }

    /// Cross-platform golden vector. Task C8's Kotlin EnclaveSealTest asserts
    /// this exact constant, which is how the two implementations are pinned to
    /// each other. Independently verifiable:
    ///   python3 -c "import hashlib;a='appAttest:1000:'+'a'*64+':c2ln';
    ///   print(hashlib.sha256(b'uid:golden-uid\n'+a.encode()+b'\n').hexdigest())"
    func testGoldenVector() {
        let c = EnclaveSeal.seal(uid: "golden-uid", artifacts: [artifact(.appAttest, at: 1000)])
        XCTAssertEqual(
            c.commitmentHashHex,
            "498af846df74d0e173e1cee4c09cec1d932c14e65fc9e88d4862943a211922d7"
        )
    }
}
