import Foundation
import CoreML
import CoreImage
import CoreGraphics
import Vision
import CryptoKit

// Phase 5 — real `.antiSpoof` artifact. Replaces MockAntiSpoofProducer when
// the active profile requires .antiSpoof.
//
// Inputs: the same selfie JPEGs CaptureCoordinator already captured during
// the liveness pose loop. Reusing them avoids waking the camera back up
// after passport scan and keeps anti-spoof inference deterministic from the
// exact frames the user already saw.
//
// Pipeline per frame:
//   1. Decode JPEG → CGImage.
//   2. Vision face detect → tightest bounding box (fall back to centre crop
//      if Vision misses; Silent-Face is forgiving on coarse crops).
//   3. Resize to 80×80 RGB.
//   4. Run both Silent-Face MiniFAS models, softmax their 3-class logits,
//      pick class 1 ("real") probability per model, average across models.
// Final score = mean per-frame "real" probability across all input frames.
//
// HARD INVARIANT: raw frames are not persisted. The producer holds them only
// for the duration of `produce()`; only the fused score, threshold, frame
// count, and model identity hashes go into the signed payload.

struct AntiSpoofProducer: ProofProducer {
    let kind: ProofArtifact.Kind = .antiSpoof

    let selfieJpegs: [Data]
    let threshold: Float
    let modelV2: MLModel
    let modelV1SE: MLModel

    static let defaultThreshold: Float = 0.55

    enum Failure: Error, LocalizedError {
        case noFrames
        case modelNotBundled(String)
        case decodeFailed
        case inferenceFailed(String)
        case rejected(Float)

        var errorDescription: String? {
            switch self {
            case .noFrames: return "Anti-spoof needs at least one selfie frame."
            case .modelNotBundled(let n): return "Anti-spoof model not bundled: \(n)"
            case .decodeFailed: return "Anti-spoof failed to decode a selfie frame."
            case .inferenceFailed(let m): return "Anti-spoof inference failed: \(m)"
            case .rejected(let s): return "Anti-spoof check failed (score \(String(format: "%.2f", s))). Please retry in good lighting."
            }
        }
    }

    init(
        selfieJpegs: [Data],
        threshold: Float = AntiSpoofProducer.defaultThreshold
    ) throws {
        guard !selfieJpegs.isEmpty else { throw Failure.noFrames }
        self.selfieJpegs = selfieJpegs
        self.threshold = threshold
        self.modelV2 = try Self.loadBundled(name: "SilentFaceMiniFASNetV2")
        self.modelV1SE = try Self.loadBundled(name: "SilentFaceMiniFASNetV1SE")
    }

    func produce() async throws -> ProofArtifact {
        var perFrameRealProb: [Float] = []
        for jpeg in selfieJpegs {
            guard let cg = Self.decodeJPEG(jpeg) else { throw Failure.decodeFailed }
            let faceCG = (try? Self.cropFace(cg)) ?? Self.centreCrop(cg)
            guard let resized = Self.resize(faceCG, width: 80, height: 80) else {
                throw Failure.decodeFailed
            }
            let p2 = try Self.realProbability(model: modelV2, image: resized)
            let p1se = try Self.realProbability(model: modelV1SE, image: resized)
            perFrameRealProb.append((p2 + p1se) / 2)
        }
        let score: Float = perFrameRealProb.reduce(0, +) / Float(perFrameRealProb.count)
        // Diagnostic (unconditional — staging/TF are Release): per-frame "real"
        // probabilities + mean. A uniformly near-zero spread points at a
        // systematic preprocessing problem (crop / colour / orientation), not
        // lighting; a mixed spread points at a few bad frames.
        print("[AntiSpoof] frames=\(selfieJpegs.count) perFrameReal=\(perFrameRealProb.map { String(format: "%.3f", $0) }) mean=\(String(format: "%.4f", score)) threshold=\(threshold)")
        let accepted = score >= threshold
        guard accepted else { throw Failure.rejected(score) }

        let payload = Self.canonicalPayload(
            accepted: accepted,
            score: score,
            threshold: threshold,
            frameCount: selfieJpegs.count,
            modelTag: "MiniFASNetV2+V1SE"
        )
        return try await ProofArtifactBuilder.build(kind: .antiSpoof, payload: payload)
    }

    static func canonicalPayload(
        accepted: Bool,
        score: Float,
        threshold: Float,
        frameCount: Int,
        modelTag: String
    ) -> Data {
        let scoreMilli = Int((score * 10_000).rounded())
        let thresholdMilli = Int((threshold * 10_000).rounded())
        let modelHash = SHA256.hash(data: Data(modelTag.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let line = "antiSpoof:accepted=\(accepted ? 1 : 0):frames=\(frameCount):model=\(modelHash):score10000=\(scoreMilli):threshold10000=\(thresholdMilli)"
        return Data(line.utf8)
    }

    // MARK: - Inference

    private static func realProbability(model: MLModel, image: CGImage) throws -> Float {
        let imgFV: MLFeatureValue
        do {
            imgFV = try MLFeatureValue(
                cgImage: image,
                pixelsWide: 80,
                pixelsHigh: 80,
                pixelFormatType: kCVPixelFormatType_32BGRA,
                options: nil
            )
        } catch {
            throw Failure.inferenceFailed(String(describing: error))
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: ["image": imgFV])
        let out = try model.prediction(from: provider)
        guard let arr = out.featureValue(for: "logits")?.multiArrayValue, arr.count == 3 else {
            throw Failure.inferenceFailed("logits shape != [3]")
        }
        // Softmax over 3 logits. Class 1 ("real") is what we report.
        let l0 = Float(truncating: arr[0])
        let l1 = Float(truncating: arr[1])
        let l2 = Float(truncating: arr[2])
        let m = max(l0, max(l1, l2))
        let e0 = expf(l0 - m), e1 = expf(l1 - m), e2 = expf(l2 - m)
        let sum = e0 + e1 + e2
        return e1 / sum
    }

    // MARK: - Image helpers

    private static func decodeJPEG(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    // Vision returns bounding boxes in normalized image coords with the
    // origin in the bottom-left. We flip to top-left and pad by 25% so the
    // crop captures forehead + chin (Silent-Face was trained on a slightly
    // looser crop than VNDetectFaceRectanglesRequest produces).
    private static func cropFace(_ image: CGImage) throws -> CGImage {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let face = (request.results ?? []).max(by: { $0.confidence < $1.confidence }) else {
            throw Failure.decodeFailed
        }
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let bb = face.boundingBox
        let pad: CGFloat = 0.25
        var rect = CGRect(
            x: (bb.minX - pad * bb.width) * w,
            y: (1 - bb.maxY - pad * bb.height) * h,
            width: (1 + 2 * pad) * bb.width * w,
            height: (1 + 2 * pad) * bb.height * h
        )
        rect = rect.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard rect.width > 1, rect.height > 1, let cropped = image.cropping(to: rect) else {
            throw Failure.decodeFailed
        }
        return cropped
    }

    private static func centreCrop(_ image: CGImage) -> CGImage {
        let w = image.width, h = image.height
        let side = min(w, h)
        let rect = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
        return image.cropping(to: rect) ?? image
    }

    private static func resize(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let cs = CGColorSpaceCreateDeviceRGB()
        let bmp: UInt32 = CGImageAlphaInfo.noneSkipLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: bmp
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    // MARK: - Bundle loading

    // Prefer Xcode-compiled .mlmodelc; fall back to runtime-compiling the
    // .mlpackage and caching the result. Xcode's CoreMLModelCompile only
    // runs when the .mlpackage file ref is in the right build phase with
    // the right last-known-file-type — both are fragile across pbxproj
    // edits and re-runs of add-swift-sources.rb. Runtime compile is the
    // belt-and-suspenders fallback that survives any pbxproj weirdness.
    // First call is ~1-2 s per model; subsequent calls hit the cache.
    private static func loadBundled(name: String) throws -> MLModel {
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndGPU

        if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
            do {
                return try MLModel(contentsOf: url, configuration: cfg)
            } catch {
                // Pre-compiled bundle is malformed — surface and stop.
                throw Failure.inferenceFailed("MLModel load (mlmodelc): \(error)")
            }
        }

        // `url(forResource:withExtension:"mlpackage")` does NOT reliably
        // resolve a directory-wrapper resource copied verbatim into the
        // .app (the pbxproj references these as opaque wrappers, so Xcode
        // never compiles them to .mlmodelc and the package ships as a
        // folder). Fall back to a direct resourceURL path — same fix as
        // CoreMLFaceEmbedder.locateBundledPackage.
        guard let packageURL = Self.locateBundledPackage(name: name) else {
            throw Failure.modelNotBundled(name)
        }
        do {
            let cachedURL = try Self.compileMLPackageToCache(name: name, packageURL: packageURL)
            return try MLModel(contentsOf: cachedURL, configuration: cfg)
        } catch {
            throw Failure.inferenceFailed("MLModel runtime-compile + load: \(error)")
        }
    }

    private static func locateBundledPackage(name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "mlpackage") {
            return url
        }
        if let resourceURL = Bundle.main.resourceURL {
            let direct = resourceURL.appendingPathComponent("\(name).mlpackage")
            if FileManager.default.fileExists(atPath: direct.path) {
                return direct
            }
        }
        return nil
    }

    private static func compileMLPackageToCache(name: String, packageURL: URL) throws -> URL {
        let fm = FileManager.default
        let cachesURL = try fm.url(
            for: .cachesDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let modelDir = cachesURL.appendingPathComponent("MLModelCache", isDirectory: true)
        try? fm.createDirectory(at: modelDir, withIntermediateDirectories: true)
        let cachedURL = modelDir.appendingPathComponent("\(name).mlmodelc")
        if !fm.fileExists(atPath: cachedURL.path) {
            let compiledURL = try MLModel.compileModel(at: packageURL)
            try? fm.removeItem(at: cachedURL)
            try fm.moveItem(at: compiledURL, to: cachedURL)
        }
        return cachedURL
    }
}
