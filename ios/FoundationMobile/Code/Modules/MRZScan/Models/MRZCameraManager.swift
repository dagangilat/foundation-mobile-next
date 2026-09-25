import AVFoundation
import Foundation

class MRZCameraManager: NSObject {
    private let captureSession = AVCaptureSession()
    private var deviceInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let systemPreferredCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    private var sessionQueue = DispatchQueue(label: "video.mrz.session")

    private var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            
            return isAuthorized
        }
    }
    
    private var addToPreviewStream: ((CGImage) -> Void)?
        
    lazy var previewStream: AsyncStream<CGImage> = AsyncStream { continuation in
        addToPreviewStream = { cgImage in
            continuation.yield(cgImage)
        }
    }
    
    override init() {
        super.init()
        
        Task {
            do {
                try await configureSession()
                await startSession()
            } catch {
                LoggerUtil.common.fault("Error configuring session: \(error, privacy: .public)")
            }
        }
    }
    
    private func configureSession() async throws {
        guard await isAuthorized, let systemPreferredCamera else { return }
        
        let deviceInput = try AVCaptureDeviceInput(device: systemPreferredCamera)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            
        guard captureSession.canAddInput(deviceInput) else {
            throw MRZCaptureSessionError.deviceInputNotAdded
        }
            
        guard captureSession.canAddOutput(videoOutput) else {
            throw MRZCaptureSessionError.videoOutputNotAdded
        }
            
        captureSession.beginConfiguration()
        captureSession.addInput(deviceInput)
        captureSession.addOutput(videoOutput)
        captureSession.commitConfiguration()
        
        // The session picks the camera format once the input is committed,
        // so zoom and focus are set after that.
        try systemPreferredCamera.lockForConfiguration()
        defer { systemPreferredCamera.unlockForConfiguration() }
        
        let zoom = Self.passportZoomFactor(for: systemPreferredCamera)
        systemPreferredCamera.videoZoomFactor = zoom
        if systemPreferredCamera.isAutoFocusRangeRestrictionSupported {
            systemPreferredCamera.autoFocusRangeRestriction = .near
        }
        if systemPreferredCamera.isFocusPointOfInterestSupported {
            systemPreferredCamera.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        if systemPreferredCamera.isFocusModeSupported(.continuousAutoFocus) {
            systemPreferredCamera.focusMode = .continuousAutoFocus
        }
        
        LoggerUtil.common.info("MRZ camera: zoom \(Double(zoom), privacy: .public)x, closest focus \(systemPreferredCamera.minimumFocusDistance, privacy: .public) mm")
    }
    
    /// Filling the on-screen passport guide at 1x puts the passport closer to
    /// the lens than it can focus (about 15-20 cm on recent iPhones), so the
    /// photo page comes out blurred and the MRZ can't be read. Zooming in lets
    /// the passport fill the guide from about 30 cm, where it is sharp.
    private static func passportZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        let passportWidth: Float = 125 // mm, ICAO TD3 page
        let guideFill: Float = 0.85 // share of the preview's width the guide covers
        
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let longSide = Float(max(dimensions.width, dimensions.height))
        let shortSide = Float(min(dimensions.width, dimensions.height))
        guard longSide > 0, shortSide > 0 else { return 1 }
        
        // videoFieldOfView spans the sensor's long side; in portrait the
        // preview's width is the short side.
        let halfAngle = device.activeFormat.videoFieldOfView * .pi / 360
        let halfTanAcrossWidth = tan(halfAngle) * shortSide / longSide
        guard halfTanAcrossWidth > 0 else { return 1 }
        
        let distanceAt1x = passportWidth / guideFill / 2 / halfTanAcrossWidth
        let closestFocus = Float(device.minimumFocusDistance)
        let wantedDistance = max(300, closestFocus > 0 ? closestFocus * 1.5 : 0)
        
        let maxZoom = min(Float(device.activeFormat.videoMaxZoomFactor), 3)
        return CGFloat(min(max(wantedDistance / distanceAt1x, 1), maxZoom))
    }
    
    /// Runs one focus pass on the middle of the frame, for Capture.
    func focusOnce() {
        setFocusMode(.autoFocus)
    }
    
    /// Goes back to following the passport as it moves.
    func resumeContinuousFocus() {
        setFocusMode(.continuousAutoFocus)
    }
    
    private func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        sessionQueue.async { [systemPreferredCamera] in
            guard let device = systemPreferredCamera, device.isFocusModeSupported(mode) else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                }
                device.focusMode = mode
                device.unlockForConfiguration()
            } catch {
                LoggerUtil.common.error("MRZ camera focus: \(error, privacy: .public)")
            }
        }
    }

    private func startSession() async {
        guard await isAuthorized else { return }
        
        captureSession.startRunning()
    }
    
    func stopSession() {
        captureSession.stopRunning()
    }
}

extension MRZCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let currentFrame = sampleBuffer.cgImage else {
            return
        }
        
        connection.videoOrientation = .portrait
        addToPreviewStream?(currentFrame)
    }
}

/// Moved here in Task B5: this AVCapture wiring error used to live in
/// `Modules/Likeness/Models/FaceCaptureSession.swift` (as
/// `FaceCaptureSessionError`), which was deleted with the Likeness module.
/// It is generic capture-session plumbing that MRZ scanning still needs.
enum MRZCaptureSessionError: Error {
    case deviceInputNotAdded
    case videoOutputNotAdded

    var localizedDescription: String {
        switch self {
        case .deviceInputNotAdded:
            return "Device input could not be added to the capture session."
        case .videoOutputNotAdded:
            return "Video output could not be added to the capture session."
        }
    }
}
