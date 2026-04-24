import Foundation

// Thin wrapper around the Sprint-0 MOPRO smoke test so the host app compiles
// whether the xcframework has been built yet or not. The real call only
// switches on when Dagan has:
//   1. run mopro-smoke/build-xcframework.sh on macOS,
//   2. dragged MoproSmoke.xcframework into Xcode with Embed & Sign,
//   3. added the generated MoproSmoke.swift binding to the target,
//   4. added "-D MOPRO_LINKED" to Other Swift Flags.
//
// Until then, HomeView's MOPRO row shows the stub string so the smoke
// failure mode is visible instead of a linker error.

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
}
