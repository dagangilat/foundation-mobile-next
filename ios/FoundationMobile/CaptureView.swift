import SwiftUI
import AVFoundation
import UIKit

struct CaptureView: View {
    @StateObject private var camera = CameraSession.shared
    @StateObject private var coordinator = CaptureCoordinator.shared
    @State private var warmupTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
        }
        .navigationTitle("Verify humanity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
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
            liveCapturePanel
        }
        #endif
    }

    private var liveCapturePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            CameraPreview(session: CameraSession.shared.underlyingSession)
                .frame(maxWidth: .infinity)
                .aspectRatio(3.0/4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))

            statusLine

            Button(action: { coordinator.captureAndSeal() }) {
                Text(buttonLabel)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGreen)
                    .cornerRadius(12)
                    .opacity(buttonEnabled ? 1.0 : 0.5)
            }
            .disabled(!buttonEnabled)

            Spacer()
        }
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundStyle(statusColor)
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var statusIcon: String {
        switch coordinator.state {
        case .idle: return "camera"
        case .unsupported, .needsAttestation: return "exclamationmark.triangle.fill"
        case .capturing, .signing, .sealing: return "hourglass"
        case .sealed: return "checkmark.seal.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch coordinator.state {
        case .sealed: return Theme.brandGreen
        case .failed, .unsupported, .needsAttestation: return .orange
        default: return Theme.muted
        }
    }

    private var statusLabel: String {
        switch coordinator.state {
        case .idle: return "Tap capture to start"
        case .unsupported: return "App Attest unsupported on this device"
        case .needsAttestation: return "App Attest not completed — return home and wait"
        case .capturing: return "Capturing frame…"
        case .signing: return "Signing with App Attest…"
        case .sealing: return "Sealing commitment…"
        case .sealed(let c): return "Sealed — \(shortHash(c.commitmentHashHex))"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }

    private var buttonLabel: String {
        switch coordinator.state {
        case .capturing: return "Capturing…"
        case .signing: return "Signing…"
        case .sealing: return "Sealing…"
        case .sealed: return "Capture again"
        default: return "Capture"
        }
    }

    private var buttonEnabled: Bool {
        switch coordinator.state {
        case .capturing, .signing, .sealing: return false
        case .unsupported, .needsAttestation: return false
        default: break
        }
        switch camera.state {
        case .authorizing, .unauthorized, .failed: return false
        default: return true
        }
    }

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
