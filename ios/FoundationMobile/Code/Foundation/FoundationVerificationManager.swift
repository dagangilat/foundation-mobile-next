import Foundation
import FirebaseAuth
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
    /// The one production instance, and the only one that persists anything:
    /// it alone is handed the `UserDefaults`-backed cache (see
    /// `VerifiedMemberCache`). Every other instance - the unit tests' - gets no
    /// cache unless a test passes its own, so a test's `reset()` can never
    /// wipe the real device's "verified" answer and a test's `.verified` can
    /// never leak into it.
    static let shared = FoundationVerificationManager(cache: VerifiedMemberCache(defaults: .standard))

    @Published private(set) var state: VerificationState = .idle

    /// Where "this Firebase uid is a verified person" is kept between
    /// launches. `nil` means no persistence at all (see `shared`).
    private let cache: VerifiedMemberCache?

    /// The Firebase uid that is signed in right now. Injected only so tests
    /// can run without a live Firebase session; production reads the SDK's
    /// `currentUser` directly rather than `AuthService.uid`, which trails the
    /// SDK by one main-actor hop after every auth change (see AuthService's
    /// listener) - exactly the window a cross-account check must not trust.
    private let currentUid: @MainActor () -> String?

    /// `getMyFounderProfile`, injected for the same reason as `currentUid`.
    private let fetchProfile: () async throws -> FounderProfileResult

    /// `true` while `state` is a `.verified` that came out of the local cache
    /// and the server has not yet confirmed THIS launch. It is the one
    /// `.verified` that `refreshFromServer()` may still take back: a
    /// `.verified` reached through this session's own flow (a finished poll,
    /// the `already_verified_l2` short-circuit) or already confirmed by a
    /// refresh is final, as it always was. Without this distinction a cached
    /// answer could only ever be cleared by signing out: the member deleted
    /// on the web, or a revoked passport, would keep showing as verified on
    /// this phone forever, because the refresh that should notice it would
    /// see `.verified` and stand down.
    private var isVerifiedUnconfirmed = false

    /// Bumped by every `reset()`. `refreshFromServer()` captures it before its
    /// network await and refuses to write if it moved: a sign-out (or account
    /// deletion) that lands during the await must win, even if the SAME uid
    /// happens to sign back in before the answer arrives - a uid comparison
    /// alone cannot see that, a generation counter can.
    private var resetGeneration = 0

    /// One refresh at a time. Home's `onAppear` and the scene becoming
    /// `.active` routinely fire together on a cold launch; the second call
    /// would only repeat the first's round trip.
    private var isRefreshing = false

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
    ///
    /// `cache`, `currentUid` and `fetchProfile` are the same kind of seam, for
    /// `refreshFromServer()`: a test injects a throwaway `UserDefaults` suite,
    /// a fixed uid and a canned profile instead of Firebase. The defaults are
    /// production's. With a cache, an `.idle` entry state is immediately
    /// upgraded from it when it belongs to the signed-in uid - that is what
    /// makes Home say "verified" on the very first frame of a cold launch,
    /// offline included, instead of flashing "Finish verification" until a
    /// round trip lands.
    init(
        state: VerificationState = .idle,
        cache: VerifiedMemberCache? = nil,
        currentUid: @escaping @MainActor () -> String? = { Auth.auth().currentUser?.uid },
        fetchProfile: @escaping () async throws -> FounderProfileResult = {
            try await FunctionsService.shared.getMyFounderProfile()
        }
    ) {
        self.state = state
        self.cache = cache
        self.currentUid = currentUid
        self.fetchProfile = fetchProfile
        restoreFromCacheIfIdle()
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
                markVerified(memberNumber: result.memberNumber, notify: true)
                return
            }
            guard let raw = result.getProofParamsUrl, let url = URL(string: raw) else {
                fail("The server didn't return proof parameters.")
                return
            }

            // AD-2: hand the params URL straight to Rarimo's proof flow.
            ExternalRequestsManager.shared.setProofRequest(proofParamsUrl: url)
            state = .awaitingProof
        } catch {
            LoggerUtil.common.error("startL2Verification failed: \(error.localizedDescription, privacy: .public)")
            fail("We couldn't start the passport check. Please try again.")
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
    /// a proof-params load failure, any `generateProof` error - and without
    /// this reset `.awaitingProof` is terminal:
    /// `FoundationVerifyCardView.isBusy` would keep the Home verify
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
    ///
    /// The persisted "verified" answer goes with it, for the same reason: both
    /// callers (`ProfileView.signOutOfFoundation`, shared by Sign Out and
    /// Delete Account) mean "this uid is no longer this device's". The cache is
    /// uid-keyed and would never be RESTORED for another uid anyway (see
    /// `restoreFromCacheIfIdle()`), but a departed member's uid and member
    /// number have no business staying on disk either. Bumping
    /// `resetGeneration` turns away any `refreshFromServer()` still awaiting
    /// its answer.
    func reset() {
        state = .idle
        isVerifiedUnconfirmed = false
        resetGeneration &+= 1
        cache?.clear()
    }

    /// Ask the backend, without side effects, whether this member is already
    /// verified, and let Home say so.
    ///
    /// Why this exists: `state` is in memory only, and `.verified` used to be
    /// reachable only through a live flow (a finished poll, or the
    /// `already_verified_l2` short-circuit behind "Finish verification"). So
    /// every cold launch started at `.idle`, and a member who finished
    /// verifying last night found Home back at "Passport checked - One last
    /// step: share a private proof with Foundation to finish verifying" the
    /// next morning, and was asked to do it all again. Called from HomeView on
    /// appear and whenever the scene becomes active.
    ///
    /// What it may touch, and what it may not:
    ///   - `.idle`, `.failed` and a cache-restored `.verified` only. `.failed`
    ///     is terminal - nothing is running behind it - so a server that says
    ///     "verified" simply outranks a try that didn't finish.
    ///   - Never `.starting`/`.awaitingProof`/`.polling`: those belong to a
    ///     flow in progress, whose own ending writes the state. Nor
    ///     `.notRegistered`, which only a tap produces and only a tap clears.
    ///   - Verified: `.verified(memberNumber)`, cached, WITHOUT the "You're
    ///     verified" bell entry - the member got that one when it actually
    ///     happened; re-posting it on every launch is noise.
    ///   - Not verified (including `not_a_member`): the cache is dropped, and a
    ///     cache-restored `.verified` goes back to `.idle`. `.idle`/`.failed`
    ///     stay as they are.
    ///   - Any error (offline, a 5xx, Founders disabled): silent, state kept.
    ///     This is a background read; the card's own button is where errors
    ///     are reported.
    ///
    /// Uses `getMyFounderProfile`, never `startL2Verification`: the latter
    /// answers the same question for an l3 member, but for anyone else it
    /// CREATES a verification request and resets the verifier row - a side
    /// effect no launch or foreground may have.
    func refreshFromServer() async {
        // Cheap and synchronous first: a cold launch where Firebase's keychain
        // restore had not landed by `shared`'s init gets its cached answer here,
        // on Home's first `onAppear`, before any network.
        restoreFromCacheIfIdle()

        guard !isRefreshing, isRefreshable, let uid = currentUid() else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let generation = resetGeneration

        let profile: FounderProfileResult
        do {
            profile = try await fetchProfile()
        } catch {
            LoggerUtil.common.info("getMyFounderProfile failed; keeping the current state: \(error.localizedDescription, privacy: .public)")
            return
        }

        // Everything may have moved during the await: a reset() (sign-out,
        // account deletion - caught by the generation even when the same uid
        // signed straight back in), a different member signed in (the uid), or
        // a flow the member started by tapping Finish (the state). Any of these
        // makes this answer stale, so it is dropped - not merged.
        guard generation == resetGeneration, currentUid() == uid, isRefreshable else { return }

        if profile.isVerifiedPerson {
            markVerified(memberNumber: profile.memberNumber, notify: false)
        } else {
            cache?.clear()
            if case .verified = state, isVerifiedUnconfirmed {
                state = .idle
                isVerifiedUnconfirmed = false
            }
        }
    }

    /// The states `refreshFromServer()` may overwrite; see there.
    private var isRefreshable: Bool {
        switch state {
        case .idle, .failed: return true
        case .verified: return isVerifiedUnconfirmed
        case .notRegistered, .starting, .awaitingProof, .polling: return false
        }
    }

    /// `.idle` -> `.verified` from the local cache, but only when the cached
    /// entry names the uid signed in RIGHT NOW. A mismatch (another member on
    /// this device, or no one signed in) restores nothing; the entry is left
    /// alone, because only a server answer or `reset()` may drop it.
    private func restoreFromCacheIfIdle() {
        guard state == .idle, let cache, let entry = cache.read(),
              let uid = currentUid(), entry.uid == uid else { return }
        state = .verified(memberNumber: entry.memberNumber)
        isVerifiedUnconfirmed = true
    }

    /// Every transition INTO `.verified` goes through here, so every one of
    /// them is cached for the next launch. `notify` is true only for the two
    /// live-flow endings; `refreshFromServer()` passes false, which is what
    /// keeps the bell's "You're verified" to one entry per verification rather
    /// than one per app launch.
    private func markVerified(memberNumber: Int?, notify: Bool) {
        state = .verified(memberNumber: memberNumber)
        isVerifiedUnconfirmed = false
        if let uid = currentUid() {
            cache?.write(VerifiedMemberCache.Entry(uid: uid, memberNumber: memberNumber))
        }
        if notify { notifyVerified() }
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
                if FoundationVerificationManager.isTerminalSuccess(status.status) {
                    guard state == .polling else { return }
                    markVerified(memberNumber: status.memberNumber, notify: true)
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
                    fail(message)
                    return
                }
                LoggerUtil.common.error("getL2VerificationStatus failed: \(error.localizedDescription, privacy: .public)")
            }
            try? await Task.sleep(for: pollInterval)
        }
        guard state == .polling else { return }
        fail("The check is taking longer than expected. Please try again.")
    }

    /// A terminal failure: the Home card says the last try didn't finish,
    /// and the reason goes behind Home's bell with Try again.
    private func fail(_ message: String) {
        state = .failed(message)
        AppNotificationStore.shared.postVerificationFailure(reason: message, retry: .finishVerification)
    }

    private func notifyVerified() {
        AppNotificationStore.shared.postSuccess(
            title: String(localized: "You're verified"),
            message: String(localized: "Foundation confirmed you're a real, unique person.")
        )
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
    ///   - `.failedPrecondition`: `failed_verification`, and the svc's
    ///     `uniqueness_check_failed` when the backend confirms it (reasons
    ///     `identity_reissued` / `uniqueness_unconfirmed`, each with its own
    ///     message). ProofRequestView no longer stops on that svc status
    ///     itself; it hands off here so the backend makes the call.
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

    /// Whether a `getL2VerificationStatus` status string is terminal-success.
    ///
    /// Pulled out of `pollUntilVerified`'s loop for the same reason as
    /// `terminalRejectionMessage(for:)` above: no DI seam on `FunctionsService
    /// .shared` means this pure function, not a live round-trip, is what a
    /// unit test can actually exercise. Added 2026-09-04 (scoped re-review
    /// finding N-2 on the whole-plan review): Android pins its equivalent set
    /// (`TERMINAL_SUCCESS_STATUSES`) with 8 test cases; this exact string set
    /// was the one that was actually wrong before the 2026-09-03 fix (see
    /// `pollUntilVerified`'s comment above), so it was the platform most in
    /// need of a pin, not least.
    nonisolated static func isTerminalSuccess(_ status: String) -> Bool {
        status == "member_created" || status == "member_upgraded"
            || status == "already_verified_l2" || status == "verified"
    }
}

/// "This Firebase uid is a verified person" (and its member number), kept in
/// `UserDefaults` so Home can say so on a cold launch before - or without -
/// a network round trip.
///
/// Holds a uid and an optional Int; nothing about the passport. Keyed by uid
/// rather than trusted blindly: `FoundationVerificationManager` restores an
/// entry only for the uid signed in at that moment, and `reset()` (sign-out,
/// account deletion) deletes it. It is a display hint, never an authority -
/// every Foundation callable re-checks the member server-side, and
/// `refreshFromServer()` drops the entry the first time the server disagrees.
struct VerifiedMemberCache {
    struct Entry: Equatable {
        let uid: String
        let memberNumber: Int?
    }

    let defaults: UserDefaults
    var key = "foundation.verifiedMember"

    func read() -> Entry? {
        guard let dict = defaults.dictionary(forKey: key),
              let uid = dict["uid"] as? String, !uid.isEmpty else { return nil }
        return Entry(uid: uid, memberNumber: dict["memberNumber"] as? Int)
    }

    func write(_ entry: Entry) {
        var dict: [String: Any] = ["uid": entry.uid]
        if let memberNumber = entry.memberNumber { dict["memberNumber"] = memberNumber }
        defaults.set(dict, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
