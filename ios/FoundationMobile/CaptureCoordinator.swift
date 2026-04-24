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
        // All poses captured. Waiting for the user to tap "Scan passport".
        case readyForPassport(framesCount: Int)
        // NFC chip read in flight. Triggered after MRZScanView parses the
        // MRZ key; the system NFC modal is drawn by CoreNFC.
        case scanningPassport(framesCount: Int)
        // NFC read completed. Waiting for the user to tap Verify.
        case passportReady(framesCount: Int, passport: PassportReadResult)
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

    // Server-audit status for the most recently sealed commitment. Tracked
    // separately from `state` so CaptureView can auto-dismiss on `.sealed`
    // and HomeView can keep rendering the anchor status live as the server
    // round-trip completes (or fails). Reset to `.notAttempted` on begin().
    @Published private(set) var anchorStatus: AnchorStatus = .notAttempted

    // In-memory only. Dropped as soon as the combined hash is computed in
    // `verify()`; never written to disk, never uploaded. Honors the
    // "nothing identifying leaves this device" invariant.
    private var capturedJpegs: [Data] = []
    private var task: Task<Void, Never>?
    private var anchorTask: Task<Void, Never>?
    private var passportScanTask: Task<Void, Never>?

    // Tracks the pre-scan frame count so the retry path can restore the
    // correct `.readyForPassport(framesCount:)` state after a failure
    // without re-running the pose loop.
    private var lastFramesCount: Int = 0

    // Begin a fresh capture run. Call from CaptureView.onAppear.
    func begin() {
        task?.cancel()
        anchorTask?.cancel()
        passportScanTask?.cancel()
        task = nil
        anchorTask = nil
        passportScanTask = nil
        capturedJpegs.removeAll()
        lastFramesCount = 0
        anchorStatus = .notAttempted

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
                    self.lastFramesCount = next
                    self.state = .readyForPassport(framesCount: next)
                }
            } catch {
                self.state = .failed(String(describing: error))
            }
        }
    }

    // Phase 3a — NFC chip read step. Called from CaptureView once
    // MRZScanView hands back a parsed MRZ key. Transitions through
    // .scanningPassport → .passportReady(...) → (user taps Verify).
    func scanPassport(mrzKey: MRZKey) {
        // Accept from either state — user may have just finished the pose
        // loop (.readyForPassport) or is retrying after a scan failure
        // (.failed, where lastFramesCount still carries the right count).
        let frames: Int
        switch state {
        case .readyForPassport(let n): frames = n
        case .failed: frames = lastFramesCount
        default: return
        }

        state = .scanningPassport(framesCount: frames)
        passportScanTask?.cancel()
        passportScanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await PassportNFCReader.shared.readPassport(mrzKey: mrzKey)
                self.state = .passportReady(framesCount: frames, passport: result)
            } catch {
                self.state = .failed("Passport scan failed: \(error.localizedDescription)")
            }
        }
    }

    // Called from NFCScanView's retry button when the scan failed. Drops
    // the user back to .readyForPassport so CaptureView re-presents
    // MRZScanView. Preserves already-captured liveness frames.
    func retryPassportFromFailure() {
        guard case .failed = state else { return }
        state = .readyForPassport(framesCount: lastFramesCount)
    }

    // User tapped Verify: sign the combined liveness payload with App Attest,
    // build the Phase 1 appAttest artifact, build the Phase 3a real .nfcZk
    // artifact from the NFC scan, fan in remaining mocks, seal.
    // AttestationService self-heals on a stale keyId, so a ~5-8s stall on
    // first run is normal.
    func verify() {
        guard case .passportReady(let framesCount, let passport) = state, framesCount > 0 else { return }
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

                // Phase 3a — real .nfcZk artifact bound to the captured DG1.
                let nfcArtifact = try await PassportNfcProducer(passportData: passport).produce()

                var artifacts: [ProofArtifact] = [appAttest, liveness, nfcArtifact]
                // .nfcZk is now produced explicitly above; keep the loop for
                // the still-mocked phases.
                for kind in [ProofArtifact.Kind.antiSpoof, .faceMatch] {
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
                self.submitAnchor(commitment: commitment, artifacts: artifacts)
            } catch {
                self.state = .failed(String(describing: error))
            }
        }
    }

    // Fire-and-forget the server audit call. Runs alongside the auto-dismiss
    // in CaptureView so HomeView is already visible when the anchor result
    // arrives — @Published anchorStatus drives live HomeView updates without
    // blocking the user's return-home transition.
    private func submitAnchor(commitment: EnclaveSeal.Commitment, artifacts: [ProofArtifact]) {
        anchorStatus = .pending
        anchorTask = Task { [weak self] in
            let req = AnchorCommitmentRequest(
                commitment: .init(
                    hashHex: commitment.commitmentHashHex,
                    producedAtMs: commitment.producedAtMs,
                    kinds: commitment.artifactKinds.map { $0.rawValue }
                ),
                artifacts: artifacts.map {
                    .init(
                        kind: $0.kind.rawValue,
                        producedAtMs: $0.producedAtMs,
                        payloadHashHex: $0.payloadHashHex,
                        signatureBase64: $0.signatureBase64
                    )
                }
            )
            do {
                let result = try await FunctionsService.shared.anchorCommitment(req)
                self?.anchorStatus = .completed(result)
            } catch {
                self?.anchorStatus = .failed(String(describing: error))
            }
        }
    }

    func reset() {
        task?.cancel()
        anchorTask?.cancel()
        passportScanTask?.cancel()
        task = nil
        anchorTask = nil
        passportScanTask = nil
        capturedJpegs.removeAll()
        lastFramesCount = 0
        anchorStatus = .notAttempted
        state = .idle
    }
}

enum CaptureCoordinatorError: Error {
    case duplicateArtifact(ProofArtifact.Kind)
}

// Server-audit + on-chain anchor status for a sealed commitment. `pending`
// fires as soon as the seal lands; `completed` carries the server's reply
// (which itself may say accepted=false / solana-anchor-not-wired until the
// Anchor program ships the commitment-anchor instruction). `failed` captures
// network / auth errors before any server-level response.
enum AnchorStatus: Equatable {
    case notAttempted
    case pending
    case completed(AnchorCommitmentResult)
    case failed(String)
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
