import Foundation

// Thin wrapper around the Sprint-0 MOPRO smoke test so the host app compiles
// whether the xcframework has been built yet or not. The real calls only
// switch on when Dagan has:
//   1. run mopro-smoke/build-xcframework.sh on macOS,
//   2. dragged MoproSmoke.xcframework into Xcode with Embed & Sign,
//   3. added the generated MoproSmoke.swift binding to the target,
//   4. added "-D MOPRO_LINKED" to Other Swift Flags.
//
// Until then, HomeView's MOPRO rows show stub strings so the smoke
// failure modes are visible instead of a linker error.

enum SmokeProofResult {
    case ok(publicInputs: [String])
    case skipped
    case failed(String)
}

enum MoproSmokeBridge {
    static func hello() -> String {
        #if MOPRO_LINKED
        return moproSmokeHello()
        #else
        return "mopro-smoke: xcframework not linked yet — run mopro-smoke/build-xcframework.sh on macOS, then follow mopro-smoke/README.md."
        #endif
    }

    static var isLinked: Bool {
        #if MOPRO_LINKED
        return true
        #else
        return false
        #endif
    }

    /// Generates a Groth16 proof for the upstream mopro `multiplier2` circuit
    /// (`a*b=c`) against the bundled zkey. Intentionally a smoke test: the
    /// circuit is stock upstream and doesn't prove anything Foundation-specific
    /// — its job is to validate that `generateCircomProof` on the Rust side is
    /// reachable, the zkey is loadable from the app bundle, and the Swift
    /// types emitted by uniffi-bindgen line up with what HomeView can display.
    ///
    /// Phase 3 will swap the zkey and reuse this same call seat for the real
    /// NFC-bound circuit; the plumbing is what matters.
    static func runMultiplier2Smoke() async -> SmokeProofResult {
        #if MOPRO_LINKED
        guard let zkeyURL = Bundle.main.url(
            forResource: "multiplier2_final",
            withExtension: "zkey",
            subdirectory: "circuits"
        ) ?? Bundle.main.url(
            forResource: "multiplier2_final",
            withExtension: "zkey"
        ) else {
            return .failed("multiplier2_final.zkey not in bundle")
        }

        return await Task.detached(priority: .userInitiated) { () -> SmokeProofResult in
            do {
                let result = try generateCircomProof(
                    zkeyPath: zkeyURL.path,
                    circuitInputs: "{\"a\":\"3\",\"b\":\"4\"}",
                    proofLib: .arkworks
                )
                return .ok(publicInputs: result.inputs)
            } catch {
                return .failed(String(describing: error))
            }
        }.value
        #else
        return .skipped
        #endif
    }
}
