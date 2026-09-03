import Foundation
import SwiftUI

enum VerificationState: Equatable {
    case idle
    /// The passport is not registered on L2 yet - Rarimo's own scan flow must
    /// complete first, because a proof request needs a registration proof.
    case notRegistered
    case starting
    /// The proof sheet is up; Rarimo's ProofRequestView owns the UI from here.
    case awaitingProof
    case polling
    case verified(memberNumber: Int?)
    case failed(String)
}

/// Bridges Foundation's backend to Rarimo's proving flow, entirely in-process.
///
/// The flow:
///   1. `startL2Verification` (Foundation Cloud Function) creates a
///      verification request against this fork's own verificator-svc instance
///      and returns `getProofParamsUrl`.
///   2. That URL is handed straight to `ExternalRequestsManager`, which drives
///      Rarimo's existing `ProofRequestView` - the same code path an external
///      QR scan would take.
///   3. `ProofRequestView` posts the query proof to verificator-svc.
///   4. `getL2VerificationStatus` is polled until the member flips to l2.
///
/// No deep link is constructed or parsed, and no backend change is required.
/// See AD-2 in docs/superpowers/plans/2026-08-31-foundation-mobile-next-rarimo-fork-rebrand.md
@MainActor
final class FoundationVerificationManager: ObservableObject {
    static let shared = FoundationVerificationManager()

    @Published private(set) var state: VerificationState = .idle

    /// How long to keep polling before giving up. verificator-svc terminates
    /// the proof server-side, so the flip is usually seconds, not minutes.
    private let pollInterval: Duration = .seconds(3)
    private let pollLimit = 40

    func beginVerification() async {
        guard UserManager.shared.registerZkProof != nil else {
            state = .notRegistered
            return
        }
        state = .starting
        do {
            let result = try await FunctionsService.shared.startL2Verification()

            if result.status == "already_verified_l2" {
                state = .verified(memberNumber: nil)
                return
            }
            guard let raw = result.getProofParamsUrl, let url = URL(string: raw) else {
                state = .failed("The server didn't return proof parameters.")
                return
            }

            // AD-2: hand the params URL straight to Rarimo's proof flow.
            ExternalRequestsManager.shared.setProofRequest(proofParamsUrl: url)
            state = .awaitingProof
        } catch {
            LoggerUtil.common.error("startL2Verification failed: \(error.localizedDescription, privacy: .public)")
            state = .failed("We couldn't start the passport check. Please try again.")
        }
    }

    /// Call once ProofRequestView reports success.
    func pollUntilVerified() async {
        state = .polling
        for _ in 0 ..< pollLimit {
            do {
                let status = try await FunctionsService.shared.getL2VerificationStatus()
                if status.status == "verified" || status.status == "already_verified_l2" {
                    state = .verified(memberNumber: status.memberNumber)
                    return
                }
            } catch {
                LoggerUtil.common.error("getL2VerificationStatus failed: \(error.localizedDescription, privacy: .public)")
            }
            try? await Task.sleep(for: pollInterval)
        }
        state = .failed("The check is taking longer than expected. Please try again.")
    }
}
