import Foundation
import Combine
import CryptoKit
import DeviceCheck
import FirebaseAuth
import FirebaseFirestore
import UIKit

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
        // Entered when the active profile requires .nfcZk.
        case readyForPassport(framesCount: Int)
        // NFC chip read in flight. Triggered after MRZScanView parses the
        // MRZ key; the system NFC modal is drawn by CoreNFC.
        case scanningPassport(framesCount: Int)
        // NFC read completed. Waiting for the user to tap Verify.
        case passportReady(framesCount: Int, passport: DocumentReadResult)
        // standardsec branch — profile requires faceMatch with source=
        // documentPhoto. DocumentPhotoView opens the back camera; user holds
        // their ID/passport up; Vision auto-captures the face crop.
        case readyForDocumentPhoto(framesCount: Int)
        // standardsec — face crop captured, JPEG + SHA-256 in memory only.
        case documentPhotoReady(framesCount: Int, captureJpeg: Data, captureHash: Data)
        // lowsec-attest branch — neither nfcZk nor faceMatch is required.
        // Poses captured, ready to seal App Attest + liveness only.
        case readyForVerification(framesCount: Int)
        // User tapped Verify; we're signing + sealing. `phase` tells the UI
        // which of the two we're in without making the view count seconds.
        case verifying(phase: VerifyPhase)
        case sealed(EnclaveSeal.Commitment)
        case failed(stage: FailureStage, message: String)
    }

    // Coarse stage label for `.failed`. Lets the view layer pick body copy
    // that matches what actually went wrong instead of always showing the
    // passport-scan retry message. Keep this enum small — finer detail
    // belongs in the message string.
    enum FailureStage: Equatable {
        case poseCapture       // active-liveness pose loop / emergency capture
        case livenessTimeout   // 15 s scan budget expired with zero frames
        case passportScan      // MRZ parse / NFC chip read
        case verify            // App Attest signing, anti-spoof, face-match, seal
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

    // Live Firestore subscription on the commitment doc that the server
    // writes during the queued → anchored → (anchor-failed) lifecycle.
    // Same pattern as FirestoreService.observeUser and the web's
    // subscribeToProposals. Held here so reset()/begin() can tear it down.
    private var commitmentListener: ListenerRegistration?

    // Tracks the pre-scan frame count so the retry path can restore the
    // correct `.readyForPassport(framesCount:)` state after a failure
    // without re-running the pose loop.
    private var lastFramesCount: Int = 0

    // Phase 4 — active-liveness face tracker. Exposed so the view can
    // observe @Published status for overlay rendering. Lifecycle is
    // owned by the coordinator: started on .readyForPose entry, stopped
    // when pose advances / flow ends / flow restarts.
    let faceTracker = FaceTracker()

    // Tunables driven by AppConfig (foundationmobile.json). Lazy-evaluated
    // once at first access, after AppConfig.shared has loaded the bundled
    // profile. See `liveness` block in the profile JSONs.
    static let poseHoldDuration: Duration = .milliseconds(AppConfig.shared.liveness.poseHoldMs)
    static let scanBudget: Duration = .seconds(AppConfig.shared.liveness.scanBudgetSeconds)

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
        commitmentListener?.remove()
        commitmentListener = nil
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
                    self.state = self.afterPosesState(framesCount: next)
                }
            } catch {
                self.state = .failed(stage: .poseCapture, message: String(describing: error))
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
                    self.state = self.afterPosesState(framesCount: 1)
                } catch {
                    self.state = .failed(
                        stage: .livenessTimeout,
                        message: "Liveness scan timed out and emergency capture failed: \(error.localizedDescription)"
                    )
                }
            }
        } else {
            lastFramesCount = capturedJpegs.count
            state = afterPosesState(framesCount: lastFramesCount)
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
    func scanPassport(mrzKey: MRZKey, profile: DocumentProfile) {
        // Accept from readyForPassport (fresh NFC scan) or failed at the
        // passport/verify stage (retry). Reject failures from earlier stages
        // (e.g. poseCapture) where lastFramesCount may be 0, which would
        // produce a passportReady(framesCount:0) that silently blocks verify().
        let frames: Int
        switch state {
        case .readyForPassport(let n): frames = n
        case .failed(let stage, _) where stage == .passportScan || stage == .verify:
            frames = lastFramesCount
        default: return
        }

        state = .scanningPassport(framesCount: frames)
        passportScanTask?.cancel()
        passportScanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await DocumentNFCReader.shared.readDocument(
                    mrzKey: mrzKey,
                    profile: profile,
                    includeFacePhoto: AppConfig.shared.profile.requires(.faceMatch) &&
                                      AppConfig.shared.profile.faceMatchSource == .dg2 &&
                                      profile.dg2Accessible
                )
                self.state = .passportReady(framesCount: frames, passport: result)
            } catch {
                self.state = .failed(stage: .passportScan, message: error.localizedDescription)
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

    // Called by DocumentPhotoView when the back-camera face crop is captured.
    // Holds the JPEG + hash on the state for verify() to consume.
    func documentPhotoCaptured(_ capture: DocumentPhotoCapture) {
        guard case .readyForDocumentPhoto(let framesCount) = state else { return }
        state = .documentPhotoReady(
            framesCount: framesCount,
            captureJpeg: capture.faceCropJpeg,
            captureHash: capture.faceCropHash
        )
    }

    // Branches the post-poses transition based on the active profile.
    // Hisec (NFC) → readyForPassport; standardsec (documentPhoto) →
    // readyForDocumentPhoto; lowsec-attest → readyForVerification.
    private func afterPosesState(framesCount: Int) -> State {
        let profile = AppConfig.shared.profile
        if profile.requires(.nfcZk) {
            return .readyForPassport(framesCount: framesCount)
        }
        if profile.requires(.faceMatch) && profile.faceMatchSource == .documentPhoto {
            return .readyForDocumentPhoto(framesCount: framesCount)
        }
        return .readyForVerification(framesCount: framesCount)
    }

    // User tapped Verify: sign the combined liveness payload with App Attest,
    // build the Phase 1 appAttest artifact, then per the active profile build
    // the .nfcZk / .faceMatch / .antiSpoof artifacts from whatever credential
    // was gathered (NFC chip read, document-photo capture, or nothing for
    // lowsec-attest). Fan in remaining mocks. Seal.
    // AttestationService self-heals on a stale keyId, so a ~5-8s stall on
    // first run is normal.
    func verify() {
        let framesCount: Int
        let passportData: DocumentReadResult?
        let docPhotoJpeg: Data?
        let docPhotoHash: Data?
        switch state {
        case .passportReady(let n, let passport):
            framesCount = n
            passportData = passport
            docPhotoJpeg = nil
            docPhotoHash = nil
        case .documentPhotoReady(let n, let jpeg, let hash):
            framesCount = n
            passportData = nil
            docPhotoJpeg = jpeg
            docPhotoHash = hash
        case .readyForVerification(let n):
            framesCount = n
            passportData = nil
            docPhotoJpeg = nil
            docPhotoHash = nil
        default:
            return
        }
        guard framesCount > 0 else { return }
        guard let keyId = Keychain.getAttestedKeyId() else {
            state = .needsAttestation
            return
        }

        let jpegs = capturedJpegs
        self.capturedJpegs.removeAll()  // drop the raw bytes eagerly

        task = Task { [weak self] in
            guard let self else { return }
            // Breadcrumb names the last-entered verify step. Printed
            // unconditionally on failure (NOT #if DEBUG — staging/TestFlight
            // are Release builds) so the orange-badge dead-end is no longer
            // silent: the catch below swallowed the real error into UI state
            // only, which is why device logs showed App Check / SE noise but
            // never the actual verify throw.
            var step = "start"
            do {
                self.state = .verifying(phase: .signing)

                // Liveness payload = concat of per-frame SHA-256s. Keeps the
                // signed surface small (96 B for 3 frames) while still
                // binding all frames into the commitment.
                step = "liveness-artifact"
                let perFrameHashes = jpegs.map { Data(SHA256.hash(data: $0)) }
                let combinedPayload = perFrameHashes.reduce(Data(), +)
                let liveness = try await ProofArtifactBuilder.build(
                    kind: .liveness,
                    payload: combinedPayload
                )

                step = "appAttest-assertion"
                let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
                let appAttestPayload = Data("appAttest:\(keyId):\(nowMs)".utf8)
                let appAttest = try await ProofArtifactBuilder.build(
                    kind: .appAttest,
                    payload: appAttestPayload
                )

                var artifacts: [ProofArtifact] = [appAttest, liveness]

                // Phase 3a — real .nfcZk artifact when the active profile
                // requires it AND the user came through the NFC-scan funnel.
                if AppConfig.shared.profile.requires(.nfcZk), let passport = passportData {
                    step = "nfcZk-artifact"
                    let nfcArtifact = try await PassportNfcProducer(documentData: passport).produce()
                    artifacts.append(nfcArtifact)
                }

                // Phase 6 — real .faceMatch artifact when the active profile
                // requires it. Reference image source is profile-driven:
                //   .dg2           → bind selfie ↔ chip's DG2 photo
                //   .documentPhoto → bind selfie ↔ back-camera capture of doc
                if AppConfig.shared.profile.requires(.faceMatch) {
                    step = "faceMatch-artifact"
                    let source = AppConfig.shared.profile.faceMatchSource
                    let referenceImage: UIImage
                    let referenceHash: Data
                    let producerSource: FaceMatchSource
                    switch source {
                    case .dg2:
                        guard
                            let dg2Image = passportData?.dg2FaceImage,
                            let dg2Hash = passportData?.dg2Hash
                        else {
                            throw CaptureCoordinatorError.faceMatchInputsMissing
                        }
                        referenceImage = dg2Image
                        referenceHash = dg2Hash
                        producerSource = .dg2
                    case .documentPhoto:
                        guard
                            let docJpeg = docPhotoJpeg,
                            let docHash = docPhotoHash,
                            let docImage = UIImage(data: docJpeg)
                        else {
                            throw CaptureCoordinatorError.faceMatchInputsMissing
                        }
                        referenceImage = docImage
                        referenceHash = docHash
                        producerSource = .documentPhoto
                    case .none:
                        throw CaptureCoordinatorError.faceMatchInputsMissing
                    case .mdl:
                        // Task 3: mDL portrait retrieval via ProximityReader
                        throw CaptureCoordinatorError.faceMatchInputsMissing
                    }
                    guard let selfieJpeg = jpegs.first else {
                        throw CaptureCoordinatorError.faceMatchInputsMissing
                    }
                    let faceMatch = try await FaceMatchProducer(
                        referenceImage: referenceImage,
                        referenceHash: referenceHash,
                        source: producerSource,
                        selfieJpeg: selfieJpeg,
                        threshold: AppConfig.shared.faceMatch.cosineThreshold
                    ).produce()
                    artifacts.append(faceMatch)
                }

                // Phase 5 — real .antiSpoof artifact when required. Reuses
                // captured selfie JPEGs (no fresh camera capture); Silent-Face
                // inference runs on cropped 80x80 face regions.
                if AppConfig.shared.profile.requires(.antiSpoof) {
                    step = "antiSpoof-artifact"
                    let antiSpoof = try await AntiSpoofProducer(
                        selfieJpegs: jpegs,
                        threshold: AppConfig.shared.antiSpoof.minScore
                    ).produce()
                    artifacts.append(antiSpoof)
                }

                // Loop covers still-mocked kinds. The registry returns nil
                // for any kind already emitted above, so we don't double-emit.
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
                // Bind the user identity into the seal hash. Server's
                // canonicalSealBytes(uid, artifacts) mirrors this; without
                // matching uids the seal-mismatch gate rejects on submit
                // (and for legitimate sessions the uid is always present
                // because submitAnchor itself requires Firebase Auth).
                step = "seal-uid"
                let deployment = DeploymentService.shared.current
                let app = DeploymentService.shared.currentFirebaseApp
                guard let uid = Auth.auth(app: app).currentUser?.uid else {
                    // Firebase Auth state is PER-APP: signing into the default
                    // (prod) app does NOT authenticate the named staging app.
                    // Surface which app/deployment we resolved so a nil uid is
                    // diagnosable instead of a generic "not signed in".
                    print("[CaptureCoordinator] verify FAILED at step=seal-uid: no currentUser on FirebaseApp '\(app.name)' (deployment='\(deployment.id)', plist='\(deployment.plist)')")
                    self.state = .failed(stage: .verify, message: "not signed in")
                    return
                }
                let commitment = EnclaveSeal.seal(uid: uid, artifacts: artifacts)
                self.state = .sealed(commitment)
                self.submitAnchor(commitment: commitment, artifacts: artifacts)
            } catch {
                print("[CaptureCoordinator] verify FAILED at step=\(step): \(error)")
                self.state = .failed(stage: .verify, message: String(describing: error))
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
            // 2026-04-26 security review M-H-4: build the biometric seal
            // sidecar by Face-ID-signing commitment.hashHex with the
            // Secure-Enclave-bound, biometryCurrentSet-protected key.
            // The signature is proof the user explicitly authorized
            // THIS commitment (not just the verification session). A
            // graceful-degradation fallback to seal=nil is intentional
            // — biometrics may be unavailable on this device, or the
            // user may cancel; the canonical-bytes uid binding (Phase
            // 1.C) plus the per-artifact App Attest assertions still
            // protect the commitment, so a missing seal is a soft
            // signal rather than a hard precondition.
            let biometricSeal = await Self.buildBiometricSeal(commitment: commitment)
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
                },
                biometricSeal: biometricSeal,
                passportBiometricSeal: nil
            )
            do {
                let result = try await FunctionsService.shared.anchorCommitment(req)
                self?.anchorStatus = .completed(result)
                if result.status == "queued", let path = result.commitmentDocPath {
                    self?.observeCommitmentDoc(at: path, baseResult: result)
                }
            } catch {
                self?.anchorStatus = .failed(String(describing: error))
            }
        }
    }

    @MainActor
    private static func buildBiometricSeal(
        commitment: EnclaveSeal.Commitment
    ) async -> AnchorCommitmentRequest.BiometricSealPayload? {
        let sealer = BiometricSealer.shared
        guard sealer.isAvailable else { return nil }
        let payload = Data(commitment.commitmentHashHex.utf8)
        do {
            let signature = try await sealer.sign(
                payload: payload,
                prompt: "Sign your humanity commitment"
            )
            let publicKey = try sealer.publicKeyBase64()
            return AnchorCommitmentRequest.BiometricSealPayload(
                publicKeyB64: publicKey,
                signatureB64: signature,
                signedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
        } catch BiometricSealError.userCancelled {
            // User explicitly cancelled the second prompt. They already
            // approved verification at entry-gate, so still submit
            // (sealing is best-effort here, the entry gate is the
            // load-bearing consent moment).
            return nil
        } catch BiometricSealError.keyInvalidated {
            // Biometrics changed mid-session. Reset the key so the next
            // attempt regenerates; submit unsealed this round.
            sealer.resetKey()
            return nil
        } catch {
            // Generic signing failure — log only in debug. The submit
            // proceeds without the seal so the verification round
            // doesn't dead-end.
            #if DEBUG
            print("[CaptureCoordinator] biometric seal failed: \(error)")
            #endif
            return nil
        }
    }

    // Listen for the server's queued → anchored (or anchor-failed) write
    // on the Firestore commitment doc. Same pattern as the web's
    // subscribeToProposals + FirestoreService.observeUser. The callable
    // returns immediately with status:"queued"; the on-chain task finishes
    // async and only the doc reflects the final outcome.
    private func observeCommitmentDoc(at path: String, baseResult: AnchorCommitmentResult) {
        commitmentListener?.remove()
        let db = Firestore.firestore()
        commitmentListener = db.document(path).addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let data = snap?.data() else { return }
                let status = data["status"] as? String ?? baseResult.status
                let slot: Int64? = (data["slot"] as? Int64)
                    ?? (data["slot"] as? NSNumber)?.int64Value
                let txSig = data["txSignature"] as? String
                let reason = data["reason"] as? String ?? baseResult.reason
                self.anchorStatus = .completed(AnchorCommitmentResult(
                    accepted: baseResult.accepted,
                    status: status,
                    slot: slot,
                    txSignature: txSig,
                    commitmentDocPath: baseResult.commitmentDocPath,
                    recordAddress: baseResult.recordAddress,
                    reason: reason
                ))
                if status == "anchored" || status == "anchor-failed" {
                    self.commitmentListener?.remove()
                    self.commitmentListener = nil
                }
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
        commitmentListener?.remove()
        commitmentListener = nil
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

    // Active poses come from the active profile (`liveness.activePoses`).
    // Up/down pitch detection has been historically unreliable on iPhone 13
    // at arm's length, so default profiles list only [straight, left, right];
    // re-enable per-profile by adding to the JSON array.
    static var active: [LivenessPose] {
        AppConfig.shared.liveness.activePoses.compactMap { LivenessPose(rawValue: $0) }
    }

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

    // Pose thresholds come from AppConfig (foundationmobile.json). Yaw
    // convention: positive = user's head rotates to their right.
    private var poseConfig: AppConfig.Liveness.Pose? {
        AppConfig.shared.liveness.poses[rawValue]
    }
    var targetYaw: Float       { poseConfig?.yaw ?? 0 }
    var targetPitch: Float     { poseConfig?.pitch ?? 0 }
    var toleranceYaw: Float    { poseConfig?.yawTolerance ?? 0.18 }
    var tolerancePitch: Float  { poseConfig?.pitchTolerance ?? 0.18 }

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
