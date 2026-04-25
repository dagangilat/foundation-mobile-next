import Foundation

// Runtime configuration for tunables + the active security profile. Loaded
// once at launch from `foundationmobile.json` in the main bundle. The build-
// phase script `ios/scripts/select-profile.sh` copies the profile-specific
// JSON (hisec-global / standardsec / lowsec-attest) into the bundle as
// `foundationmobile.json` so the binary ships with exactly one profile baked
// in — auditable that a "low security" build does not contain the high-
// security thresholds, and vice versa.
//
// Fail-loud on missing or malformed JSON. A silent fallback would mask the
// build script not running and ship a binary with surprise defaults.

enum AppConfigError: Error {
    case bundleResourceMissing
    case decodeFailed(String)
    case unknownProfile(String)
}

struct AppConfig: Decodable, Sendable {
    let schemaVersion: Int
    let profile: Profile
    let splash: Splash
    let loading: Loading
    let liveness: Liveness
    let camera: Camera
    let captureView: CaptureViewSection
    let antiSpoof: AntiSpoof
    let faceMatch: FaceMatch
    // session: see struct below — added in schemaVersion 3.

    struct Profile: Decodable, Sendable {
        let id: String
        let label: String
        let description: String
        let requiredPhases: [String]
        let faceMatchSource: FaceMatchSource

        enum FaceMatchSource: String, Decodable, Sendable {
            case dg2            // ePassport NFC chip face image
            case documentPhoto  // back-camera capture of the document
            case none           // no face match in this profile
        }

        func requires(_ kind: ProofArtifact.Kind) -> Bool {
            requiredPhases.contains(kind.rawValue)
        }
    }

    struct Splash: Decodable, Sendable {
        let minDurationMs: UInt64
    }

    struct Loading: Decodable, Sendable {
        let phaseThresholdsMs: [Double]
    }

    struct Liveness: Decodable, Sendable {
        let scanBudgetSeconds: Int
        let poseHoldMs: Int
        let activePoses: [String]
        let frameStride: Int
        let minConfidence: Float
        let poses: [String: Pose]

        struct Pose: Decodable, Sendable {
            let yaw: Float
            let pitch: Float
            let yawTolerance: Float
            let pitchTolerance: Float
        }
    }

    struct Camera: Decodable, Sendable {
        let frameTimeoutSeconds: Int
    }

    struct CaptureViewSection: Decodable, Sendable {
        let postSealDismissMs: Int
    }

    struct AntiSpoof: Decodable, Sendable {
        let minScore: Float
        let modelTag: String
    }

    struct FaceMatch: Decodable, Sendable {
        let cosineThreshold: Float
    }

    // Session-level controls. authFreshnessSeconds gates pair claim/release
    // (and any future "sensitive" mobile op) on a recent email-link sign-in:
    // the JWT auth_time claim must be within this window. Profile-tunable
    // because high-security postures want tighter windows than community
    // postures. Server-side ensureFreshPairingAuth in foundation-global is
    // the load-bearing backstop; the client check is for UX.
    struct Session: Decodable, Sendable {
        let authFreshnessSeconds: Int
    }
    let session: Session

    // Support-sheet controls. maxPerSession caps how many diagnostic
    // tickets a single app session can submit; the count resets on app
    // relaunch. Prevents a wedged client from spamming /support during
    // a debug loop. SupportSessionTracker lives in memory only.
    struct Support: Decodable, Sendable {
        let maxPerSession: Int
    }
    let support: Support

    static let shared: AppConfig = {
        do {
            return try load()
        } catch {
            fatalError("AppConfig load failed: \(error). " +
                       "The build-phase script ios/scripts/select-profile.sh " +
                       "must copy a profile JSON into the bundle as " +
                       "foundationmobile.json before this resource is read.")
        }
    }()

    static func load() throws -> AppConfig {
        guard let url = Bundle.main.url(forResource: "foundationmobile", withExtension: "json") else {
            throw AppConfigError.bundleResourceMissing
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            throw AppConfigError.decodeFailed(String(describing: error))
        }
    }
}
