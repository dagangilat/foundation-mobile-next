import Foundation
import FirebaseAppCheck
import FirebaseCore

/// App Check provider factory: real App Attest on device, debug
/// provider on simulator.
///
/// **Pre-flight**
///
/// Requires the iOS bundle ID `com.foundationnext.mobile` to be registered
/// with App Attest + DeviceCheck in the `foundation-next-app` Firebase
/// Console, and the simulator's debug token registered in the App Check
/// debug-tokens list.
///
/// **Without that registration**, every token-fetch attempt will 400
/// with "App not registered", the SDK will retry, and you'll be back
/// in the cold-launch retry storm we just escaped from. Don't ship this
/// file to a build that's going to install on a device until the
/// Console side is done.
///
/// **History**
///
/// Reverted from `NoopAppCheckProvider` (a synthetic-token workaround
/// that pretended App Check was working). Reasoning in
/// `foundation-global/docs/architecture_app-check-review-2026-04-28.md`
/// section 3 (workaround #1). The synthetic-token provider taught the
/// codebase that forging a security token to keep the SDK quiet was
/// acceptable; this restoration reverses that precedent.
final class AppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        // Dispatch on simulator vs device, NOT on DEBUG. Dev-signed device
        // builds are DEBUG but must use real App Attest; only the simulator
        // (which has no Secure Enclave) needs the debug provider. The
        // debug provider emits a UUID at first launch (visible in Xcode
        // console as "App Check debug token: …") which must be registered
        // in Firebase Console → App Check → debug tokens.
        //
        // Deployment target is iOS 18+ (project.pbxproj's real value, not
        // the plan's original iOS 16+ assumption - corrected 2026-09-04,
        // scoped re-review finding M-1), so AppAttestProvider is always
        // available on real devices — no DeviceCheck-on-old-iOS fallback
        // needed in code (Firebase auto-falls-back to DeviceCheck for
        // pre-iOS-14 devices, which we don't support).
        #if targetEnvironment(simulator)
        return AppCheckDebugProviderFactory().createProvider(with: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
