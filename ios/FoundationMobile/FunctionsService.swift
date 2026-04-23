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

enum FunctionsError: Error {
    case malformedResponse
}

actor FunctionsService {
    static let shared = FunctionsService()

    private let functions = Functions.functions()

    func issueAttestationNonce() async throws -> AttestationNonce {
        let result = try await functions.httpsCallable("issueAttestationNonce").call([:])
        return try decode(AttestationNonce.self, from: result.data)
    }

    func recordMobileAttestation(_ req: RecordAttestationRequest) async throws -> RecordAttestationResult {
        let payload = try encodeToDict(req)
        let result = try await functions.httpsCallable("recordMobileAttestation").call(payload)
        return try decode(RecordAttestationResult.self, from: result.data)
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
