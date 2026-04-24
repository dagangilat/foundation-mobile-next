import SwiftUI
import AVFoundation
import UIKit

struct CaptureView: View {
    @StateObject private var camera = CameraSession.shared
    @StateObject private var coordinator = CaptureCoordinator.shared
    @State private var warmupTask: Task<Void, Never>?
    @State private var isShowingMRZScan = false
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
            // Auto-dismiss back to HomeView on success so the sealed
            // commitment row is the next thing the user sees. iOS-16-style
            // single-parameter onChange — iOS 17's (initial, _, _) would
            // fail the deployment target check.
            if case .sealed = newValue {
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    dismiss()
                }
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
            // preview isn't useful — swap to the NFC host view.
            if shouldShowNFCPanel {
                NFCScanView(coordinator: coordinator)
            } else {
                liveCapturePanel
            }
        }
        #endif
    }

    // True once we've left the pose-capture path — i.e. we're in the
    // passport scan funnel or later. Drives the swap between the camera
    // preview and the NFC host screen.
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

    private var liveCapturePanel: some View {
        VStack(spacing: 16) {
            CameraPreview(session: CameraSession.shared.underlyingSession)
                .frame(maxWidth: .infinity)
                .aspectRatio(3.0/4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))

            progressDots

            promptBlock

            primaryButton

            Spacer(minLength: 0)
        }
    }

    // Three dots tracking pose progress. Filled = captured, empty = pending,
    // filled-with-halo = current pose.
    @ViewBuilder
    private var progressDots: some View {
        let total = LivenessPose.allCases.count
        let captured = currentCapturedCount
        HStack(spacing: 10) {
            ForEach(0..<total, id: \.self) { i in
                let isCaptured = i < captured
                let isCurrent = i == captured && activePoseIndex == i
                Circle()
                    .fill(isCaptured ? Theme.brandGreen : Theme.muted.opacity(0.3))
                    .frame(width: isCurrent ? 14 : 10, height: isCurrent ? 14 : 10)
                    .overlay(
                        Circle()
                            .stroke(Theme.brandGreen, lineWidth: isCurrent ? 2 : 0)
                            .frame(width: 22, height: 22)
                    )
                    .animation(.easeInOut(duration: 0.2), value: captured)
            }
            Spacer()
            Text(progressSummary)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 4)
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
                    .foregroundStyle(.white)
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
                    .foregroundStyle(.white)
                Spacer()
            }
        case .scanningPassport:
            HStack(spacing: 12) {
                ProgressView().progressViewStyle(.circular).tint(Theme.brandGreen)
                Text("Reading passport chip…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
        case .passportReady(_, let passport):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("Passport scanned (\(passport.issuingCountryCode) \(passport.passportNumberMasked)) — ready to verify")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
        case .verifying(let phase):
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Theme.brandGreen)
                Text(phase == .signing ? "Signing with App Attest…" : "Sealing commitment…")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
        case .sealed(let c):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.brandGreen)
                Text("Sealed — \(shortHash(c.commitmentHashHex))")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
        case .failed(let msg):
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
            bigGreenButton(title: "Capture") { coordinator.capturePose() }
        case .readyForPassport:
            bigGreenButton(title: "Scan passport") { isShowingMRZScan = true }
        case .scanningPassport:
            bigGreenButton(title: "Reading chip…", enabled: false) { }
        case .passportReady:
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
            bigGreenButton(title: "Done", enabled: false) { }
        case .idle, .needsAttestation, .unsupported:
            EmptyView()
        }
    }

    private func bigGreenButton(title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.brandGreen)
                .cornerRadius(12)
                .opacity(enabled ? 1.0 : 0.5)
        }
        .disabled(!enabled)
    }

    // MARK: — derived values

    private var currentCapturedCount: Int {
        switch coordinator.state {
        case .readyForPose(_, let captured, _): return captured
        case .readyForPassport(let n): return n
        case .scanningPassport(let n): return n
        case .passportReady(let n, _): return n
        case .verifying, .sealed: return LivenessPose.allCases.count
        default: return 0
        }
    }

    private var activePoseIndex: Int {
        if case .readyForPose(_, let captured, _) = coordinator.state { return captured }
        return -1
    }

    private var progressSummary: String {
        let total = LivenessPose.allCases.count
        switch coordinator.state {
        case .readyForPose(_, let captured, _): return "\(captured) of \(total)"
        case .readyForPassport, .scanningPassport, .passportReady:
            return "\(total) of \(total) · passport"
        case .verifying, .sealed: return "done"
        default: return ""
        }
    }

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
                .foregroundStyle(.white)
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
                    .foregroundStyle(.black)
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
                .foregroundStyle(.white)
            Text(msg)
                .font(.callout)
                .foregroundStyle(Theme.muted)
        }
    }

    private var simulatorBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulator")
                .font(.headline)
                .foregroundStyle(.white)
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
