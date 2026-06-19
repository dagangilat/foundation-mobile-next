import Foundation
import FirebaseCore

typealias Deployment = AppConfig.Deployment

final class DeploymentService: ObservableObject {
    static let shared = DeploymentService()

    let all: [Deployment]
    @Published private(set) var current: Deployment

    private static let defaultDeployment = Deployment(
        id: "production",
        name: "Production",
        description: "Live platform — foundation-global.com",
        version: "1.0",
        webUrl: "https://foundation-global.com",
        plist: "GoogleService-Info"
    )

    private init() {
        let deployments = AppConfig.shared.deployments ?? [Self.defaultDeployment]
        self.all = deployments
        let savedId = UserDefaults.standard.string(forKey: "selectedDeploymentId")
        self.current = deployments.first { $0.id == savedId } ?? deployments[0]
    }

    var currentFirebaseApp: FirebaseApp {
        if current.plist == "GoogleService-Info" { return FirebaseApp.app()! }
        return FirebaseApp.app(name: current.id) ?? FirebaseApp.app()!
    }

    func isAvailable(_ deployment: Deployment) -> Bool {
        if deployment.plist == "GoogleService-Info" { return true }
        return Bundle.main.path(forResource: deployment.plist, ofType: "plist") != nil
    }

    @MainActor
    func select(_ deployment: Deployment) {
        guard isAvailable(deployment), deployment.id != current.id else { return }
        current = deployment
        UserDefaults.standard.set(deployment.id, forKey: "selectedDeploymentId")
        AuthService.shared.reattach()
    }
}
