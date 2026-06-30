import Foundation

// Phase 3a — real .nfcZk artifact. Replaces MockNfcZkProducer's synthetic
// "mock:nfc-zk" payload with a SHA-256(DG1) signed by the device's App
// Attest key via ProofArtifactBuilder. The signed payload becomes the
// artifact's payloadHashHex; the App Attest assertion becomes its
// signatureBase64. The Phase 7 enclave seal concatenates this with the
// other artifacts and the commitment hash is what the server audits.
//
// Phase 3b will swap this for a zk-self-style Circom circuit that proves
// DG1 properties (age-over-18, nationality-is-X) without revealing the
// bytes. The signature surface stays identical — only the payload changes
// from `SHA-256(DG1)` to `SHA-256(circuit public inputs)`.

struct PassportNfcProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .nfcZk
    let documentData: DocumentReadResult

    func produce() async throws -> ProofArtifact {
        // documentData.dg1Hash is already SHA-256(DG1 raw bytes).
        // ProofArtifactBuilder will hash the payload again (that's its
        // contract for every artifact kind — inputs are whatever raw
        // bytes a producer wants to bind into the commitment). Net result:
        // payloadHashHex = SHA-256(SHA-256(DG1)). The App Attest assertion
        // signs over that doubled hash. Keeping the builder signature
        // stable means no special-case code in EnclaveSeal.
        return try await ProofArtifactBuilder.build(
            kind: .nfcZk,
            payload: documentData.dg1Hash
        )
    }
}
