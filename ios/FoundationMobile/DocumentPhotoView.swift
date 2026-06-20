import SwiftUI
import AVFoundation
import Vision
import UIKit
import CoreImage
import CoreGraphics
import CryptoKit

// Phase 6 (standardsec) — back-camera capture of the document's face region.
// Used when the active profile's faceMatchSource = .documentPhoto, i.e. the
// credential has no NFC chip (older passports, US driver licenses, state IDs).
//
// Pipeline per frame:
//   1. Back-camera VideoDataOutput → CVPixelBuffer
//   2. VNDetectFaceRectanglesRequest finds the face region inside the doc
//   3. Once face confidence ≥ minConfidence AND held stable (bbox center jitter
//      ≤ STABILITY_PIXELS) for HOLD_DURATION ms → auto-capture
//   4. Crop the face region (with 25% padding) from the captured frame
//   5. Encode the crop as JPEG; hand back JPEG bytes + SHA-256 hash to caller
//
// The caller (CaptureCoordinator.documentPhotoCaptured) treats the JPEG
// bytes as the "reference image" for FaceMatchProducer. Hash binds the
// .faceMatch artifact to this exact crop. Image bytes never leave the device.

struct DocumentPhotoCapture: Sendable {
    let faceCropJpeg: Data
    let faceCropHash: Data
    let referenceImage: UIImage
}

struct DocumentPhotoView: View {
    let onCaptured: (DocumentPhotoCapture) -> Void
    let onCancel: () -> Void

    @StateObject private var session = DocumentPhotoSession()
    @State private var statusText: String = "Hold your document up to the back camera so the photo is visible."

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(spacing: 16) {
                    DocumentPhotoCameraPreview(session: session.captureSession)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3.0/4.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))

                    Text(statusText)
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                    Button {
                        session.requestManualCapture()
                    } label: {
                        Text("Capture now")
                            .font(.headline)
                            .foregroundStyle(Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.brandGreen)
                            .cornerRadius(12)
                            .opacity(session.canManualCapture ? 1.0 : 0.5)
                    }
                    .disabled(!session.canManualCapture)

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
            .navigationTitle("Capture Document Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.brandGreen)
                }
            }
        }
        .onAppear {
            session.onCaptured = { capture in
                session.stop()
                statusText = "Captured. Returning to liveness…"
                onCaptured(capture)
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
final class DocumentPhotoSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let configureQueue = DispatchQueue(label: "com.foundationglobal.mobile.docphoto.config")
    private let sampleQueue = DispatchQueue(label: "com.foundationglobal.mobile.docphoto.sample", qos: .userInitiated)

    var onCaptured: ((DocumentPhotoCapture) -> Void)?
    var onStatus: ((String) -> Void)?

    @Published private(set) var canManualCapture: Bool = false

    private var configured = false
    private var stopped = false

    // Auto-capture pose-hold logic. We track the last detected face bbox
    // center; when consecutive frames stay within STABILITY_PIXELS of each
    // other AND confidence ≥ minConfidence for HOLD_DURATION_MS, fire.
    private static let HOLD_DURATION_MS: Int = 500
    private static let STABILITY_FRACTION: CGFloat = 0.04  // ~4% of frame width

    // Don't auto-capture for the first few seconds after the camera opens, so
    // the user has time to line the document's photo page up in frame. Manual
    // "Capture now" still fires immediately.
    private static let ARMING_DELAY_S: TimeInterval = 3
    private var armedAt: Date?

    private var stableSince: Date?
    private var lastCenter: CGPoint?
    private var pendingManualCapture = false
    private var lastFrame: CVPixelBuffer?
    private var lastFaceBBox: CGRect?

    func start() {
        armedAt = Date().addingTimeInterval(Self.ARMING_DELAY_S)
        Task { await ensureRunning() }
    }

    func stop() {
        stopped = true
        guard captureSession.isRunning else { return }
        configureQueue.async { [captureSession] in captureSession.stopRunning() }
    }

    func requestManualCapture() {
        pendingManualCapture = true
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
            onStatus?("Camera permission denied. Enable it in Settings to verify.")
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
                domain: "DocumentPhotoSession", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Back camera not available."]
            )
        }
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) { captureSession.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }

    fileprivate nonisolated func ingest(pixelBuffer: CVPixelBuffer) {
        let detection = Self.detectFace(pixelBuffer: pixelBuffer)
        Task { @MainActor [weak self] in
            guard let self, !self.stopped else { return }
            self.handleDetection(pixelBuffer: pixelBuffer, detection: detection)
        }
    }

    private func handleDetection(pixelBuffer: CVPixelBuffer, detection: FaceDetection?) {
        if stopped { return }
        lastFrame = pixelBuffer
        lastFaceBBox = detection?.boundingBox

        guard let detection else {
            stableSince = nil
            lastCenter = nil
            canManualCapture = false
            onStatus?("Hold the document so its photo is fully visible.")
            return
        }

        let confidence = detection.confidence
        let minConf = AppConfig.shared.liveness.minConfidence
        guard confidence >= minConf else {
            stableSince = nil
            lastCenter = nil
            canManualCapture = false
            onStatus?("Move closer / improve lighting (confidence \(String(format: "%.2f", confidence)))")
            return
        }

        canManualCapture = true

        let center = CGPoint(x: detection.boundingBox.midX, y: detection.boundingBox.midY)
        if let last = lastCenter {
            let dx = abs(center.x - last.x)
            let dy = abs(center.y - last.y)
            if dx < Self.STABILITY_FRACTION && dy < Self.STABILITY_FRACTION {
                if stableSince == nil { stableSince = Date() }
            } else {
                stableSince = Date()
            }
        } else {
            stableSince = Date()
        }
        lastCenter = center

        let elapsedMs = stableSince.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        let armed = armedAt.map { Date() >= $0 } ?? true
        if (elapsedMs >= Self.HOLD_DURATION_MS && armed) || pendingManualCapture {
            pendingManualCapture = false
            performCapture(pixelBuffer: pixelBuffer, faceBBox: detection.boundingBox)
        } else if !armed {
            onStatus?("Line up the photo page…")
        } else {
            onStatus?("Hold steady… (\(elapsedMs)ms)")
        }
    }

    private func performCapture(pixelBuffer: CVPixelBuffer, faceBBox: CGRect) {
        guard !stopped else { return }
        stopped = true
        guard let cropped = Self.cropFace(pixelBuffer: pixelBuffer, normalizedBBox: faceBBox) else {
            onStatus?("Could not crop face region; please try again.")
            stopped = false
            return
        }
        let uiImage = UIImage(cgImage: cropped)
        guard let jpeg = uiImage.jpegData(compressionQuality: 0.85) else {
            onStatus?("Could not encode capture; please try again.")
            stopped = false
            return
        }
        let hash = Data(SHA256.hash(data: jpeg))
        let cap = DocumentPhotoCapture(
            faceCropJpeg: jpeg,
            faceCropHash: hash,
            referenceImage: uiImage
        )
        onCaptured?(cap)
    }

    // MARK: — Vision (nonisolated)

    fileprivate struct FaceDetection {
        let boundingBox: CGRect  // normalized, Vision convention (origin BL)
        let confidence: Float
    }

    private nonisolated static func detectFace(pixelBuffer: CVPixelBuffer) -> FaceDetection? {
        let request = VNDetectFaceRectanglesRequest()
        if #available(iOS 15.0, *) {
            request.revision = VNDetectFaceRectanglesRequestRevision3
        }
        // Back camera, portrait orientation: pixel buffer arrives rotated
        // 90° CCW relative to the upright image the user sees. .right is
        // the standard incantation for back-facing portrait.
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let face = (request.results ?? []).max(by: { $0.confidence < $1.confidence }) else {
            return nil
        }
        return FaceDetection(boundingBox: face.boundingBox, confidence: face.confidence)
    }

    private static func cropFace(pixelBuffer: CVPixelBuffer, normalizedBBox: CGRect) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(.right)
        let context = CIContext(options: nil)
        let extent = ciImage.extent
        let pad: CGFloat = 0.25
        let bb = normalizedBBox
        // Vision normalized coords: origin bottom-left. Convert to pixels
        // in the oriented (.right-rotated) image space.
        let rect = CGRect(
            x: max(0, (bb.minX - pad * bb.width) * extent.width),
            y: max(0, (bb.minY - pad * bb.height) * extent.height),
            width: min(extent.width, (1 + 2 * pad) * bb.width * extent.width),
            height: min(extent.height, (1 + 2 * pad) * bb.height * extent.height)
        )
        guard rect.width > 1, rect.height > 1 else { return nil }
        let cropped = ciImage.cropped(to: rect)
        return context.createCGImage(cropped, from: cropped.extent)
    }
}

extension DocumentPhotoSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        ingest(pixelBuffer: pixelBuffer)
    }
}

private struct DocumentPhotoCameraPreview: UIViewRepresentable {
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
