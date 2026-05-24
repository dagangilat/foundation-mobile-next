import UIKit
import FirebaseCore
import FirebaseAppCheck

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register the noop App Check factory BEFORE FirebaseApp.configure
        // so the first token request inside Firebase init uses our
        // synthetic provider instead of the SDK's DeviceCheck fallback.
        // See AppCheckFactory.swift for the full rationale — without
        // this, the SDK hits exchangeDeviceCheckToken (400 "App not
        // registered") and burns 7-12 s on retries during cold launch.
        AppCheck.setAppCheckProviderFactory(AppCheckFactory())
        FirebaseApp.configure()
        return true
    }
}
