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

    /// Per-request signature using a previously-attested key. Self-heals on
    /// `DCError.invalidKey` — the Keychain-cached keyId can go stale when the
    /// app is reinstalled, the Secure Enclave purges the key, or Apple's
    /// App Attest backend invalidates it independently. In those cases we
    /// wipe the keychain entry, re-attest end-to-end, and retry the
    /// assertion once with the fresh keyId. A second failure propagates as-is.
    func generateAssertion(keyId: String, payloadBase64: String) async throws -> String {
        guard let payload = Data(base64Encoded: payloadBase64) else {
            throw AttestationError.invalidChallenge
        }
        let clientDataHash = Data(SHA256.hash(data: payload))
        do {
            return try await callGenerateAssertion(keyId: keyId, clientDataHash: clientDataHash)
        } catch let error as NSError where Self.isInvalidKeyError(error) {
            Keychain.clearAttestedKeyId()
            _ = try await attestDeviceEndToEnd()
            guard let freshKeyId = Keychain.getAttestedKeyId() else {
                throw AttestationError.noKeyReturned
            }
            return try await callGenerateAssertion(keyId: freshKeyId, clientDataHash: clientDataHash)
        }
    }

    private func callGenerateAssertion(keyId: String, clientDataHash: Data) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            service.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let error { cont.resume(throwing: error); return }
                guard let assertion else { cont.resume(throwing: AttestationError.noAssertionReturned); return }
                cont.resume(returning: assertion.base64EncodedString())
            }
        }
    }

    // DCError domain + code matched textually. DCError.Code.invalidKey is
    // defined as 3 by DeviceCheck.framework; hard-coding avoids an import
    // of DCError's Swift enum name (which the SDK exports inconsistently
    // across Xcode versions).
    private static func isInvalidKeyError(_ error: NSError) -> Bool {
        error.domain == "com.apple.devicecheck.error" && error.code == 3
    }

    /// Full nonce → attest → submit round-trip. Feeds the Phase 7 enclave seal
    /// via the `recordMobileAttestation` callable. Persists the attested keyId
    /// so future runs use `generateAssertion` instead.
    func attestDeviceEndToEnd() async throws -> RecordAttestationResult {
        let nonce = try await FunctionsService.shared.issueAttestationNonce()
        let keyId = try await generateKey()
        let attestation = try await attestKey(keyId: keyId, nonce: nonce.nonce)
        #if DEBUG
        Self.dumpAttestationForDebug(
            keyId: keyId,
            nonce: nonce.nonce,
            attestationBase64: attestation
        )
        #endif
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

    #if DEBUG
    // Debug-only export of the App Attest CBOR blob + the metadata
    // needed to reproduce the assertion offline. Writes into the app's
    // Documents directory; pull via Xcode → Window → Devices and
    // Simulators → FoundationMobile → ⚙ → Download Container.
    //
    // Files emitted (per attest):
    //   attestation-<keyId-prefix>-<timestamp>.b64    — base64 CBOR
    //   attestation-<keyId-prefix>-<timestamp>.cbor   — raw CBOR bytes
    //   attestation-<keyId-prefix>-<timestamp>-meta.txt
    //
    // Decode the .cbor with any CBOR tool (e.g. https://cbor.me, the
    // `cborg` npm pkg, or openssl asn1parse via the embedded x5c chain).
    //
    // HARD INVARIANT: this path is wrapped in #if DEBUG. Release builds
    // never write the attestation bytes to disk.
    nonisolated static func dumpAttestationForDebug(
        keyId: String,
        nonce: String,
        attestationBase64: String
    ) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = fmt.string(from: Date())
        let keyIdPrefix = String(keyId.prefix(8))
        let prefix = "attestation-\(keyIdPrefix)-\(stamp)"

        let b64URL = docs.appendingPathComponent("\(prefix).b64")
        try? attestationBase64.data(using: .utf8)?.write(to: b64URL)

        if let cborBytes = Data(base64Encoded: attestationBase64) {
            let cborURL = docs.appendingPathComponent("\(prefix).cbor")
            try? cborBytes.write(to: cborURL)
            print("[DEBUG] App Attest CBOR → \(cborURL.lastPathComponent) (\(cborBytes.count) bytes)")
        }

        let clientDataHashHex = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let meta = """
        app-attest-debug-dump
        ---
        timestamp: \(stamp)
        bundleId: \(bundleId)
        keyId: \(keyId)
        nonce: \(nonce)
        clientDataHashHex: \(clientDataHashHex)
        attestationBase64Length: \(attestationBase64.count)
        ---
        verify offline:
          1. Decode .cbor as CBOR → map of fmt + attStmt + authData
          2. Extract x5c chain from attStmt → leaf cert + Apple CA chain
          3. Validate authData[0:32] == SHA256("appattest" || teamId || bundleId)
          4. Validate clientDataHash matches: \(clientDataHashHex)
        """
        let metaURL = docs.appendingPathComponent("\(prefix)-meta.txt")
        try? meta.data(using: .utf8)?.write(to: metaURL)
        print("[DEBUG] App Attest meta → \(metaURL.lastPathComponent)")
    }
    #endif
}
