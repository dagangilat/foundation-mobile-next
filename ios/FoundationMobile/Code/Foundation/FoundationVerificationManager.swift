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

    /// `state` is `private(set)` so that only the transitions below can move
    /// it. `VerificationManagerTests` still has to stand an instance up mid
    /// -flow (there is no way to reach `.awaitingProof` without a live
    /// `startL2Verification` round-trip), so entry state is an init parameter
    /// rather than a settable property - a seam that cannot be used to mutate
    /// an already-running flow, including `shared`.
    init(state: VerificationState = .idle) {
        self.state = state
    }

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

    /// Claim the success `ProofRequestView` just reported, **synchronously**.
    ///
    /// Call this as the first statement of `onSuccess`, on the main actor, and
    /// *before* the sheet is dismissed. Dismissal fires `proofSheetDismissed()`
    /// below, which resets a still-`.awaitingProof` state back to `.idle`;
    /// moving to `.polling` here - with no `await` in between - is the only
    /// thing that tells a real success apart from an abandoned sheet. Doing
    /// this flip inside a `Task` instead would let the dismissal win the race
    /// and throw away a legitimate verification.
    ///
    /// Returns `false`, and the caller must then *not* poll, when the proof
    /// that succeeded is not the one `beginVerification()` asked for - e.g. an
    /// externally scanned `foundationmobile://external?type=proof-request`.
    /// Such a request has nothing to do with this member's L2 status, and
    /// polling `getL2VerificationStatus` for it would burn ~2 minutes and end
    /// in a bogus `.failed`.
    @discardableResult
    func proofRequestSucceeded() -> Bool {
        guard state == .awaitingProof else { return false }
        state = .polling
        return true
    }

    /// The proof sheet closed. Every non-success close lands here with the
    /// state still `.awaitingProof` - Cancel, the sheet's X, swipe-to-dismiss,
    /// a proof-params load failure, a failed uniqueness check, any
    /// `generateProof` error - and without this reset `.awaitingProof` is
    /// terminal: `FoundationVerifyCardView.isBusy` would keep the Home verify
    /// card disabled and showing "Working…" for the rest of the process.
    ///
    /// A real success has already moved to `.polling` in
    /// `proofRequestSucceeded()`, so this is a no-op on that path.
    func proofSheetDismissed() {
        guard state == .awaitingProof else { return }
        state = .idle
    }

    /// The polling loop, started only after `proofRequestSucceeded()` returned
    /// true and therefore only from this manager's own flow.
    ///
    /// The guard is on `.polling`, not `.awaitingProof`: the transition out of
    /// `.awaitingProof` has to happen synchronously in `proofRequestSucceeded()`
    /// (see there), so by the time this loop runs the state is already
    /// `.polling`. Same discrimination, one hop later - it is defence in depth
    /// behind `proofRequestSucceeded()`, which is where an external request is
    /// actually turned away.
    func pollUntilVerified() async {
        guard state == .polling else { return }
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
