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
        
        /// Capture: reads the frame on screen right away instead of waiting
        /// for the live scan to lock on. Uses a stricter reading pass (no
        /// language correction, spaces removed), which suits the MRZ lines.
        @MainActor
        func capture() async {
            guard let image = currentFrame, !isCapturing else { return }

            isCapturing = true
            captureFailed = false
            defer { isCapturing = false }

            let found: Bool
            do {
                found = try await detectMRZ(image, isManualCapture: true)
            } catch {
                LoggerUtil.common.error("Error reading MRZ on capture: \(error, privacy: .public)")
                found = false
            }

            if !found { captureFailed = true }
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
                for text in recognizedTexts {
                    if !(text.count == 30 || text.count == 43 || text.count == 44) {
                        continue
                    }
                    
                    if let documentType {
                        switch documentType {
                        case .idCard:
                            return readMRZFromIDCard(text, documentNumber, nationality)
                        case .passport:
                            return readMRZFromPassport(text, nationality)
                        }
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
