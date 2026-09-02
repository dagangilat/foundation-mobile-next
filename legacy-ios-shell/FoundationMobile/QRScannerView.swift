import SwiftUI
import AVFoundation
import UIKit

// Phase — desktop pairing entry point. Back-camera AVCaptureSession with an
// AVCaptureMetadataOutput configured for `.qr`. On detection the view
// dismisses and hands the decoded string up. Single-shot: stops the session
// the moment a code is read so the camera tears down promptly.
//
// HARD INVARIANT: the QR payload is a short pairing code only. No image
// frames are persisted, no payload bytes leave the device beyond the call
// site's normal route (claimPairingSession).

struct QRScannerView: View {
    let onScanned: (String) -> Void
    let onCancel: () -> Void

    @StateObject private var session = QRScanSession()
    @State private var statusText: String = "Point the camera at the desktop QR code."

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    QRCameraPreview(session: session.captureSession)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))

                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Pair Desktop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.brandGreen)
                }
            }
        }
        .onAppear {
            session.onScanned = { code in
                session.stop()
                statusText = "Pairing…"
                onScanned(code)
            }
            session.onStatus = { msg in statusText = msg }
            session.start()
        }
        .onDisappear {
            session.stop()
        }
    }
}

@MainActor
final class QRScanSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private let configureQueue = DispatchQueue(label: "com.foundationglobal.mobile.qr")

    var onScanned: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    private var configured = false

    func start() {
        Task { await ensureRunning() }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        configureQueue.async { [captureSession] in captureSession.stopRunning() }
    }

    private func ensureRunning() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let authorized: Bool
        switch status {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard authorized else {
            onStatus?("Camera permission denied. Enable it in Settings to pair.")
            return
        }

        if !configured {
            do {
                try configure()
                configured = true
            } catch {
                onStatus?("Camera setup failed: \(error.localizedDescription)")
                return
            }
        }

        if !captureSession.isRunning {
            configureQueue.async { [captureSession] in captureSession.startRunning() }
        }
    }

    private func configure() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else {
            throw NSError(
                domain: "QRScanSession", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Back camera not available."]
            )
        }
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) { captureSession.addInput(input) }

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            // Set metadata types AFTER addOutput; otherwise availableMetadataObjectTypes
            // hasn't been populated and the array is empty.
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
        }
    }
}

extension QRScanSession: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              first.type == .qr,
              let value = first.stringValue,
              !value.isEmpty else { return }
        Task { @MainActor [weak self] in
            self?.onScanned?(value)
        }
    }
}

private struct QRCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
