import XCTest
@testable import FoundationMobile

// Unit tests for Task 5 CaptureCoordinator wallet-document state extensions.
// These tests do NOT call real WalletDocumentReader / App Attest / NFC — they
// only exercise the coordinator's state-machine logic.
//
// Tier-2 (manual, Simulator): install "Mobile Document Reader (Developer)"
// profile on the device, run the full flow in the app, and confirm the
// readyForWalletDocument → scanningWalletDocument → walletDocumentReady →
// sealed sequence before adding CI integration.

@MainActor
final class CaptureCoordinatorTests: XCTestCase {

    // MARK: - afterPosesState wallet branch

    /// When the coordinator is pre-positioned into .readyForWalletDocument
    /// (the outcome afterPosesState returns for walletDocument profiles),
    /// calling scanWalletDocument transitions immediately to .scanningWalletDocument.
    /// This confirms the three new state cases are distinct and the guard passes.
    func testAfterPosesWalletProfileGoesToReadyForWalletDocument() {
        let coordinator = CaptureCoordinator()

        // Pre-position as if afterPosesState already ran for a wallet profile.
        coordinator._forTesting_setState(
            .readyForWalletDocument(framesCount: 3),
            framesCount: 3
        )

        // Verify the state was accepted.
        guard case .readyForWalletDocument(let n) = coordinator.state else {
            XCTFail("Expected .readyForWalletDocument, got \(coordinator.state)")
            return
        }
        XCTAssertEqual(n, 3)
    }

    // MARK: - scanWalletDocument transition

    /// scanWalletDocument() called from .readyForWalletDocument should
    /// immediately set state to .scanningWalletDocument (before the async
    /// WalletDocumentReader call completes). This is the synchronous leading
    /// edge of the method.
    func testScanWalletDocumentTransitionsToScanning() {
        let coordinator = CaptureCoordinator()

        // Pre-position into readyForWalletDocument.
        coordinator._forTesting_setState(
            .readyForWalletDocument(framesCount: 30),
            framesCount: 30
        )

        // Invoke — the synchronous part transitions to .scanningWalletDocument
        // before the async Task body starts.
        coordinator.scanWalletDocument(profile: .usaMDL)

        guard case .scanningWalletDocument(let n) = coordinator.state else {
            XCTFail("Expected .scanningWalletDocument immediately after scanWalletDocument(), got \(coordinator.state)")
            return
        }
        XCTAssertEqual(n, 30, "framesCount must be preserved through the scanning transition")
    }

    /// scanWalletDocument() called from a state other than .readyForWalletDocument
    /// must be a no-op (guard let early-return).
    func testScanWalletDocumentIgnoredFromWrongState() {
        let coordinator = CaptureCoordinator()
        // Leave coordinator in .idle (default).
        XCTAssertEqual(coordinator.state, .idle)

        coordinator.scanWalletDocument(profile: .usaMDL)

        // State must remain .idle.
        XCTAssertEqual(coordinator.state, .idle)
    }

    // MARK: - New state cases basic Equatable checks

    func testNewStateCasesAreEquatable() {
        let hash = Data(repeating: 0x01, count: 32)
        let walletResult = WalletDocumentReadResult(
            portraitHash: hash,
            portraitImage: nil,
            documentNumberRaw: "DL123",
            documentNumberMasked: maskDocumentNumber("DL123"),
            issuingState: "AZ",
            walletDocumentType: .mobileDriversLicense
        )

        XCTAssertEqual(
            CaptureCoordinator.State.readyForWalletDocument(framesCount: 5),
            CaptureCoordinator.State.readyForWalletDocument(framesCount: 5)
        )
        XCTAssertNotEqual(
            CaptureCoordinator.State.readyForWalletDocument(framesCount: 5),
            CaptureCoordinator.State.readyForWalletDocument(framesCount: 6)
        )
        XCTAssertEqual(
            CaptureCoordinator.State.scanningWalletDocument(framesCount: 2),
            CaptureCoordinator.State.scanningWalletDocument(framesCount: 2)
        )
        XCTAssertEqual(
            CaptureCoordinator.State.walletDocumentReady(framesCount: 3, walletResult: walletResult),
            CaptureCoordinator.State.walletDocumentReady(framesCount: 3, walletResult: walletResult)
        )
    }

    // MARK: - Unattested-tier attestation skip (2026-07-03 review, arch-mobile #1)

    func testShouldRequireAttestation_standardTierNoKey_isTrue() {
        XCTAssertTrue(
            CaptureCoordinator.shouldRequireAttestation(tier: .standard, hasKeychainKey: false)
        )
    }

    func testShouldRequireAttestation_standardTierWithKey_isFalse() {
        XCTAssertFalse(
            CaptureCoordinator.shouldRequireAttestation(tier: .standard, hasKeychainKey: true)
        )
    }

    func testShouldRequireAttestation_unattestedTierNoKey_isFalse() {
        // The bug: previously begin() had no branch for this and stranded
        // the user in .needsAttestation forever, since an unattested-tier
        // run never writes a Keychain key.
        XCTAssertFalse(
            CaptureCoordinator.shouldRequireAttestation(tier: .unattested, hasKeychainKey: false)
        )
    }

    // MARK: - Scan-budget race (2026-07-03 review, quality-mobile #1)

    func testCapturePoseResultStillApplies_trueWhenStillReadyForPose() {
        let pose = LivenessPose.active[0]
        XCTAssertTrue(
            CaptureCoordinator.capturePoseResultStillApplies(
                currentState: .readyForPose(pose: pose, captured: 1, total: 3)
            )
        )
    }

    func testCapturePoseResultStillApplies_falseAfterScanBudgetAlreadyAdvanced() {
        // Simulates handleScanBudgetExpiry having already moved the
        // coordinator on while a capturePose() Task was suspended.
        XCTAssertFalse(
            CaptureCoordinator.capturePoseResultStillApplies(
                currentState: .readyForPassport(framesCount: 2)
            )
        )
    }
}
