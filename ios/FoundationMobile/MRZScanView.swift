import SwiftUI
import AVFoundation
import Vision
import UIKit

// Phase 3a — MRZ key entry. The ICAO 9303 BAC/PACE key is derived from three
// fields on the passport photo page: passport number, date of birth, date of
// expiry (each followed by an ICAO check digit). Primary path is Vision OCR
// on a live camera feed pointed at the photo page's Machine-Readable Zone;
// fallback is a typed form for all three fields.
//
// Hard invariant: the MRZ fields live in memory only for the duration of the
// scan flow. No Keychain writes, no disk persistence. The `onParsed` callback
// hands the parsed struct to the coordinator which drops it as soon as the
// NFC read completes.

struct MRZKey: Equatable, Sendable {
    let passportNumber: String   // 9 chars, '<' padded
    let dateOfBirth: String      // YYMMDD
    let dateOfExpiry: String     // YYMMDD

    // Build the canonical BAC/PACE MRZ key string — the concatenation of each
    // field with its ICAO check digit. PassportReader expects exactly this.
    var mrzKeyString: String {
        let pn = passportNumber + String(Self.checkDigit(passportNumber))
        let dob = dateOfBirth + String(Self.checkDigit(dateOfBirth))
        let exp = dateOfExpiry + String(Self.checkDigit(dateOfExpiry))
        return pn + dob + exp
    }

    // ICAO 9303 Part 3 §4.9 check-digit weights 7,3,1 repeating; '<' = 0,
    // '0'-'9' = 0-9, 'A'-'Z' = 10-35.
    static func checkDigit(_ input: String) -> Int {
        let weights = [7, 3, 1]
        var sum = 0
        for (i, ch) in input.uppercased().enumerated() {
            let v: Int
            if ch == "<" { v = 0 }
            else if let d = ch.asciiValue, d >= 0x30 && d <= 0x39 { v = Int(d - 0x30) }
            else if let a = ch.asciiValue, a >= 0x41 && a <= 0x5A { v = Int(a - 0x41) + 10 }
            else { v = 0 }
            sum += v * weights[i % 3]
        }
        return sum % 10
    }
}

struct MRZScanView: View {
    let profile: DocumentProfile
    let onParsed: (MRZKey) -> Void
    let onCancel: () -> Void

    @State private var mode: Mode = .camera
    @State private var manualPassport: String = ""
    @State private var manualDOB: String = ""
    @State private var manualExpiry: String = ""
    @State private var manualError: String?
    @State private var ocrStatus: String
    @StateObject private var ocr = MRZOCRSession()

    enum Mode { case camera, manual }

    init(profile: DocumentProfile, onParsed: @escaping (MRZKey) -> Void, onCancel: @escaping () -> Void) {
        self.profile = profile
        self.onParsed = onParsed
        self.onCancel = onCancel
        _ocrStatus = State(initialValue: profile.mrzFormat == .td1
            ? "Align the back of your \(profile.displayName) inside the frame"
            : "Align the photo page's bottom two lines inside the frame")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                switch mode {
                case .camera: cameraView
                case .manual: manualView
                }
            }
            .navigationTitle("Scan \(profile.displayName) MRZ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(Theme.brandGreen)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(mode == .camera ? "Type manually" : "Use camera") {
                        mode = (mode == .camera) ? .manual : .camera
                    }
                    .foregroundStyle(Theme.brandGreen)
                }
            }
        }
        .onAppear {
            ocr.scanBudgetSeconds = AppConfig.shared.mrzScanBudgetSeconds
            ocr.expectedFormat = profile.mrzFormat
            ocr.onParsed = { key in
                ocr.stop()
                onParsed(key)
            }
            ocr.onStatus = { msg in ocrStatus = msg }
            if mode == .camera { ocr.start() }
        }
        .onDisappear {
            ocr.stop()
        }
        .onChange(of: mode) { newMode in
            if newMode == .camera { ocr.start() } else { ocr.stop() }
        }
    }

    // MARK: camera path

    private var cameraView: some View {
        VStack(spacing: 16) {
            MRZCameraPreview(session: ocr.captureSession)
                .frame(maxWidth: .infinity)
                .aspectRatio(3.0/4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                // Dotted green guide frame around the MRZ region — helps the
                // user position the photo page's two code lines.
                .overlay(MRZGuideFrame().allowsHitTesting(false))
                // Countdown chip while a candidate read is being confirmed.
                .overlay(alignment: .topTrailing) {
                    if let remaining = ocr.countdown {
                        Text("\(remaining)s")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.brandGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.brandGreen.opacity(0.15), in: Capsule())
                            .overlay(Capsule().stroke(Theme.brandGreen.opacity(0.4)))
                            .padding(12)
                    }
                }

            Text(ocrStatus)
                .font(.callout)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    // MARK: manual path

    private var manualView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Passport number (up to 9 chars)")
                .font(.caption).foregroundStyle(Theme.muted)
            TextField("e.g. 123456789", text: $manualPassport)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(10).background(Theme.surface).cornerRadius(8)
                .foregroundStyle(Theme.text)

            Text("Date of birth (YYMMDD)")
                .font(.caption).foregroundStyle(Theme.muted)
            TextField("e.g. 900815", text: $manualDOB)
                .keyboardType(.numberPad)
                .padding(10).background(Theme.surface).cornerRadius(8)
                .foregroundStyle(Theme.text)

            Text("Date of expiry (YYMMDD)")
                .font(.caption).foregroundStyle(Theme.muted)
            TextField("e.g. 300815", text: $manualExpiry)
                .keyboardType(.numberPad)
                .padding(10).background(Theme.surface).cornerRadius(8)
                .foregroundStyle(Theme.text)

            if let err = manualError {
                Text(err).font(.caption).foregroundStyle(.orange)
            }

            Button {
                submitManual()
            } label: {
                Text("Use these values")
                    .font(.headline)
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandGreen)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .padding(20)
    }

    private func submitManual() {
        guard let key = MRZParser.normalize(
            passport: manualPassport,
            dob: manualDOB,
            expiry: manualExpiry
        ) else {
            manualError = "Check passport number (up to 9 chars, letters or digits) and both dates (YYMMDD, 6 digits)."
            return
        }
        manualError = nil
        onParsed(key)
    }
}

// MARK: - Vision OCR session

@MainActor
final class MRZOCRSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "mrz.ocr")
    private var configured = false
    private var running = false

    var onParsed: ((MRZKey) -> Void)?
    var onStatus: ((String) -> Void)?
    var expectedFormat: DocumentProfile.MRZFormat = .td3

    // Confirmation window. The first checksum-valid TD3 read locks a
    // candidate and starts a per-second countdown; later clean reads
    // overwrite the candidate (latest wins). On expiry the candidate is
    // committed via onParsed. `countdown` is published for the UI chip.
    @Published var countdown: Int?
    var scanBudgetSeconds: Int = 3
    private var candidate: MRZKey?
    private var commitTimer: Timer?
    private var committed = false

    func start() {
        guard !running else { return }
        configureIfNeeded()
        running = true
        // Reset any prior confirmation state on (re)entry.
        candidate = nil
        countdown = nil
        committed = false
        commitTimer?.invalidate()
        commitTimer = nil
        queue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stop() {
        commitTimer?.invalidate()
        commitTimer = nil
        countdown = nil
        guard running else { return }
        running = false
        queue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    // Called on the main actor each time OCR yields a checksum-valid key.
    // First call starts the countdown; subsequent calls just refresh the
    // candidate so the latest, cleanest read is the one committed.
    func lockCandidate(_ key: MRZKey) {
        guard !committed else { return }            // already handed off
        candidate = key
        guard commitTimer == nil else { return }   // already counting down
        onStatus?("Got it — hold steady…")
        countdown = scanBudgetSeconds
        commitTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                let next = (self.countdown ?? 1) - 1
                if next <= 0 {
                    self.commitTimer?.invalidate()
                    self.commitTimer = nil
                    self.countdown = nil
                    if let confirmed = self.candidate {
                        self.committed = true
                        self.onStatus?("Confirmed — reading chip…")
                        self.onParsed?(confirmed)
                    }
                } else {
                    self.countdown = next
                }
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        captureSession.commitConfiguration()
    }
}

extension MRZOCRSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self, let obs = req.results as? [VNRecognizedTextObservation] else { return }
            let lines: [String] = obs.compactMap { $0.topCandidates(1).first?.string }
            let key: MRZKey?
            switch self.expectedFormat {
            case .td3: key = MRZParser.parseTD3(lines: lines) ?? MRZParser.parseTD1(lines: lines)
            case .td1: key = MRZParser.parseTD1(lines: lines) ?? MRZParser.parseTD3(lines: lines)
            }
            if let key {
                Task { @MainActor in
                    self.lockCandidate(key)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Camera preview container

private struct MRZCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> MRZPreviewContainerView {
        let v = MRZPreviewContainerView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: MRZPreviewContainerView, context: Context) {}
}

// MARK: - MRZ guide frame

// Dotted green capture frame drawn over the camera preview: a dashed rounded
// rectangle plus four solid corner brackets, centred on the lower-middle band
// where the photo page's two MRZ lines sit. Drawn in a single Canvas so the
// dashed rect and brackets stay registered as the preview resizes.
private struct MRZGuideFrame: View {
    var body: some View {
        Canvas { ctx, size in
            // Frame occupies the central band: full width minus a margin,
            // ~48% of height, biased slightly below centre.
            let marginX: CGFloat = 22
            let frame = CGRect(
                x: marginX,
                y: size.height * 0.26,
                width: size.width - marginX * 2,
                height: size.height * 0.48
            )
            let green = GraphicsContext.Shading.color(Theme.brandGreen)

            // Dashed rounded rectangle.
            let rounded = Path(roundedRect: frame, cornerRadius: 12)
            ctx.stroke(
                rounded,
                with: .color(Theme.brandGreen.opacity(0.85)),
                style: StrokeStyle(lineWidth: 2, dash: [7, 5])
            )

            // Solid corner brackets.
            let len: CGFloat = 20
            var corners = Path()
            // top-left
            corners.move(to: CGPoint(x: frame.minX, y: frame.minY + len))
            corners.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
            corners.addLine(to: CGPoint(x: frame.minX + len, y: frame.minY))
            // top-right
            corners.move(to: CGPoint(x: frame.maxX - len, y: frame.minY))
            corners.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
            corners.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + len))
            // bottom-left
            corners.move(to: CGPoint(x: frame.minX, y: frame.maxY - len))
            corners.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
            corners.addLine(to: CGPoint(x: frame.minX + len, y: frame.maxY))
            // bottom-right
            corners.move(to: CGPoint(x: frame.maxX - len, y: frame.maxY))
            corners.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
            corners.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - len))
            ctx.stroke(corners, with: green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Camera preview container UIView

private final class MRZPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - Parser

enum MRZParser {
    // Parse a TD3 (2x44-char) MRZ from a set of OCR-recognized lines. We
    // tolerate noisy reads — scan the lines for any pair that match the TD3
    // shape, rather than assuming the OCR pair is clean.
    static func parseTD3(lines: [String]) -> MRZKey? {
        // Strip spaces; collapse to uppercase; MRZ is ASCII-only uppercase
        // letters, digits, and '<'.
        let cleaned = lines.map { line -> String in
            let up = line.uppercased()
            return up.filter { ch in
                (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "<"
            }
        }.filter { !$0.isEmpty }

        // Look for line2: 44 chars, passport number 0..8 + checkdigit 9
        // + nationality 10..12 + DOB 13..18 + checkdigit 19 + sex 20 +
        // expiry 21..26 + checkdigit 27.
        for candidate in cleaned where candidate.count >= 28 {
            // Take the first 44 chars; some OCR rows include extra noise.
            let line = String(candidate.prefix(44))
            guard line.count >= 28 else { continue }

            let chars = Array(line)
            let passportRaw = String(chars[0..<9])
            let pnCheck = chars[9]
            let dob = String(chars[13..<19])
            let dobCheck = chars[19]
            let expiry = String(chars[21..<27])
            let expCheck = chars[27]

            // Validate each check digit against ICAO 9303 rules. Any mismatch
            // means this wasn't the MRZ line (or OCR was wrong); skip it.
            guard
                pnCheck.isASCII, let pnCheckDigit = pnCheck.wholeNumberValue,
                pnCheckDigit == MRZKey.checkDigit(passportRaw),
                dobCheck.isASCII, let dobCheckDigit = dobCheck.wholeNumberValue,
                dobCheckDigit == MRZKey.checkDigit(dob),
                expCheck.isASCII, let expCheckDigit = expCheck.wholeNumberValue,
                expCheckDigit == MRZKey.checkDigit(expiry),
                dob.allSatisfy({ $0.isNumber }),
                expiry.allSatisfy({ $0.isNumber })
            else {
                continue
            }

            return MRZKey(
                passportNumber: passportRaw,
                dateOfBirth: dob,
                dateOfExpiry: expiry
            )
        }
        return nil
    }

    // Parse a TD1 (3x30-char) MRZ — national ID card format — from a set
    // of OCR-recognized lines. Unlike TD3 (where every needed field sits
    // on one line), TD1 splits document number (line 1) from DOB/expiry
    // (line 2), so we scan all candidate lines for each piece
    // independently and combine the first valid match of each. Field
    // offsets per ICAO 9303 Part 5: line 1 = doc code(2) + issuing
    // state(3) + doc number(9) + check digit(1) + optional(15); line 2 =
    // DOB(6) + check(1) + sex(1) + expiry(6) + check(1) + nationality(3)
    // + optional(11) + composite check(1).
    static func parseTD1(lines: [String]) -> MRZKey? {
        let cleaned = lines.map { line -> String in
            let up = line.uppercased()
            return up.filter { ch in
                (ch >= "A" && ch <= "Z") || (ch >= "0" && ch <= "9") || ch == "<"
            }
        }.filter { !$0.isEmpty }

        var documentNumber: String?
        var dateOfBirth: String?
        var dateOfExpiry: String?

        for candidate in cleaned where candidate.count >= 30 {
            let chars = Array(String(candidate.prefix(30)))

            if documentNumber == nil {
                let docNumberRaw = String(chars[5..<14])
                let docNumberCheck = chars[14]
                if docNumberCheck.isASCII,
                   let checkDigit = docNumberCheck.wholeNumberValue,
                   checkDigit == MRZKey.checkDigit(docNumberRaw) {
                    documentNumber = docNumberRaw
                }
            }

            if dateOfBirth == nil || dateOfExpiry == nil {
                let dob = String(chars[0..<6])
                let dobCheck = chars[6]
                let expiry = String(chars[8..<14])
                let expCheck = chars[14]
                if dobCheck.isASCII, let dobCheckDigit = dobCheck.wholeNumberValue,
                   dobCheckDigit == MRZKey.checkDigit(dob),
                   dob.allSatisfy({ $0.isNumber }),
                   expCheck.isASCII, let expCheckDigit = expCheck.wholeNumberValue,
                   expCheckDigit == MRZKey.checkDigit(expiry),
                   expiry.allSatisfy({ $0.isNumber }) {
                    dateOfBirth = dob
                    dateOfExpiry = expiry
                }
            }
        }

        guard let documentNumber, let dateOfBirth, let dateOfExpiry else { return nil }
        return MRZKey(
            passportNumber: documentNumber,
            dateOfBirth: dateOfBirth,
            dateOfExpiry: dateOfExpiry
        )
    }

    // Manual-entry fallback: uppercase, pad passport to 9 with '<', basic
    // shape checks. Returns nil on invalid inputs (no silent defaults).
    static func normalize(passport: String, dob: String, expiry: String) -> MRZKey? {
        let pnTrim = passport.trimmingCharacters(in: .whitespaces).uppercased()
        guard !pnTrim.isEmpty, pnTrim.count <= 9,
              pnTrim.allSatisfy({ ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") || $0 == "<" })
        else { return nil }
        let pn = pnTrim + String(repeating: "<", count: 9 - pnTrim.count)

        let dobTrim = dob.trimmingCharacters(in: .whitespaces)
        guard dobTrim.count == 6, dobTrim.allSatisfy({ $0.isNumber }) else { return nil }

        let expTrim = expiry.trimmingCharacters(in: .whitespaces)
        guard expTrim.count == 6, expTrim.allSatisfy({ $0.isNumber }) else { return nil }

        return MRZKey(passportNumber: pn, dateOfBirth: dobTrim, dateOfExpiry: expTrim)
    }
}
