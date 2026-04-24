import Foundation
import DeviceCheck

// Phase 2 fan-in coordinator: drives the capture → sign → mock-sensors → seal
// sequence and publishes UI-visible state. Phase 4 is the only real producer
// today; kinds 3/5/6 come from `ProofProducerRegistry` mocks until their
// phases land. Exactly one artifact per enabled kind is expected.

@MainActor
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()

    enum State: Equatable {
        case idle
        case unsupported
        case needsAttestation
        case capturing
        case signing
        case sealing
        case sealed(EnclaveSeal.Commitment)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private var task: Task<Void, Never>?

    func captureAndSeal() {
        if case .capturing = state { return }
        if case .signing = state { return }
        if case .sealing = state { return }

        guard DCAppAttestService.shared.isSupported else {
            state = .unsupported
            return
        }
        guard let keyId = Keychain.getAttestedKeyId() else {
            state = .needsAttestation
            return
        }

        task = Task { [weak self] in
            guard let self else { return }
            do {
                self.state = .capturing
                let liveness = try await LivenessFrameProducer().produce()

                self.state = .signing
                let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                let appAttestPayload = Data("appAttest:\(keyId):\(nowMs)".utf8)
                let appAttest = try await ProofArtifactBuilder.build(
                    kind: .appAttest,
                    payload: appAttestPayload
                )

                var artifacts: [ProofArtifact] = [appAttest, liveness]
                for kind in [ProofArtifact.Kind.nfcZk, .antiSpoof, .faceMatch] {
                    guard let producer = ProofProducerRegistry.producer(for: kind) else { continue }
                    let artifact = try await producer.produce()
                    artifacts.append(artifact)
                }

                let byKind = Dictionary(grouping: artifacts, by: \.kind)
                for (kind, group) in byKind where group.count != 1 {
                    throw CaptureCoordinatorError.duplicateArtifact(kind)
                }

                self.state = .sealing
                let commitment = EnclaveSeal.seal(artifacts: artifacts)
                self.state = .sealed(commitment)
            } catch {
                self.state = .failed(String(describing: error))
            }
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }
}

enum CaptureCoordinatorError: Error {
    case duplicateArtifact(ProofArtifact.Kind)
}
