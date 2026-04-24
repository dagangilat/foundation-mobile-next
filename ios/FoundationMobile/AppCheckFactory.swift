import Foundation
import FirebaseAppCheck
import FirebaseCore

final class AppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        // Dispatch on simulator vs device, NOT on DEBUG. Dev-signed device
        // builds are DEBUG but must use real App Attest; only the simulator
        // (which has no Secure Enclave) needs the debug provider.
        // Deployment target is iOS 16+, so AppAttestProvider is always available
        // on real devices — no DeviceCheck fallback needed.
        #if targetEnvironment(simulator)
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
