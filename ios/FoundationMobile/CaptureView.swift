import SwiftUI
import AVFoundation
import UIKit

struct CaptureView: View {
    @StateObject private var camera = CameraSession.shared
    @StateObject private var coordinator = CaptureCoordinator.shared
    @State private var warmupTask: Task<Void, Never>?
    @State private var isShowingMRZScan = false
    @State private var isShowingDocPhoto = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .navigationTitle("Verify humanity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            coordinator.begin()
            #if !targetEnvironment(simulator)
            // Hold an open subscription so the AVCaptureSession starts and the
            // preview layer has frames to render. Cancelling on disappear lets
            // CameraSession stop when the last consumer leaves.
            warmupTask = Task {
                for await _ in CameraSession.shared.frames() {
                    if Task.isCancelled { break }
                }
            }
            #endif
        }
        .onDisappear {
            warmupTask?.cancel()
            warmupTask = nil
        }
        .onChange(of: coordinator.state) { newValue in
            // Auto-dismiss back to HomeView the moment the user-input
            // stages are done. .verifying is the first state where
            // nothing on screen needs the camera or the user — it's
            // pure compute (App Attest assertions per artifact, hash,
            // local seal) followed by the on-chain anchor task. Send
            // the user home immediately; the verifyHumanityButton +
            // verification badges progressively reflect signing /
            // sealing / anchoring states as each lands. Keeping
            // .sealed as a defensive fallback in case any path skips
            // the .verifying transition.
            switch newValue {
            case .verifying:
                dismiss()
            case .sealed:
                Task {
                    try? await Task.sleep(for: .milliseconds(AppConfig.shared.captureView.postSealDismissMs))
                    dismiss()
                }
            default:
                break
            }
        }
        .sheet(isPresented: $isShowingMRZScan) {
            MRZScanView(
                onParsed: { key in
                    isShowingMRZScan = false
                    coordinator.scanPassport(mrzKey: key)
                },
                onCancel: {
                    isShowingMRZScan = false
                }
            )
        }
        .sheet(isPresented: $isShowingDocPhoto) {
            DocumentPhotoView(
                onCaptured: { capture in
                    isShowingDocPhoto = false
                    coordinator.documentPhotoCaptured(capture)
                },
                onCancel: { isShowingDocPhoto = false }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        #if targetEnvironment(simulator)
        simulatorBanner
        #else
        switch camera.state {
        case .unauthorized:
            unauthorizedBanner
        case .failed(let msg):
            failedBanner(msg)
        default:
            // Once we leave the pose-capture phase the live camera
            // preview isn't useful — swap to the NFC host view, passing
            // the MRZ-sheet trigger closure so the "Scan passport" CTA
            // and the retry path can open MRZScanView without CaptureView
            // knowing the NFC panel's internal state machine.
            if shouldShowNFCPanel {
                NFCScanView(coordinator: coordinator) {
                    isShowingMRZScan = true
                }
            } else {
                liveCapturePanel
            }
        }
        #endif
    }

    // True once we've left the pose-capture path — i.e. we're in the
    // passport scan funnel or later. Drives the swap between the camera
    // preview and the NFC host screen. Document-photo flow stays in the
    // live capture panel (with the back-camera modal sheet on top).
    private var shouldShowNFCPanel: Bool {
        switch coordinator.state {
        case .readyForPassport, .scanningPassport, .passportReady:
            return true
        case .failed:
            // After a passport-scan failure, stay on the NFC host so the
            // retry button is visible.
            return coordinator.isAfterPoseCapture
        default:
            return false
        }
    }

    // Phase 4 — continuous active-liveness panel. The camera preview is
    // the stage; FaceEllipseOverlay tracks the user's face; PosePromptBar
    // announces the current head-pose ask; PoseProgressBar runs across
    // the whole capture. No capture button during normal flow — the
    // coordinator auto-advances on pose-held.
    private var liveCapturePanel: some View {
        VStack(spacing: 16) {
            ZStack {
                CameraPreview(session: CameraSession.shared.underlyingSession)
                FaceEllipseOverlay(faceStatus: coordinator.faceTracker.status)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0/4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))

            if case .readyForPose(let pose, let captured, let total) = coordinator.state {
                PosePromptBar(pose: pose, faceStatus: coordinator.faceTracker.status)
                PoseProgressBar(captured: captured, total: total)
            } else {
                promptBlock
            }

            primaryButton

            Spacer(minLength: 0)
        }
    }

    // Main instruction to the user — big, high-contrast.
    @ViewBuilder
    private var promptBlock: some View {
        switch coordinator.state {
        case .readyForPose(let pose, _, _):
            HStack(spacing: 12) {
                Image(systemName: pose.sfSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text(pose.prompt)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        case .readyForPassport(let n):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("\(n) frames captured — scan your passport next")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .scanningPassport:
            HStack(spacing: 12) {
                ProgressView().progressViewStyle(.circular).tint(Theme.brandGreen)
                Text("Reading passport chip…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .passportReady(_, let passport):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("Passport scanned (\(passport.issuingCountryCode) \(passport.passportNumberMasked)) — ready to verify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .readyForDocumentPhoto(let n):
            HStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("\(n) frames captured — capture your document next")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .documentPhotoReady:
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("Document photo captured — ready to verify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .readyForVerification(let n):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("\(n) frames captured — ready to verify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .verifying(let phase):
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.brandGreen)
                Text(phase == .signing ? "Signing with App Attest…" : "Sealing commitment…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .sealed(let c):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("Sealed — \(shortHash(c.commitmentHashHex))")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
        case .failed(_, let msg):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        case .needsAttestation:
            Text("App Attest not completed — return home and wait for it to finish, then come back.")
                .font(.callout)
                .foregroundStyle(Theme.muted)
        case .unsupported:
            Text("App Attest is unsupported on this device.")
                .font(.callout)
                .foregroundStyle(.orange)
        case .idle:
            Text("Starting…")
                .font(.callout)
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch coordinator.state {
        case .readyForPose:
            // Phase 4 — no manual Capture button during the pose loop.
            // CaptureCoordinator auto-advances on a 500ms pose hold.
            EmptyView()
        case .readyForPassport:
            bigGreenButton(title: "Scan passport") { isShowingMRZScan = true }
        case .scanningPassport:
            bigGreenButton(title: "Reading chip…", enabled: false) { }
        case .passportReady:
            bigGreenButton(title: "Verify") { coordinator.verify() }
        case .readyForDocumentPhoto:
            bigGreenButton(title: "Capture document") { isShowingDocPhoto = true }
        case .documentPhotoReady, .readyForVerification:
            bigGreenButton(title: "Verify") { coordinator.verify() }
        case .verifying:
            bigGreenButton(title: verifyButtonLabel, enabled: false) { }
        case .failed:
            // The NFC host renders its own retry button when it's visible;
            // fall back to the full-restart button for pre-scan failures.
            if coordinator.isAfterPoseCapture {
                EmptyView()
            } else {
                bigGreenButton(title: "Retry") { coordinator.begin() }
            }
        case .sealed:
            // Auto-dismiss is set up in .onChange above, but it relies on
            // a state TRANSITION while this view is mounted. If the view
            // re-enters in .sealed state, .onChange never fires and the
            // user is stuck. Make Done tappable so manual exit always
            // works.
            bigGreenButton(title: "Done") { dismiss() }
        case .idle, .needsAttestation, .unsupported:
            EmptyView()
        }
    }

    private func bigGreenButton(title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.brandGreen)
                .cornerRadius(12)
                .opacity(enabled ? 1.0 : 0.5)
        }
        .disabled(!enabled)
    }

    // MARK: — derived values

    private var verifyButtonLabel: String {
        if case .verifying(let phase) = coordinator.state {
            return phase == .signing ? "Signing…" : "Sealing…"
        }
        return "Working…"
    }

    // MARK: — error banners (unchanged)

    private var unauthorizedBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera access required")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text("Foundation needs the front camera to verify your humanity. Enable camera access in Settings.")
                .font(.callout)
                .foregroundStyle(Theme.muted)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGreen)
                    .cornerRadius(12)
            }
        }
    }

    private func failedBanner(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera failed")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(msg)
                .font(.callout)
                .foregroundStyle(Theme.muted)
        }
    }

    private var simulatorBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulator")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text("Phase 2 capture requires a real device: App Attest and the front camera aren't available in the simulator.")
                .font(.callout)
                .foregroundStyle(Theme.muted)
        }
    }

    private func shortHash(_ hex: String) -> String {
        guard hex.count > 16 else { return hex }
        let first = hex.prefix(12)
        let last = hex.suffix(4)
        return "\(first)…\(last)"
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
