import Foundation
import DeviceCheck
import CryptoKit

// Phase 1. DCAppAttestService proves a request comes from a genuine, unmodified
// build of this app on a real device. Blocks the deepfake camera-injection
// attack class that OSS liveness pipelines can't defeat on their own.

enum AttestationError: Error {
    case unsupported
    case invalidChallenge
    case noKeyReturned
    case noAttestationReturned
    case noAssertionReturned
}

actor AttestationService {
    static let shared = AttestationService()

    private let service = DCAppAttestService.shared

    var isSupported: Bool { service.isSupported }

    func generateKey() async throws -> String {
        guard service.isSupported else { throw AttestationError.unsupported }
        return try await withCheckedThrowingContinuation { cont in
            service.generateKey { keyId, error in
                if let error { cont.resume(throwing: error); return }
                guard let keyId else { cont.resume(throwing: AttestationError.noKeyReturned); return }
                cont.resume(returning: keyId)
            }
        }
    }

    /// Returns base64-encoded CBOR attestation. Nonce is treated as an opaque
    /// UTF-8 string: clientDataHash = SHA-256(utf8(nonce)). Matches the server
    /// verifier in @plantagoai/attestation which does `Buffer.from(req.nonce)`
    /// (UTF-8) before hashing. The server emits base64url-encoded nonces so
    /// base64-decoding them on the client would mostly fail anyway.
    func attestKey(keyId: String, nonce: String) async throws -> String {
        let clientDataHash = Data(SHA256.hash(data: Data(nonce.utf8)))
        return try await withCheckedThrowingContinuation { cont in
            service.attestKey(keyId, clientDataHash: clientDataHash) { attestation, error in
                if let error { cont.resume(throwing: error); return }
                guard let attestation else { cont.resume(throwing: AttestationError.noAttestationReturned); return }
                cont.resume(returning: attestation.base64EncodedString())
            }
        }
    }

    /// Per-request signature using a previously-attested key.
    func generateAssertion(keyId: String, payloadBase64: String) async throws -> String {
        guard let payload = Data(base64Encoded: payloadBase64) else {
            throw AttestationError.invalidChallenge
        }
        let clientDataHash = Data(SHA256.hash(data: payload))
        return try await withCheckedThrowingContinuation { cont in
            service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let error { cont.resume(throwing: error); return }
                guard let assertion else { cont.resume(throwing: AttestationError.noAssertionReturned); return }
                cont.resume(returning: assertion.base64EncodedString())
            }
        }
    }

    /// Full nonce → attest → submit round-trip. Feeds the Phase 7 enclave seal
    /// via the `recordMobileAttestation` callable. Persists the attested keyId
    /// so future runs use `generateAssertion` instead.
    func attestDeviceEndToEnd() async throws -> RecordAttestationResult {
        let nonce = try await FunctionsService.shared.issueAttestationNonce()
        let keyId = try await generateKey()
        let attestation = try await attestKey(keyId: keyId, nonce: nonce.nonce)
        let result = try await FunctionsService.shared.recordMobileAttestation(
            RecordAttestationRequest(
                nonce: nonce.nonce,
                attestation: .init(
                    platform: "ios",
                    keyId: keyId,
                    attestation: attestation
                )
            )
        )
        if result.accepted {
            Keychain.setAttestedKeyId(keyId)
        }
        return result
    }
}
