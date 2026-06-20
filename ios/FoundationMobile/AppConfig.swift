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
        // The credential this edition verifies, used to fill in onboarding /
        // verified-screen copy per white-label edition. Optional so existing
        // profiles and older bundles still decode; read via `documentNoun`.
        let document: Document?

        enum FaceMatchSource: String, Decodable, Sendable {
            case dg2            // ePassport NFC chip face image
            case documentPhoto  // back-camera capture of the document
            case none           // no face match in this profile
        }

        // Profile-injected document vocabulary for white-label copy, e.g.
        // "passport", "driving licence", "membership card". Possessive phrasing
        // in the UI ("your <noun>'s chip") keeps strings grammatical for any noun.
        struct Document: Decodable, Sendable {
            let noun: String    // full term, e.g. "passport"
            let short: String?  // compact form for chips/buttons, e.g. "ID"
        }

        // Display noun with a safe default, so any edition (or a profile
        // predating this field) still produces grammatical copy.
        var documentNoun: String { document?.noun ?? "identity document" }
        var documentShort: String { document?.short ?? "ID" }

        // The zk security classification this edition verifies to, named to
        // match the canonical profiles (hisec-global / standardsec /
        // lowsec-attest). Derived from the face-match source, which is the
        // distinguishing phase: an on-chip DG2 match means the NFC chip was
        // authenticated (High); a document-photo match is the chipless flow
        // (Standard); no match at all is device-attest + liveness only (Low).
        // Surfaced on the verified screen as the achieved trust tier.
        enum TrustTier: Int, Comparable, Sendable {
            case low = 0, standard = 1, high = 2
            static func < (a: TrustTier, b: TrustTier) -> Bool { a.rawValue < b.rawValue }
        }

        var trustTier: TrustTier {
            switch faceMatchSource {
            case .dg2:           return .high
            case .documentPhoto: return .standard
            case .none:          return .low
            }
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

    // MRZ scan tunables. Optional so profiles that don't read a passport
    // (standardsec uses documentPhoto; lowsec has no passport step) decode
    // without the key. `scanBudgetSeconds` is a deliberate confirmation
    // window: MRZScanView locks the first checksum-valid TD3 read as a
    // candidate, keeps scanning for this many seconds (latest clean read
    // wins), then commits — turning a single noisy OCR frame into a
    // multi-frame confirmation and giving the user a visible scan window
    // instead of an instant <1s dismissal.
    struct MRZ: Decodable, Sendable {
        let scanBudgetSeconds: Int
    }
    let mrz: MRZ?

    var mrzScanBudgetSeconds: Int { mrz?.scanBudgetSeconds ?? 3 }

    // Theming + branding, set per profile. Optional so existing profiles
    // without the key decode and fall back to the midnight palette / built-in
    // branding. `palette` names one of the ThemePalette presets
    // (midnight | light | ocean | forest | sunset). `branding` lets a
    // white-label profile (e.g. MoMA) swap the logo + hero assets.
    struct ThemeConfig: Decodable, Sendable {
        let palette: String?
        let branding: Branding?

        struct Branding: Decodable, Sendable {
            let logo: Asset?
            let hero: Hero?

            struct Asset: Decodable, Sendable {
                let asset: String       // imageset name in Images.xcassets
                let darkAsset: String?  // optional variant for dark palettes
            }
            struct Hero: Decodable, Sendable {
                let mode: String        // "pillars" (default) | "image"
                let asset: String?
                let darkAsset: String?
            }
        }
    }
    let theme: ThemeConfig?

    var themePaletteName: String { theme?.palette ?? "midnight" }

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

    // Desktop-pairing UI gate. When enabled=false, HomeView hides the
    // "Pair desktop" row entirely; the underlying PairingCoordinator +
    // QR scanner code stays compiled in (so flipping back is a JSON
    // edit, not a code change). Defaults to false for the demo path
    // since pair gating was a side-track for a non-critical feature.
    // Pairs with FEATURES.desktopPairing on the web side.
    struct Pairing: Decodable, Sendable {
        let enabled: Bool
    }
    let pairing: Pairing

    // Deployment targets selectable via the gear icon on the sign-in screen.
    // Optional — if absent, DeploymentService falls back to production-only.
    // Each entry names a GoogleService-Info-<plist>.plist bundled in the app;
    // AppDelegate registers a named FirebaseApp for each at startup so
    // switching is instant with no restart required.
    struct Deployment: Decodable, Sendable, Identifiable, Equatable {
        let id: String          // e.g. "production", "staging", "nyc-pilot"
        let name: String        // display label: "Production"
        let description: String // short tagline shown in picker
        let version: String     // semantic / build label for this deployment
        let webUrl: String      // canonical web-app base URL
        let plist: String       // GoogleService-Info plist name (without .plist)
    }
    let deployments: [Deployment]?

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
