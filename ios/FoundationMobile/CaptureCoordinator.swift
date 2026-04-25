import Foundation
import Combine
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

    // Phase 4 — active-liveness face tracker. Exposed so the view can
    // observe @Published status for overlay rendering. Lifecycle is
    // owned by the coordinator: started on .readyForPose entry, stopped
    // when pose advances / flow ends / flow restarts.
    let faceTracker = FaceTracker()

    // Pose-hold debounce: how long the user must continuously match the
    // target pose before we auto-capture. 250ms is responsive enough for
    // demo pacing while still rejecting a one-frame noise spike.
    static let poseHoldDuration: Duration = .milliseconds(250)

    // Total scan budget across the whole pose loop. When this fires we
    // auto-advance to .readyForPassport with whatever poses were captured
    // (or an emergency one-frame capture if none). This is the "seal with
    // face fingerprint even if not every pose was hit" fallback — users
    // aren't blocked from reaching the MRZ/NFC step by a flaky yaw signal.
    static let scanBudget: Duration = .seconds(15)

    // Countdown task that fires capturePose() after the user holds the
    // pose for poseHoldDuration. Cancelled whenever the pose match drops.
    private var poseHoldTask: Task<Void, Never>?
    // Single total-scan deadline; cancelled when all poses captured.
    private var scanBudgetTask: Task<Void, Never>?
    // Subscribes to faceTracker.$status and drives the auto-capture
    // countdown. One subscription per pose; torn down on stop.
    private var faceTrackerCancellable: AnyCancellable?

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

        // Phase 4 — reset tracker state for the new run.
        tearDownPoseWatchers()
        scanBudgetTask?.cancel()
        scanBudgetTask = nil
        faceTracker.stop()

        guard DCAppAttestService.shared.isSupported else {
            state = .unsupported
            return
        }
        guard Keychain.getAttestedKeyId() != nil else {
            state = .needsAttestation
            return
        }
        let firstPose = LivenessPose.active[0]
        state = .readyForPose(
            pose: firstPose,
            captured: 0,
            total: LivenessPose.active.count
        )
        startTracking(pose: firstPose)
        armScanBudget()
    }

    // Grab one frame for the current pose, then advance to the next pose
    // (or to `.readyToVerify` if this was the last one). Called by the
    // auto-capture path when faceTracker.status.matchesTargetPose stays
    // true for poseHoldDuration; also callable directly as a debug
    // affordance (no UI for that at present).
    func capturePose() {
        guard case .readyForPose(_, let captured, let total) = state else { return }

        // Stop the watchers eagerly so no stray pose-hold / timeout
        // fires while we're capturing and transitioning.
        tearDownPoseWatchers()
        faceTracker.stop()

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let frame = try await CameraSession.shared.captureOneFrame()
                let jpeg = try LivenessFrameEncoder.encodeJpeg(frame)
                self.capturedJpegs.append(jpeg)

                let next = captured + 1
                if next < total {
                    let nextPose = LivenessPose.active[next]
                    self.state = .readyForPose(
                        pose: nextPose,
                        captured: next,
                        total: total
                    )
                    // Restart tracker for the next pose.
                    self.startTracking(pose: nextPose)
                } else {
                    // All poses captured — cancel the scan budget so its
                    // expiry doesn't fire after we've already advanced.
                    self.scanBudgetTask?.cancel()
                    self.scanBudgetTask = nil
                    self.lastFramesCount = next
                    self.state = .readyForPassport(framesCount: next)
                }
            } catch {
                self.state = .failed(String(describing: error))
            }
        }
    }

    // MARK: — Phase 4 auto-capture helpers

    // Start the face tracker for this pose and wire the status stream
    // into the pose-hold countdown. Scan budget is armed once in begin()
    // and runs across all poses; no per-pose timeout here.
    private func startTracking(pose: LivenessPose) {
        tearDownPoseWatchers()
        faceTracker.start(targetPose: pose)

        // Subscribe to tracker status updates. On every emission, decide
        // whether to start / keep / cancel the pose-hold countdown.
        faceTrackerCancellable = faceTracker.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                self.handleTrackerUpdate(status: status, currentPose: pose)
            }
    }

    // Arm the single total-scan deadline. Called once from begin() after
    // the first pose's tracker starts. On expiry we stop pose tracking
    // and advance with whatever we've captured (emergency one-frame
    // capture if nothing got through) so the NFC step is always reachable.
    private func armScanBudget() {
        scanBudgetTask = Task { [weak self] in
            try? await Task.sleep(for: Self.scanBudget)
            if Task.isCancelled { return }
            await MainActor.run {
                self?.handleScanBudgetExpiry()
            }
        }
    }

    private func handleScanBudgetExpiry() {
        // Only act if we're still in the pose-capture phase. A successful
        // last-pose capture cancels the budget; a failure already moved
        // us elsewhere.
        guard case .readyForPose = state else { return }

        tearDownPoseWatchers()
        faceTracker.stop()

        if capturedJpegs.isEmpty {
            // Zero poses captured in 15s — grab one emergency frame so the
            // liveness artifact still has something to hash. Better than
            // blocking the user out of the NFC step entirely.
            task = Task { [weak self] in
                guard let self else { return }
                do {
                    let frame = try await CameraSession.shared.captureOneFrame()
                    let jpeg = try LivenessFrameEncoder.encodeJpeg(frame)
                    self.capturedJpegs.append(jpeg)
                    self.lastFramesCount = 1
                    self.state = .readyForPassport(framesCount: 1)
                } catch {
                    self.state = .failed("Liveness scan timed out and emergency capture failed: \(error.localizedDescription)")
                }
            }
        } else {
            lastFramesCount = capturedJpegs.count
            state = .readyForPassport(framesCount: lastFramesCount)
        }
    }

    private func handleTrackerUpdate(status: FaceStatus, currentPose: LivenessPose) {
        // Only act while we're actually waiting for this pose.
        guard case .readyForPose(let pose, _, _) = state, pose == currentPose else {
            return
        }

        if status.matchesTargetPose {
            // Already counting down? Let it run.
            if poseHoldTask != nil { return }
            poseHoldTask = Task { [weak self] in
                try? await Task.sleep(for: Self.poseHoldDuration)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self else { return }
                    // Still in the right state and still matching? Fire.
                    if case .readyForPose(let p, _, _) = self.state, p == currentPose {
                        self.capturePose()
                    }
                }
            }
        } else {
            // Lost the pose — cancel any in-flight countdown.
            poseHoldTask?.cancel()
            poseHoldTask = nil
        }
    }

    private func tearDownPoseWatchers() {
        poseHoldTask?.cancel()
        poseHoldTask = nil
        faceTrackerCancellable?.cancel()
        faceTrackerCancellable = nil
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
                // Phase 6 — request DG2 (face photo) only when the face-match
                // flag is on. DG2 roughly doubles chip dwell time (~4-6s →
                // ~10-12s); leave it off until the producer actually consumes it.
                let result = try await PassportNFCReader.shared.readPassport(
                    mrzKey: mrzKey,
                    includeFacePhoto: SensorFeatureFlags.faceMatch
                )
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

                // Phase 6 — real .faceMatch artifact when the flag is on AND
                // the chip returned a face photo AND we have a selfie frame.
                // First-pose JPEG (straight-on) is the natural input — it
                // matches DG2's typical neutral expression.
                if SensorFeatureFlags.faceMatch {
                    guard
                        let dg2Image = passport.dg2FaceImage,
                        let dg2Hash = passport.dg2Hash,
                        let selfieJpeg = jpegs.first
                    else {
                        throw CaptureCoordinatorError.faceMatchInputsMissing
                    }
                    let faceMatch = try await FaceMatchProducer(
                        dg2Image: dg2Image,
                        dg2Hash: dg2Hash,
                        selfieJpeg: selfieJpeg
                    ).produce()
                    artifacts.append(faceMatch)
                }

                // .nfcZk + .faceMatch handled above; loop covers still-mocked
                // kinds. The registry returns nil for any kind whose feature
                // flag is on, so .faceMatch isn't double-emitted here.
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
        scanBudgetTask?.cancel()
        task = nil
        anchorTask = nil
        passportScanTask = nil
        scanBudgetTask = nil
        capturedJpegs.removeAll()
        lastFramesCount = 0
        anchorStatus = .notAttempted
        tearDownPoseWatchers()
        faceTracker.stop()
        state = .idle
    }

    // Helper for the view layer: distinguishes a scan-stage failure (where
    // lastFramesCount > 0 and the user is in the passport funnel) from a
    // pose-stage failure (where a full restart is the right affordance).
    var isAfterPoseCapture: Bool {
        lastFramesCount > 0
    }
}

enum CaptureCoordinatorError: Error {
    case duplicateArtifact(ProofArtifact.Kind)
    case faceMatchInputsMissing
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

// Pose prompts for the multi-frame active-liveness sequence. Phase 4 replaces
// the tap-to-capture UX with a continuous Vision-driven scan: FaceTracker
// reads yaw/pitch on each frame and CaptureCoordinator auto-advances when the
// user holds the target pose for POSE_HOLD_DURATION. Thresholds are in
// radians, matched to VNFaceObservation.yaw/.pitch. Order starts with
// .straight so the very first match is trivial and the user sees progress
// immediately.
//
// Front-camera mirror: AVCaptureVideoPreviewLayer mirrors the selfie preview
// for user display, but Vision runs on the non-mirrored CVPixelBuffer. The
// raw yaw sign therefore matches the user's real-world head turn (positive
// yaw = user's head rotates to the user's right = user's left ear toward
// camera). We keep thresholds in the raw Vision frame; the ellipse overlay
// flips X to compensate for the mirrored preview so the ellipse tracks the
// user's face as they see it. See FaceEllipseOverlay.
enum LivenessPose: String, CaseIterable, Equatable {
    case straight
    case left
    case right
    case up
    case down

    // Active poses driven by the scan loop. Up/down pitch detection proved
    // unreliable on iPhone 13 at arm's length — VNFaceObservation.pitch's
    // dynamic range and sign convention don't match user expectations as
    // cleanly as yaw. Keep the cases defined (thresholds below) so a future
    // Vision revision or MediaPipe drop-in can re-enable them by adding to
    // this array; the rest of the coordinator iterates `active` not `allCases`.
    static let active: [LivenessPose] = [.straight, .left, .right]

    var prompt: String {
        switch self {
        case .straight: return "Look straight at the camera"
        case .left: return "Turn your head slowly to the left"
        case .right: return "Turn your head slowly to the right"
        case .up: return "Tilt your head up"
        case .down: return "Tilt your head down"
        }
    }

    var sfSymbol: String {
        switch self {
        case .straight: return "person.fill"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }

    // Target yaw in radians (VNFaceObservation convention — positive = user's
    // head rotates to the user's right / user's left ear toward camera).
    // 0.0 where yaw is not discriminating for the pose.
    var targetYaw: Float {
        switch self {
        case .straight: return 0.0
        case .left: return -0.45
        case .right: return 0.45
        case .up, .down: return 0.0
        }
    }

    // Target pitch in radians (positive = user's chin up / face tilts back).
    var targetPitch: Float {
        switch self {
        case .straight, .left, .right: return 0.0
        case .up: return 0.35
        case .down: return -0.35
        }
    }

    // Half-window on yaw. For yaw-dominant poses (left/right) this is the
    // distance from 0 (so we treat the pose as held if yaw crosses the sign
    // boundary generously). For pitch-dominant and straight, it's the
    // allowed yaw drift while holding the pitch target.
    var toleranceYaw: Float {
        switch self {
        case .straight: return 0.18
        case .left, .right: return 0.15  // window around targetYaw
        case .up, .down: return 0.25
        }
    }

    // Half-window on pitch.
    var tolerancePitch: Float {
        switch self {
        case .straight: return 0.18
        case .left, .right: return 0.30
        case .up, .down: return 0.15
        }
    }

    // True if the observed angles fall within tolerance of the target for
    // this pose. Straight needs both yaw AND pitch near zero; yaw-dominant
    // poses require yaw past the threshold in the correct direction (and
    // pitch within tolerance); same mirror for pitch-dominant.
    func matches(yaw: Float, pitch: Float) -> Bool {
        switch self {
        case .straight:
            return abs(yaw) <= toleranceYaw && abs(pitch) <= tolerancePitch
        case .left:
            return yaw <= (targetYaw + toleranceYaw) && abs(pitch) <= tolerancePitch
        case .right:
            return yaw >= (targetYaw - toleranceYaw) && abs(pitch) <= tolerancePitch
        case .up:
            return pitch >= (targetPitch - tolerancePitch) && abs(yaw) <= toleranceYaw
        case .down:
            return pitch <= (targetPitch + tolerancePitch) && abs(yaw) <= toleranceYaw
        }
    }
}
