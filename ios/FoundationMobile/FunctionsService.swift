import Foundation
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
struct WebSessionTokenResult: Decodable, Sendable {
    let customToken: String
    let issuedAtMs: Int64
    let expiresInSeconds: Int
}

enum FunctionsError: Error {
    case malformedResponse
}

actor FunctionsService {
    static let shared = FunctionsService()

    // All Foundation callables are deployed to us-east1. Firebase's default
    // region is us-central1, so passing the region explicitly is required
    // or the SDK routes to a nonexistent function URL.
    private let functions = Functions.functions(region: "us-east1")

    func issueAttestationNonce() async throws -> AttestationNonce {
        let result = try await functions.httpsCallable("issueAttestationNonce").call([:])
        return try decode(AttestationNonce.self, from: result.data)
    }

    func recordMobileAttestation(_ req: RecordAttestationRequest) async throws -> RecordAttestationResult {
        let payload = try encodeToDict(req)
        let result = try await functions.httpsCallable("recordMobileAttestation").call(payload)
        return try decode(RecordAttestationResult.self, from: result.data)
    }

    func resendInviteLink(email: String) async throws -> ResendInviteLinkResult {
        let result = try await functions.httpsCallable("resendInviteLink").call([
            "email": email,
            "platform": "ios",
        ])
        return try decode(ResendInviteLinkResult.self, from: result.data)
    }

    func anchorCommitment(_ req: AnchorCommitmentRequest) async throws -> AnchorCommitmentResult {
        var payload = try encodeToDict(req)
        payload = await Self.injectAttestationTier(into: payload)
        let result = try await functions.httpsCallable("anchorCommitment").call(payload)
        return try decode(AnchorCommitmentResult.self, from: result.data)
    }

    func claimPairingSession(code: String) async throws -> ClaimPairingSessionResult {
        let payload = await Self.injectAttestationTier(into: ["code": code])
        let result = try await functions.httpsCallable("claimPairingSession").call(payload)
        return try decode(ClaimPairingSessionResult.self, from: result.data)
    }

    func heartbeatPairingSession(sessionId: String) async throws -> AckResult {
        // Heartbeats are read-mostly (touch the doc, no state change beyond
        // lastHeartbeatAt) — server doesn't gate them on freshness, so no
        // tier injection needed.
        let result = try await functions.httpsCallable("heartbeatPairingSession").call(["sessionId": sessionId])
        return try decode(AckResult.self, from: result.data)
    }

    func releasePairingSession(sessionId: String) async throws -> AckResult {
        let payload = await Self.injectAttestationTier(into: ["sessionId": sessionId])
        let result = try await functions.httpsCallable("releasePairingSession").call(payload)
        return try decode(AckResult.self, from: result.data)
    }

    func submitSupportTicket(_ req: SubmitSupportTicketRequest) async throws -> SupportTicketResult {
        let payload = try encodeToDict(req)
        let result = try await functions.httpsCallable("submitSupportTicket").call(payload)
        return try decode(SupportTicketResult.self, from: result.data)
    }

    func mintWebSessionToken() async throws -> WebSessionTokenResult {
        let payload = await Self.injectAttestationTier(into: [:])
        let result = try await functions.httpsCallable("mintWebSessionToken").call(payload)
        return try decode(WebSessionTokenResult.self, from: result.data)
    }

    /// Adds the current attestation tier to a callable payload. Mutating
    /// callables (mintWebSessionToken, claim/release pairing, anchor)
    /// read this on the server to pick a freshness window and stamp
    /// produced artifacts. AttestationCoordinator runs on @MainActor so
    /// the tier read hops there briefly.
    private static func injectAttestationTier(into base: [String: Any]) async -> [String: Any] {
        let tier = await MainActor.run { AttestationCoordinator.shared.tier.rawValue }
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
