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

struct RecordAttestationResult: Decodable, Sendable {
    let accepted: Bool
    let commitment: String?
}

struct ResendInviteLinkResult: Decodable, Sendable {
    let status: String
    let sent: Bool
    let reason: String?
}

// OTP sign-in (iOS-only path). See requestSignInCode / verifySignInCode
// in foundation-global/functions/index.js for the threat model. Replaces
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

// Phase 2 — seal commitment anchor.
//
// The client produces an EnclaveSeal.Commitment locally (SHA-256 over the
// canonical artifact bytes) and posts it here. The server re-derives the
// canonical bytes from the same `artifacts` payload, verifies the hash
// matches, persists to Firestore, and writes the hash to Solana devnet
// via the shared Anchor client. The mobile side never holds a Solana
// keypair (hard invariant — see project_solana_server_side).
//
// `kinds` is the rawValue list of ProofArtifact.Kind values in the seal,
// sorted the same way EnclaveSeal.seal sorts them (alphabetical by
// rawValue). `producedAtMs` is EnclaveSeal.Commitment.producedAtMs.
struct AnchorCommitmentRequest: Encodable, Sendable {
    let commitment: CommitmentPayload
    let artifacts: [ArtifactPayload]
    /// Optional biometric seal sidecar — present when BiometricSealer
    /// successfully signed the commitment.hashHex with the user's
    /// Secure-Enclave-bound, Face-ID-protected key. Server stores the
    /// fields on the commitment doc; cryptographic verification lives
    /// in a follow-on task. Sending it on every successful seal lets
    /// the server log + audit even before verification ships.
    let biometricSeal: BiometricSealPayload?
    /// Optional biometric seal of the passport dg1Hash — present when the
    /// user completed Face ID on the "Passport scanned" screen before verify.
    /// Signing the dg1Hash (32-byte SHA-256 of DG1) creates a proof that this
    /// specific face authorized this specific passport's identity data.
    let passportBiometricSeal: BiometricSealPayload?

    struct CommitmentPayload: Encodable, Sendable {
        let hashHex: String
        let producedAtMs: Int64
        let kinds: [String]
    }

    struct ArtifactPayload: Encodable, Sendable {
        let kind: String
        let producedAtMs: Int64
        let payloadHashHex: String
        let signatureBase64: String
    }

    struct BiometricSealPayload: Encodable, Sendable {
        /// SEC1 / X9.63 uncompressed public key, base64-encoded. Sent
        /// every call so the server can lazily build a per-uid public
        /// key registry without a separate enrollment round-trip.
        let publicKeyB64: String
        /// DER ECDSA-P256 signature over UTF-8 bytes of
        /// commitment.hashHex, base64-encoded. SecKey signs with
        /// `.ecdsaSignatureMessageX962SHA256` so the algorithm hashes
        /// the payload internally.
        let signatureB64: String
        /// Local timestamp the signature was produced. Surfaces clock
        /// skew vs server time at audit; not enforced.
        let signedAtMs: Int64
    }
}

struct AnchorCommitmentResult: Decodable, Sendable, Equatable {
    let accepted: Bool
    // "queued" — server enqueued the on-chain write; poll the Firestore doc
    // at commitmentDocPath for the transition to "anchored" or "anchor-failed".
    // "anchored" — tx landed on-chain; slot + txSignature populated.
    // "anchor-failed" — DLQ'd after 24h retry budget.
    // nil — legacy stub response shape (pre-2026-04-25 deploy).
    let status: String?
    let slot: Int64?
    let txSignature: String?
    let commitmentDocPath: String?
    let recordAddress: String?
    let reason: String?
}

// Phase — desktop pairing.
//
// Desktop calls `requestPairingCode` (unauthenticated) and renders the
// returned code as a QR. Mobile scans, calls `claimPairingSession` (authed)
// to attach the mobile UID + ring claims to the server-side pairing doc.
// Mobile then heartbeats every ~30s; server flips to "stale" after 90s
// without a heartbeat (cleanupStalePairings scheduled function).
struct ClaimPairingSessionResult: Decodable, Sendable {
    let sessionId: String
    let acceptedAtMs: Int64?
}

struct AckResult: Decodable, Sendable {
    let ok: Bool
}

// Support ticket — diagnostic-only payload. SupportSheet renders the
// same strings it sends, so what the user sees is what the support team
// receives. Server enforces strict per-field length caps and writes to
// /support/{ticketId} via admin SDK; client direct read/write is denied
// in firestore.rules. No personal data — see foundation-global
// submitSupportTicket comments.
struct SubmitSupportTicketRequest: Encodable, Sendable {
    let appAttest: String
    let moproStatus: String
    let humanityState: String
    let latestCommitment: String
    let anchorStatus: String
    let profileId: String
    let appVersion: String
    let buildVersion: String
    let iosVersion: String
    let deviceModel: String
}

struct SupportTicketResult: Decodable, Sendable {
    let ticketId: String
    let createdAtMs: Int64
}

// Web session bridge — Firebase custom token minted by the server for
// the embedded WKWebView. Token is one-shot: WebContainer exchanges it
// for a Firebase web-session ID token via signInWithCustomToken, then
// drops the raw token. Server gates mint on a recent email-link sign-in
// (auth_time freshness, same as pair-claim/release), so a stolen-but-
// still-signed-in phone can't quietly mint web access.
struct RecordBiometricConsentResult: Decodable, Sendable {
    let success: Bool
    let version: String
}

struct CheckBiometricConsentResult: Decodable, Sendable {
    let accepted: Bool
    let currentVersion: String
    let documentType: String
}

struct WebSessionTokenResult: Decodable, Sendable {
    let customToken: String
    let issuedAtMs: Int64
    let expiresInSeconds: Int
}

enum FunctionsError: Error {
    case malformedResponse
    /// hisec-global profile attempted a mutating callable while tier
    /// is .unattested — the App Attest gate must succeed (or the user
    /// must be on a lower-security profile) before mutating callables
    /// are allowed. 2026-04-26 security review M-H-3.
    case unattestedTierForHisec
}

actor FunctionsService {
    static let shared = FunctionsService()

    // All Foundation callables are deployed to us-east1. Firebase's default
    // region is us-central1, so passing the region explicitly is required
    // or the SDK routes to a nonexistent function URL.
    // Resolved per-call so deployment switches take effect immediately.
    private var functions: Functions {
        Functions.functions(app: DeploymentService.shared.currentFirebaseApp, region: "us-east1")
    }

    /// Last time we forced a Firebase ID token refresh. Mutating callables
    /// gate on this to avoid sending a stale cached token to the server.
    /// The Firebase iOS SDK's default `getIDToken(forcingRefresh: false)`
    /// will return a cached token until its 1-h TTL expires — even after
    /// a sign-out + email-link re-sign-in — which produced the
    /// "Session is stale" failures we kept hitting in YC-demo testing.
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
    ///
    /// Plan ref: P0-2 (Foundation Mobile + Backend Resilience Plan).
    private func refreshIDTokenIfStale() async throws {
        let now = Date()
        if let last = lastIDTokenRefresh,
           now.timeIntervalSince(last) < Self.idTokenStaleWindow {
            return
        }
        guard let user = await MainActor.run(body: { Auth.auth(app: DeploymentService.shared.currentFirebaseApp).currentUser }) else {
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

    func resendInviteLink(email: String) async throws -> ResendInviteLinkResult {
        // Pre-sign-in callable — no auth context to refresh.
        let result = try await functions.httpsCallable("resendInviteLink").call([
            "email": email,
            "platform": "ios",
        ])
        return try decode(ResendInviteLinkResult.self, from: result.data)
    }

    /// Ask the server to email a 6-digit sign-in code. Replaces the
    /// email-link path on iOS — see requestSignInCode in foundation-
    /// global/functions/index.js for the why.
    func requestSignInCode(email: String) async throws -> RequestSignInCodeResult {
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

    func anchorCommitment(_ req: AnchorCommitmentRequest) async throws -> AnchorCommitmentResult {
        try await refreshIDTokenIfStale()
        var payload = try encodeToDict(req)
        payload = try await Self.injectAttestationTier(into: payload)
        let result = try await functions.httpsCallable("anchorCommitment").call(payload)
        return try decode(AnchorCommitmentResult.self, from: result.data)
    }

    func claimPairingSession(code: String) async throws -> ClaimPairingSessionResult {
        try await refreshIDTokenIfStale()
        let payload = try await Self.injectAttestationTier(into: ["code": code])
        let result = try await functions.httpsCallable("claimPairingSession").call(payload)
        return try decode(ClaimPairingSessionResult.self, from: result.data)
    }

    func heartbeatPairingSession(sessionId: String) async throws -> AckResult {
        // Heartbeats are read-mostly (touch the doc, no state change beyond
        // lastHeartbeatAt) — server doesn't gate them on freshness, so no
        // tier injection or token refresh needed. The 10s heartbeat cadence
        // also makes per-tick refresh actively harmful (ID-token endpoint
        // round-trips on every beat would mask real network latency).
        let result = try await functions.httpsCallable("heartbeatPairingSession").call(["sessionId": sessionId])
        return try decode(AckResult.self, from: result.data)
    }

    func releasePairingSession(sessionId: String) async throws -> AckResult {
        try await refreshIDTokenIfStale()
        let payload = try await Self.injectAttestationTier(into: ["sessionId": sessionId])
        let result = try await functions.httpsCallable("releasePairingSession").call(payload)
        return try decode(AckResult.self, from: result.data)
    }

    func submitSupportTicket(_ req: SubmitSupportTicketRequest) async throws -> SupportTicketResult {
        // Diagnostic-only path — must work even when other gates fail; we
        // explicitly do NOT refresh here (the network may already be
        // half-broken, which is when support tickets matter most).
        let payload = try encodeToDict(req)
        let result = try await functions.httpsCallable("submitSupportTicket").call(payload)
        return try decode(SupportTicketResult.self, from: result.data)
    }

    func mintWebSessionToken() async throws -> WebSessionTokenResult {
        try await refreshIDTokenIfStale()
        let payload = try await Self.injectAttestationTier(into: [:])
        let result = try await functions.httpsCallable("mintWebSessionToken").call(payload)
        return try decode(WebSessionTokenResult.self, from: result.data)
    }

    // 2026-04-26 security review M-CRIT-4: Art. 9 biometric consent.
    // Server-side schema lives at users/{uid}/legal_consent/biometric-processing_<version>.
    // Pattern mirrors the existing ToS callables.

    func recordBiometricConsent() async throws -> RecordBiometricConsentResult {
        try await refreshIDTokenIfStale()
        let result = try await functions.httpsCallable("recordBiometricConsent").call([:])
        return try decode(RecordBiometricConsentResult.self, from: result.data)
    }

    func checkBiometricConsent() async throws -> CheckBiometricConsentResult {
        // Read-only check; cached token is fine.
        let result = try await functions.httpsCallable("checkBiometricConsent").call([:])
        return try decode(CheckBiometricConsentResult.self, from: result.data)
    }

    /// Force the next mutating callable to refresh the ID token, regardless
    /// of staleness window. Call from AuthService.signOut so the very first
    /// callable after a fresh sign-in skips the cache-warming window.
    func invalidateIDTokenCache() {
        lastIDTokenRefresh = nil
    }

    /// Mark the ID token as freshly refreshed without actually forcing a
    /// network round-trip. Use this right after `Auth.signIn(withCustomToken:)`
    /// or `Auth.signIn(withEmail:link:)` succeed — those calls produce a
    /// fresh ID token as a side effect, so a subsequent force-refresh is
    /// pure waste (we measured ~7 s of waste on slow networks). Without
    /// this, every first mutating callable after sign-in pays the cost
    /// of a redundant Identity-Toolkit round-trip.
    func markIDTokenJustRefreshed() {
        lastIDTokenRefresh = Date()
    }

    /// Adds the current attestation tier to a callable payload. Mutating
    /// callables (mintWebSessionToken, claim/release pairing, anchor)
    /// read this on the server to pick a freshness window and stamp
    /// produced artifacts. AttestationCoordinator runs on @MainActor so
    /// the tier read hops there briefly.
    ///
    /// 2026-04-26 security review M-H-3: belt-and-suspenders. On the
    /// hisec-global profile, refuse to send `.unattested` for mutating
    /// callables — the server's per-callable enforcement is the real
    /// gate, but throwing client-side surfaces the precondition early
    /// and keeps the unattested-skip carve-out scoped to lower-security
    /// profiles where it's intentional.
    private static func injectAttestationTier(into base: [String: Any]) async throws -> [String: Any] {
        let tier = await MainActor.run { AttestationCoordinator.shared.tier.rawValue }
        let profileId = AppConfig.shared.profile.id
        if profileId == "hisec-global" && tier == AttestationTier.unattested.rawValue {
            throw FunctionsError.unattestedTierForHisec
        }
        var payload = base
        payload["attestationTier"] = tier
        return payload
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
