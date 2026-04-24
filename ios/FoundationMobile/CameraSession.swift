import Foundation
import AVFoundation
import CoreVideo
import CoreMedia

// Shared front-camera capture pipeline for Phases 4 (liveness), 5 (anti-spoof),
// and 6 (face match). One AVCaptureSession, many consumers: each call to
// `frames()` returns an AsyncStream that receives every frame until the
// consumer cancels. This avoids three competing camera sessions and keeps
// the three sensor implementations cleanly separated.

struct FrameBuffer: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime
}

@MainActor
final class CameraSession: NSObject, ObservableObject {
    static let shared = CameraSession()

    enum State: Equatable {
        case idle
        case authorizing
        case unauthorized
        case running
        case failed(String)
    }

    enum CameraError: Error {
        case noFrontCamera
    }

    @Published private(set) var state: State = .idle

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(
        label: "com.foundationglobal.mobile.camera",
        qos: .userInitiated
    )

    private var continuations: [UUID: AsyncStream<FrameBuffer>.Continuation] = [:]
    private var isConfigured = false

    func frames() -> AsyncStream<FrameBuffer> {
        let id = UUID()
        return AsyncStream { cont in
            continuations[id] = cont
            cont.onTermination = { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.continuations.removeValue(forKey: id)
                    if self.continuations.isEmpty {
                        self.stop()
                    }
                }
            }
            Task { await self.ensureRunning() }
        }
    }

    private func ensureRunning() async {
        if case .running = state { return }
        state = .authorizing

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let authorized: Bool
        switch status {
        case .authorized:
            authorized = true
        case .notDetermined:
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            authorized = false
        }
        guard authorized else {
            state = .unauthorized
            return
        }

        do {
            if !isConfigured {
                try configure()
                isConfigured = true
            }
            if !session.isRunning {
                sampleQueue.async { [session] in session.startRunning() }
            }
            state = .running
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private func stop() {
        guard session.isRunning else { return }
        sampleQueue.async { [session] in session.stopRunning() }
        state = .idle
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) else {
            throw CameraError.noFrontCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frame = FrameBuffer(
            pixelBuffer: pixelBuffer,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            for cont in self.continuations.values {
                cont.yield(frame)
            }
        }
    }
}
