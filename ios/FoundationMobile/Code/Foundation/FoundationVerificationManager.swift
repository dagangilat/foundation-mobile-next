import Foundation
import FirebaseFunctions
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
    // No @discardableResult: the caller MUST check this. A dropped `false`
    // means a foreign proof's success silently falls through to the poller
    // it explicitly should not reach.
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

    /// Return to the starting state, unconditionally.
    ///
    /// `state` describes ONE Foundation member identity. When that identity
    /// stops being this device's - account deletion, sign-out - the state has
    /// to go with it, or the next person to use the device inherits it. The
    /// concrete leak this closes: a `.verified` left standing across an account
    /// deletion makes the app show the new user as a verified member having
    /// performed zero verification for them.
    ///
    /// Unlike `proofSheetDismissed()` this is not a release valve for one
    /// state; it is a full reset, so it deliberately has no guard.
    func reset() {
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
            // Re-checked every iteration, and again right before the write
            // below, rather than only at entry. This loop lives for up to two
            // minutes across `await`s, and `reset()` can land in any of them
            // (account deletion, sign-out). Without these checks the loop is
            // the one writer that could stamp a stale `.verified` - or a
            // `.failed("taking longer than expected")` - back over the `.idle`
            // a reset just established, for the NEXT user of the device.
            guard state == .polling else { return }
            do {
                let status = try await FunctionsService.shared.getL2VerificationStatus()
                // The server (functions/founders/passport.js) never returns
                // "verified" - that was this method's original, unverified
                // assumption. On success it returns "member_created" (first
                // member record) or "member_upgraded" (existing member
                // reaching l2), and "already_verified_l2" on a pre-checked
                // short-circuit. Checking only "verified" meant every real,
                // successful verification silently ran out the clock into
                // .failed below - found and fixed 2026-09-03 while porting
                // this poller's Android counterpart (Task C8), which caught
                // the mismatch against the real backend response shape.
                // "verified" itself is kept here too, defensively - matching
                // Android's TERMINAL_SUCCESS_STATUSES - so a future backend
                // rename to that value cannot silently strand this poller.
                if status.status == "member_created" || status.status == "member_upgraded"
                    || status.status == "already_verified_l2" || status.status == "verified" {
                    guard state == .polling else { return }
                    state = .verified(memberNumber: status.memberNumber)
                    return
                }
                // Any other status ("pending", "request_created", or an
                // unrecognized future value) is not terminal - keep polling.
            } catch {
                // A terminal rejection surfaces its own message immediately;
                // everything else (transient blips, unrecognized errors)
                // keeps retrying, matching the original behavior.
                if let message = FoundationVerificationManager.terminalRejectionMessage(for: error) {
                    guard state == .polling else { return }
                    state = .failed(message)
                    return
                }
                LoggerUtil.common.error("getL2VerificationStatus failed: \(error.localizedDescription, privacy: .public)")
            }
            try? await Task.sleep(for: pollInterval)
        }
        guard state == .polling else { return }
        state = .failed("The check is taking longer than expected. Please try again.")
    }

    /// Maps a `getL2VerificationStatus` failure to a terminal, user-facing
    /// message, or `nil` when it is a transient blip worth retrying.
    ///
    /// Pulled out of `pollUntilVerified`'s catch block so the classification
    /// is directly unit-testable: unlike Android's `FoundationVerificationManager`
    /// (which injects `terminalFailureMessage` and can stub the whole poll),
    /// this manager's `FunctionsService.shared` call has no DI seam, so this
    /// static function - not a live network round-trip - is what the tests
    /// exercise. It mirrors Android's `firebaseRejectionMessage` in shape and
    /// in which codes it classifies as terminal.
    ///
    /// Two distinct codes are terminal, both thrown by passport.js's
    /// `getL2VerificationStatus` / `upsertMemberWithLaneTx`:
    ///   - `.failedPrecondition`: `failed_verification` / `uniqueness_check_failed`
    ///     (the svc-side check).
    ///   - `.alreadyExists`: the lane-doc uniqueness guard rejecting a
    ///     duplicate passport - found 2026-09-03 (whole-plan review finding
    ///     I-2) to be the ONE that actually fires in practice, because the
    ///     svc-side check above "went blind" (see the passport.js comment).
    ///     Before this fix only `.failedPrecondition` was classified
    ///     terminal, so a real duplicate-passport rejection was retried 40x
    ///     over two minutes and reported as a generic timeout instead of the
    ///     server's real, specific rejection message
    ///     ("This passport is already linked to another member...", or the
    ///     erased-member variant).
    ///
    /// Either way the server's `HttpsError` message IS the real, user-facing
    /// rejection reason; the original code caught every error the same way
    /// and silently retried until timeout, discarding it in favor of a
    /// generic "taking longer than expected".
    nonisolated static func terminalRejectionMessage(for error: Error) -> String? {
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain else { return nil }
        guard ns.code == FunctionsErrorCode.failedPrecondition.rawValue
            || ns.code == FunctionsErrorCode.alreadyExists.rawValue else { return nil }
        return ns.localizedDescription
    }
}
