import Foundation
import CoreML
import CoreImage
import CoreGraphics

// Phase 6 — real face embedder, replacing StubFaceEmbedder.
// MobileFaceNet, 1.0M params, ~2MB compiled. Input 112×96 RGB, output
// 128-dim embedding. Conversion was done from Xiaoccer/MobileFaceNet_Pytorch
// in tools/coreml-convert/convert-mobilefacenet.py — preprocessing
// (scale 1/128, bias -127.5/128) is baked into the .mlpackage's ImageType
// input, so the Swift side only needs to provide a CGImage at 112×96.

struct CoreMLFaceEmbedder: FaceEmbedder {
    let dimension: Int = 128
    let model: MLModel

    enum Failure: Error, LocalizedError {
        case modelNotBundled
        case resizeFailed
        case inferenceFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotBundled: return "MobileFaceNet model not bundled."
            case .resizeFailed: return "Failed to resize face crop to 112×96."
            case .inferenceFailed(let m): return "MobileFaceNet inference failed: \(m)"
            }
        }
    }

    // Prefer Xcode-compiled .mlmodelc; fall back to runtime-compiling the
    // .mlpackage and caching the result. See AntiSpoofProducer.loadBundled
    // for the rationale (pbxproj build-phase fragility).
    static func tryLoadFromBundle() -> CoreMLFaceEmbedder? {
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndGPU

        // Fast path: Xcode-compiled .mlmodelc. Only present when the build
        // recognizes the .mlpackage as a CoreML source and runs its compile
        // rule — which it does NOT when the file is referenced as an opaque
        // `wrapper` in the pbxproj (the case here). Logged, not silent.
        if let url = Bundle.main.url(forResource: "MobileFaceNet", withExtension: "mlmodelc") {
            do {
                let model = try MLModel(contentsOf: url, configuration: cfg)
                print("[CoreMLFaceEmbedder] loaded precompiled .mlmodelc")
                return CoreMLFaceEmbedder(model: model)
            } catch {
                print("[CoreMLFaceEmbedder] .mlmodelc present but load failed: \(error)")
            }
        }

        // Fallback: runtime-compile the bundled .mlpackage. `url(forResource:
        // withExtension:)` does NOT reliably resolve a directory-wrapper
        // resource that was copied verbatim (vs. a flattened file), so when
        // it returns nil we look the package up directly under resourceURL.
        // Without this the lookup silently fails → StubFaceEmbedder →
        // faceMatch distance ≈ 1.0 → faceMatchRejected → POH dead-ends.
        guard let packageURL = locateBundledPackage(name: "MobileFaceNet") else {
            print("[CoreMLFaceEmbedder] MobileFaceNet.mlpackage NOT found in bundle (neither url(forResource:) nor resourceURL) — falling back to stub")
            return nil
        }
        do {
            let cachedURL = try compileToCache(name: "MobileFaceNet", packageURL: packageURL)
            let model = try MLModel(contentsOf: cachedURL, configuration: cfg)
            print("[CoreMLFaceEmbedder] runtime-compiled .mlpackage at \(packageURL.lastPathComponent)")
            return CoreMLFaceEmbedder(model: model)
        } catch {
            print("[CoreMLFaceEmbedder] runtime compile failed: \(error)")
            return nil
        }
    }

    /// Resolve a bundled `.mlpackage` robustly. Tries the standard resource
    /// lookup first, then a direct path under the bundle's resource dir —
    /// directory-wrapper resources don't always answer `url(forResource:
    /// withExtension:)` even when physically present in the .app.
    static func locateBundledPackage(name: String) -> URL? {
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

    private static func compileToCache(name: String, packageURL: URL) throws -> URL {
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

    func embed(_ image: CGImage) async throws -> [Float] {
        guard let resized = Self.resize(image, width: 96, height: 112) else {
            throw Failure.resizeFailed
        }
        let imgFV: MLFeatureValue
        do {
            imgFV = try MLFeatureValue(
                cgImage: resized,
                pixelsWide: 96,
                pixelsHigh: 112,
                pixelFormatType: kCVPixelFormatType_32BGRA,
                options: nil
            )
        } catch {
            throw Failure.inferenceFailed(String(describing: error))
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: ["image": imgFV])
        let out: MLFeatureProvider
        do {
            out = try await model.prediction(from: provider)
        } catch {
            throw Failure.inferenceFailed(String(describing: error))
        }
        guard let arr = out.featureValue(for: "embedding")?.multiArrayValue,
              arr.count == dimension else {
            throw Failure.inferenceFailed("embedding shape != [\(dimension)]")
        }
        var v = [Float](repeating: 0, count: dimension)
        for i in 0..<dimension { v[i] = Float(truncating: arr[i]) }
        return Self.l2Normalize(v)
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

    private static func l2Normalize(_ v: [Float]) -> [Float] {
        let mag = sqrt(v.reduce(Float(0)) { $0 + $1 * $1 })
        return mag > 0 ? v.map { $0 / mag } : v
    }
}
