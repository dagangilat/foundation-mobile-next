import Foundation
import FirebaseAuth
import FirebaseFunctions

struct AttestationNonce: Decodable, Sendable {
    let nonce: String
    let expiresAtMs: Int64
}

struct RecordAttestationRequest: Encodable, Sendable {
    let nonce: String
    let attestation: AttestationPayload

    struct AttestationPayload: Encodable, Sendable {
        let platform: String
        let keyId: String
        let attestation: String
    }
}

/// `recordMobileAttestation`'s real reply shape. The server (Foundation's
/// `functions/index.js` → `@plantagoai/attestation`'s `recordAttestation`)
/// answers `{ accepted, platform, credentialId }`.
///
/// The field this used to carry — `commitment` — belonged to the Phase 7
/// enclave-seal flow that Task B9 removed along with `anchorCommitment`; the
/// live callable has never returned it. `platform`/`credentialId` are optional
/// so a server that answers with only `accepted` still decodes.
struct RecordAttestationResult: Decodable, Sendable {
    let accepted: Bool
    let platform: String?
    let credentialId: String?
}

// OTP sign-in (iOS-only path). See requestSignInCode / verifySignInCode
// in Foundation's functions/index.js for the threat model. Replaces
// the email-link flow on iOS because Gmail iOS bypasses Universal Links.
struct RequestSignInCodeResult: Decodable, Sendable {
    let status: String
    let sent: Bool
    let reason: String?
    let expiresInSeconds: Int?
}

struct VerifySignInCodeResult: Decodable, Sendable {
    let customToken: String
    let uid: String
    let issuedAtMs: Int64
    let expiresInSeconds: Int
}

struct StartL2VerificationResult: Decodable, Sendable {
    let status: String
    /// The universal link Foundation's backend builds for RariMe. The fork
    /// deliberately IGNORES this and uses getProofParamsUrl directly - see
    /// AD-2 in the fork plan. Decoded only so the shape stays honest.
    let deepLink: String?
    let getProofParamsUrl: String?
}

struct L2VerificationStatusResult: Decodable, Sendable {
    let status: String
    let memberNumber: Int?
}

/// `deleteMyAccount`'s real reply shape.
///
/// The callable (`foundation-next/functions/account-deletion.js`) returns
/// whatever `deleteAccount(uid, foundationDataMap, …)` from `@plantagoai/auth`
/// returns, i.e. that package's `DeletionResult`:
/// `{ userId, deletedDocs, anonymizedDocs, retainedDocs, authDeleted,
///    collections, external, completedAt, dryRun }`.
///
/// Two of those are deliberately NOT modelled here. `collections` is a
/// per-collection `Record<string, { mode, count }>` and `external` a list of
/// provider names - server-side bookkeeping this client has no use for, and
/// modelling them would only create a shape to drift out of sync with.
///
/// Everything that IS modelled is optional, and that is a correctness
/// decision rather than defensiveness: by the time this struct is built the
/// server has already performed an irreversible hard delete, so a decode that
/// throws on an added/renamed/missing field would report a *successful*
/// deletion as a failure and strand the member signed in to an account that no
/// longer exists.
struct DeleteAccountResult: Decodable, Sendable {
    var userId: String?
    var deletedDocs: Int?
    var anonymizedDocs: Int?
    var retainedDocs: Int?
    /// Informational only - never gate on it. `deleteAccount()` swallows
    /// "user not found" from `auth.deleteUser` and reports `false`, which is
    /// exactly what a re-run against an already-deleted account produces.
    var authDeleted: Bool?
    var completedAt: String?
    /// The live callable never passes `dryRun`, so this is `false` or absent in
    /// practice. It is read anyway because `dryRun: true` is the one reply that
    /// means "the server reported success and deleted nothing" - the single
    /// case where a 200 must not unlock the local erase.
    var dryRun: Bool?
}

enum FunctionsError: Error {
    case malformedResponse
    /// The server answered, but said it did not actually delete anything.
    case accountDeletionNotPerformed
}

actor FunctionsService {
    static let shared = FunctionsService()

    /// Foundation's callables are region-pinned (see FOUNDATION_FUNCTIONS_REGION
    /// in the per-configuration xcconfigs). Firebase's default region is
    /// us-central1, so passing the region explicitly is required or the SDK
    /// routes to a nonexistent function URL.
    ///
    /// The xcconfig values in this project are written quoted
    /// (`FOUNDATION_FUNCTIONS_REGION="us-east1"`) and Xcode carries the quotes
    /// verbatim into Info.plist, so the raw dictionary value is `"us-east1"`
    /// INCLUDING the quote characters. ConfigManager strips them with its own
    /// private `normalizeInfoPlistString`; this does the same, because a region
    /// of `"us-east1"` would silently produce an unreachable callable host.
    private var functions: Functions {
        let raw = Bundle.main.object(forInfoDictionaryKey: "FOUNDATION_FUNCTIONS_REGION") as? String
        let region = Self.unquote(raw) ?? "us-east1"
        return Functions.functions(region: region)
    }

    private static func unquote(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2
            ? String(value.dropFirst().dropLast())
            : value
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Last time we forced a Firebase ID token refresh. Mutating callables
    /// gate on this to avoid sending a stale cached token to the server.
    /// The Firebase iOS SDK's default `getIDToken(forcingRefresh: false)`
    /// will return a cached token until its 1-h TTL expires — even after
    /// a sign-out + re-sign-in — which produced the "Session is stale"
    /// failures we kept hitting in testing.
    private var lastIDTokenRefresh: Date?

    /// Stale-window for the cached ID token. Five minutes is short enough
    /// that the post-sign-in race ("user signed in 2s ago, ID token cache
    /// hasn't flushed yet") is always covered, while leaving rapid-fire
    /// successive callables in a single user gesture (≤300 ms apart)
    /// using the just-refreshed token without an extra round-trip.
    private static let idTokenStaleWindow: TimeInterval = 5 * 60

    /// Force a fresh Firebase ID token if the last forced refresh was
    /// more than `idTokenStaleWindow` ago. Cost: one auth round-trip
    /// (~200 ms) to Firebase Identity Toolkit. Called by every mutating
    /// callable wrapper below; eliminates the class of failures where
    /// the SDK's cached token is a generation behind the live signed-in
    /// user (post sign-out → sign-in, post token revocation, etc.).
    private func refreshIDTokenIfStale() async throws {
        let now = Date()
        if let last = lastIDTokenRefresh,
           now.timeIntervalSince(last) < Self.idTokenStaleWindow {
            return
        }
        guard let user = await MainActor.run(body: { Auth.auth().currentUser }) else {
            // Not signed in — let the callable's own requireAuth path
            // produce the right "unauthenticated" error instead of
            // synthesising one here.
            return
        }
        _ = try await user.getIDToken(forcingRefresh: true)
        lastIDTokenRefresh = now
    }

    func issueAttestationNonce() async throws -> AttestationNonce {
        // Read-only setup callable; safe to use cached token.
        let result = try await functions.httpsCallable("issueAttestationNonce").call([:])
        return try decode(AttestationNonce.self, from: result.data)
    }

    func recordMobileAttestation(_ req: RecordAttestationRequest) async throws -> RecordAttestationResult {
        try await refreshIDTokenIfStale()
        let payload = try encodeToDict(req)
        let result = try await functions.httpsCallable("recordMobileAttestation").call(payload)
        return try decode(RecordAttestationResult.self, from: result.data)
    }

    /// Ask the server to email a 6-digit sign-in code.
    func requestSignInCode(email: String) async throws -> RequestSignInCodeResult {
        // Pre-sign-in callable — no auth context to refresh.
        let result = try await functions.httpsCallable("requestSignInCode").call([
            "email": email,
        ])
        return try decode(RequestSignInCodeResult.self, from: result.data)
    }

    /// Exchange a 6-digit code for a Firebase custom token. The caller
    /// (AuthService) immediately passes the token to
    /// `Auth.signIn(withCustomToken:)` and discards it.
    func verifySignInCode(email: String, code: String) async throws -> VerifySignInCodeResult {
        let result = try await functions.httpsCallable("verifySignInCode").call([
            "email": email,
            "code": code,
        ])
        return try decode(VerifySignInCodeResult.self, from: result.data)
    }

    func startL2Verification() async throws -> StartL2VerificationResult {
        try await refreshIDTokenIfStale()
        let result = try await functions.httpsCallable("startL2Verification").call([:])
        return try decode(StartL2VerificationResult.self, from: result.data)
    }

    /// Irreversible, server-side hard delete of this member's Foundation
    /// account. No undo, by design (the callable's own comment cites GDPR
    /// Art. 17); on-chain accounts created by the member's custodial Solana
    /// keypair become orphaned, which is an accepted consequence of erasure
    /// rather than a bug.
    ///
    /// The callable is `requireAuth`-gated, so this only ever works while the
    /// Firebase session is live. Callers MUST invoke it BEFORE signing out.
    ///
    /// Throws only when the deletion genuinely did not happen: a transport /
    /// auth / server error out of `.call()`, or a `dryRun` reply. A malformed
    /// or unexpected response body does NOT throw - see `DeleteAccountResult`.
    func deleteMyAccount() async throws -> DeleteAccountResult {
        try await refreshIDTokenIfStale()
        let result = try await functions.httpsCallable("deleteMyAccount").call([:])

        // Past this line the server has already run the deletion, so nothing
        // about the *shape* of its answer may be turned into a failure.
        // `DeleteAccountResult`'s fields are all optional, so this fallback
        // only fires for a reply that isn't a JSON object at all.
        let decoded = (try? decode(DeleteAccountResult.self, from: result.data)) ?? DeleteAccountResult()

        // The one exception, and the reason the field is decoded: the server
        // explicitly reporting that it deleted nothing.
        if decoded.dryRun == true {
            throw FunctionsError.accountDeletionNotPerformed
        }

        return decoded
    }

    func getL2VerificationStatus() async throws -> L2VerificationStatusResult {
        let result = try await functions.httpsCallable("getL2VerificationStatus").call([:])
        return try decode(L2VerificationStatusResult.self, from: result.data)
    }

    /// Force the next mutating callable to refresh the ID token, regardless
    /// of staleness window. Call from AuthService.signOut so the very first
    /// callable after a fresh sign-in skips the cache-warming window.
    func invalidateIDTokenCache() {
        lastIDTokenRefresh = nil
    }

    /// Mark the ID token as freshly refreshed without actually forcing a
    /// network round-trip. Use this right after `Auth.signIn(withCustomToken:)`
    /// succeeds — that call produces a fresh ID token as a side effect, so a
    /// subsequent force-refresh is pure waste (we measured ~7 s of waste on
    /// slow networks). Without this, every first mutating callable after
    /// sign-in pays the cost of a redundant Identity-Toolkit round-trip.
    func markIDTokenJustRefreshed() {
        lastIDTokenRefresh = Date()
    }

    private func decode<T: Decodable>(_: T.Type, from raw: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func encodeToDict<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FunctionsError.malformedResponse
        }
        return dict
    }
}
