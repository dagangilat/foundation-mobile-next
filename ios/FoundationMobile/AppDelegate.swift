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

        // Default app — production, from GoogleService-Info.plist.
        FirebaseApp.configure()

        // Register named apps for any additional deployments whose plist is
        // bundled. DeploymentService reads the selection; FunctionsService +
        // AuthService consult it to route calls to the right Firebase project.
        for dep in DeploymentService.shared.all where dep.plist != "GoogleService-Info" {
            guard
                let path = Bundle.main.path(forResource: dep.plist, ofType: "plist"),
                let opts = FirebaseOptions(contentsOfFile: path)
            else { continue }
            FirebaseApp.configure(name: dep.id, options: opts)
        }

        return true
    }
}
