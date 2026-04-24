import Foundation
import CryptoKit
import DeviceCheck

// Phase 2 fan-in coordinator. Drives a multi-pose liveness capture sequence
// (stand-in for Phase 4 MediaPipe active-liveness until it ships), then signs
// + seals all captured frames together as a single `.liveness` artifact fanned
// in with the Phase 1 `.appAttest` assertion and Phase 3/5/6 mocks. One
// artifact per enabled kind.

@MainActor
final class CaptureCoordinator: ObservableObject {
    static let shared = CaptureCoordinator()

    enum State: Equatable {
        case idle
        case unsupported
        case needsAttestation
        // Waiting for the user to tap Capture for the given pose. `captured`
        // is how many frames are already in the buffer (0-indexed for which
        // pose is showing: pose index == captured when readyForPose fires).
        case readyForPose(pose: LivenessPose, captured: Int, total: Int)
        // All poses captured. Waiting for the user to tap Verify.
        case readyToVerify(framesCount: Int)
        // User tapped Verify; we're signing + sealing. `phase` tells the UI
        // which of the two we're in without making the view count seconds.
        case verifying(phase: VerifyPhase)
        case sealed(EnclaveSeal.Commitment)
        case failed(String)
    }

    enum VerifyPhase: Equatable {
        case signing
        case sealing
    }

    @Published private(set) var state: State = .idle

    // In-memory only. Dropped as soon as the combined hash is computed in
    // `verify()`; never written to disk, never uploaded. Honors the
    // "nothing identifying leaves this device" invariant.
    private var capturedJpegs: [Data] = []
    private var task: Task<Void, Never>?

    // Begin a fresh capture run. Call from CaptureView.onAppear.
    func begin() {
        task?.cancel()
        task = nil
        capturedJpegs.removeAll()

        guard DCAppAttestService.shared.isSupported else {
            state = .unsupported
            return
        }
        guard Keychain.getAttestedKeyId() != nil else {
            state = .needsAttestation
            return
        }
        state = .readyForPose(
            pose: LivenessPose.allCases[0],
            captured: 0,
            total: LivenessPose.allCases.count
        )
    }

    // Grab one frame for the current pose, then advance to the next pose
    // (or to `.readyToVerify` if this was the last one).
    func capturePose() {
        guard case .readyForPose(_, let captured, let total) = state else { return }

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let frame = try await CameraSession.shared.captureOneFrame()
                let jpeg = try LivenessFrameEncoder.encodeJpeg(frame)
                self.capturedJpegs.append(jpeg)

                let next = captured + 1
                if next < total {
                    self.state = .readyForPose(
                        pose: LivenessPose.allCases[next],
                        captured: next,
                        total: total
                    )
                } else {
                    self.state = .readyToVerify(framesCount: next)
                }
            } catch {
                self.state = .failed(String(describing: error))
            }
        }
    }

    // User tapped Verify: sign the combined liveness payload with App Attest,
    // build the Phase 1 appAttest artifact, fan in mocks, seal. AttestationService
    // self-heals on a stale keyId, so a ~5-8s stall on first run is normal.
    func verify() {
        guard case .readyToVerify(let framesCount) = state, framesCount > 0 else { return }
        guard let keyId = Keychain.getAttestedKeyId() else {
            state = .needsAttestation
            return
        }

        let jpegs = capturedJpegs
        self.capturedJpegs.removeAll()  // drop the raw bytes eagerly

        task = Task { [weak self] in
            guard let self else { return }
            do {
                self.state = .verifying(phase: .signing)

                // Liveness payload = concat of per-frame SHA-256s. Keeps the
                // signed surface small (96 B for 3 frames) while still
                // binding all frames into the commitment.
                let perFrameHashes = jpegs.map { Data(SHA256.hash(data: $0)) }
                let combinedPayload = perFrameHashes.reduce(Data(), +)
                let liveness = try await ProofArtifactBuilder.build(
                    kind: .liveness,
                    payload: combinedPayload
                )

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

                self.state = .verifying(phase: .sealing)
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
        capturedJpegs.removeAll()
        state = .idle
    }
}

enum CaptureCoordinatorError: Error {
    case duplicateArtifact(ProofArtifact.Kind)
}

// Pose prompts for the multi-frame liveness sequence. Until Phase 4's real
// active-liveness detector lands, these are UX theater — they drive the user
// to move their head so multiple distinct frames land in the combined hash,
// but the app does not verify that the head actually moved. Phase 4 adds the
// MediaPipe check; the signature surface stays identical so migrating is a
// drop-in.
enum LivenessPose: String, CaseIterable, Equatable {
    case straight
    case left
    case right

    var prompt: String {
        switch self {
        case .straight: return "Look straight at the camera"
        case .left: return "Turn your head slowly to the left"
        case .right: return "Turn your head slowly to the right"
        }
    }

    var sfSymbol: String {
        switch self {
        case .straight: return "person.fill"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}
