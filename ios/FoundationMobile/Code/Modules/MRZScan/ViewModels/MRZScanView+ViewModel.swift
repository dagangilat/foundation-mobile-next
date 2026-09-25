import Combine
import Semaphore
import SwiftUI
import Vision

extension MRZScanView {
    class ViewModel: ObservableObject {
        @Published var currentFrame: CGImage?

        /// A Capture tap is reading the frame on screen.
        @Published var isCapturing = false
        /// The last Capture tap found no readable MRZ in its frame.
        @Published var captureFailed = false
        /// A valid MRZ was read, by the live scan or by Capture.
        private var didReadMRZ = false
        
        private let cameraManager = MRZCameraManager()
        
        var lastMRZAttemptDate = Date()
        
        private let semaphore = AsyncSemaphore(value: 1)
        
        var onMRZKey: (String) -> Void = { _ in }
        var onUSA: () -> Void = {}
        
        @Published var cameraTask: Task<Void, Never>? = nil
        
        func startScanning() {
            cameraTask = Task { await handleCameraPreviews() }
        }
        
        func stopScanning() {
            cameraTask?.cancel()
            
            cameraManager.stopSession()
        }
        
        func handleCameraPreviews() async {
            for await image in cameraManager.previewStream {
                Task { @MainActor in
                    currentFrame = image
                }
                
                Task { @MainActor in
                    do {
                        try await detectMRZ(image)
                    } catch {
                        LoggerUtil.common.error("Error detecting MRZ: \(error, privacy: .public)")
                    }
                }
            }
        }
        
        /// Capture: refocuses on the middle of the frame, then reads the
        /// frames that follow for a few seconds instead of waiting for the
        /// live scan to lock on. Uses a stricter reading pass (no language
        /// correction, spaces removed), which suits the MRZ lines.
        @MainActor
        func capture() async {
            guard currentFrame != nil, !isCapturing else { return }

            isCapturing = true
            captureFailed = false
            defer { isCapturing = false }

            cameraManager.focusOnce()

            let deadline = Date().addingTimeInterval(3)
            var lastImage: CGImage?
            repeat {
                if let image = currentFrame, image !== lastImage {
                    lastImage = image
                    do {
                        if try await detectMRZ(image, isManualCapture: true) { return }
                    } catch {
                        LoggerUtil.common.error("Error reading MRZ on capture: \(error, privacy: .public)")
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            } while Date() < deadline && !didReadMRZ && !Task.isCancelled

            if didReadMRZ { return }

            cameraManager.resumeContinuousFocus()
            captureFailed = true
        }

        /// Returns true once a valid MRZ key was read and passed on.
        @discardableResult
        func detectMRZ(_ image: CGImage, isManualCapture: Bool = false) async throws -> Bool {
            await semaphore.wait()
            defer { semaphore.signal() }
            
            if !isManualCapture && lastMRZAttemptDate > Date().addingTimeInterval(-0.5) {
                return false
            }
            
            defer {
                lastMRZAttemptDate = Date()
            }
            
            var recognizedTexts: [String] = []
            
            let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
            
            let request = VNRecognizeTextRequest { request, _ in
                guard let result = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                // Extract the data
                let stringArray = result.compactMap { result in
                    result.topCandidates(1).first?.string
                }
                
                recognizedTexts.append(contentsOf: stringArray)
            }
            
            request.recognitionLevel = .accurate
            if isManualCapture {
                request.usesLanguageCorrection = false
            }
            
            try requestHandler.perform([request])
            
            if isManualCapture {
                recognizedTexts = recognizedTexts.map { $0.replacingOccurrences(of: " ", with: "").uppercased() }
            }
            
            if !recognizedTexts.isEmpty {
                var nationality = ""
                var documentType: DocumentType? = nil
                var documentNumber = ""
                lines: for text in recognizedTexts {
                    if !(text.count == 30 || text.count == 43 || text.count == 44) {
                        continue
                    }
                    
                    if let documentType {
                        let isRead: Bool
                        switch documentType {
                        case .idCard:
                            isRead = readMRZFromIDCard(text, documentNumber, nationality)
                        case .passport:
                            isRead = readMRZFromPassport(text, nationality)
                        }
                        
                        if isRead { return true }
                        break lines
                    } else {
                        if text.starts(with: "P<") {
                            documentType = .passport
                            
                            nationality = getNationality(text)
                            
                            continue
                        } else if text.starts(with: "ID") {
                            documentType = .idCard
                            
                            let documentNumberStartIndex = text.index(text.startIndex, offsetBy: 5)
                            let documentNumberEndIndex = text.index(text.startIndex, offsetBy: 14)
                            
                            documentNumber = String(text[documentNumberStartIndex...documentNumberEndIndex])
                            
                            nationality = getNationality(text)
                            
                            continue
                        }
                    }
                }
            }
            
            // The strict reading above needs both passport lines whole and
            // exactly 44 characters long. OCR often splits the lines, drops a
            // few "<" or reads a 0 as O, so also look for the second line's
            // fields anywhere in what was read. The three check digits guard
            // against a wrong read.
            if let fields = MRZLineReader.passportFields(in: recognizedTexts) {
                return readMrzFromDocument(fields.0, fields.1, fields.2, fields.3)
            }
            
            return false
        }
        
        @discardableResult
        func readMRZFromPassport(_ text: String, _ nationality: String) -> Bool {
            let documentNumberStartIndex = text.index(text.startIndex, offsetBy: 0)
            let documentNumberEndIndex = text.index(text.startIndex, offsetBy: 9)
            
            let birthdayStartIndex = text.index(text.startIndex, offsetBy: 13)
            let birthdayEndIndex = text.index(text.startIndex, offsetBy: 19)
            
            let expirationStartIndex = text.index(text.startIndex, offsetBy: 21)
            let expirationEndIndex = text.index(text.startIndex, offsetBy: 27)
            
            let documentNumber = String(text[documentNumberStartIndex...documentNumberEndIndex])
            let birthday = String(text[birthdayStartIndex...birthdayEndIndex])
            let expiration = String(text[expirationStartIndex...expirationEndIndex])
                
            return readMrzFromDocument(documentNumber, birthday, expiration, nationality)
        }
        
        @discardableResult
        func readMRZFromIDCard(_ text: String, _ documentNumber: String, _ nationality: String) -> Bool {
            let birthdayStartIndex = text.index(text.startIndex, offsetBy: 0)
            let birthdayEndIndex = text.index(text.startIndex, offsetBy: 6)
            
            let expirationStartIndex = text.index(text.startIndex, offsetBy: 8)
            let expirationEndIndex = text.index(text.startIndex, offsetBy: 14)
            
            let birthday = String(text[birthdayStartIndex...birthdayEndIndex])
            let expiration = String(text[expirationStartIndex...expirationEndIndex])
            
            return readMrzFromDocument(documentNumber, birthday, expiration, nationality)
        }
        
        @discardableResult
        func readMrzFromDocument(
            _ documentNumber: String,
            _ birthday: String,
            _ expiration: String,
            _ nationality: String
        ) -> Bool {
            let mrzKey = "\(documentNumber+birthday+expiration)"
            
            let checkMrzKey = PassportUtils.getMRZKey(
                passportNumber: String(documentNumber.dropLast()),
                dateOfBirth: String(birthday.dropLast()),
                dateOfExpiry: String(expiration.dropLast())
            )
            
            if mrzKey == checkMrzKey {
                if nationality == "USA" {
                    onUSA()
                }
                
                didReadMRZ = true
                onMRZKey(mrzKey)
                
                stopScanning()
                
                return true
            }
            
            return false
        }
        
        func getNationality(_ text: String) -> String {
            let nationalityStartIndex = text.index(text.startIndex, offsetBy: 2)
            let nationalityEndIndex = text.index(text.startIndex, offsetBy: 4)
            
            return String(text[nationalityStartIndex...nationalityEndIndex]).uppercased()
        }
    }
}

extension MRZScanView.ViewModel {
    enum DocumentType {
        case idCard, passport
    }
}

/// Finds a passport's (TD3) second MRZ line in OCR output that the strict
/// reader rejects: split into pieces, missing filler, "«" for "<", or letters
/// read in place of digits.
enum MRZLineReader {
    // Letters OCR commonly returns for digits; accepted only in digit fields.
    private static let digit = "[0-9OQDILZSB]"
    private static let digitFixes: [Character: Character] = [
        "O": "0", "Q": "0", "D": "0", "I": "1", "L": "1", "Z": "2", "S": "5", "B": "8",
    ]

    // Document number + check, nationality, birth date + check, sex,
    // expiry date + check.
    private static let secondLine = try! NSRegularExpression(
        pattern: "([A-Z0-9<]{9})(\(digit))([A-Z<]{3})(\(digit){6})(\(digit))[MFX<](\(digit){6})(\(digit))"
    )

    /// (documentNumber + check, birthday + check, expiration + check, nationality),
    /// the shapes `readMrzFromDocument` expects, or nil when nothing matches.
    static func passportFields(in texts: [String]) -> (String, String, String, String)? {
        let lines = texts.map(normalize).filter { !$0.isEmpty }
        var candidates = lines
        for index in lines.indices.dropLast() {
            candidates.append(lines[index] + lines[index + 1])
        }
        candidates.append(lines.joined())

        for text in candidates {
            let length = (text as NSString).length
            var start = 0
            // Try every start position: a misaligned match that fails its
            // check digits must not hide the real line that overlaps it.
            while start < length,
                  let match = secondLine.firstMatch(in: text, range: NSRange(location: start, length: length - start))
            {
                if let fields = validFields(match, in: text) { return fields }
                start = match.range.location + 1
            }
        }

        return nil
    }

    private static func validFields(_ match: NSTextCheckingResult, in text: String) -> (String, String, String, String)? {
        func group(_ index: Int) -> String {
            guard let range = Range(match.range(at: index), in: text) else { return "" }
            return String(text[range])
        }
        func digits(_ index: Int) -> String {
            String(group(index).map { digitFixes[$0] ?? $0 })
        }

        let documentNumber = group(1)
        let birthday = digits(4)
        let expiration = digits(6)
        let fields = (
            documentNumber + digits(2),
            birthday + digits(5),
            expiration + digits(7),
            group(3).replacingOccurrences(of: "<", with: "")
        )
        let expected = PassportUtils.getMRZKey(
            passportNumber: documentNumber,
            dateOfBirth: birthday,
            dateOfExpiry: expiration
        )

        return fields.0 + fields.1 + fields.2 == expected ? fields : nil
    }

    private static func normalize(_ text: String) -> String {
        text.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "«", with: "<")
            .replacingOccurrences(of: "‹", with: "<")
    }
}
