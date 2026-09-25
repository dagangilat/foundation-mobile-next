import Combine
import SwiftUI
import UIKit

struct AppAlertSubject: Equatable {
    let type: AppAlertType
    let message: String?
}

class AlertManager: ObservableObject {
    static let shared = AlertManager()

    /// Errors no longer pop up over the screen: they go behind Home's bell
    /// (`AppNotificationStore`), which shows a red dot until they are read.
    /// A screen that can't be used without seeing its error shows it inline
    /// instead of calling this.
    func emitError(_ error: Errors) {
        AppNotificationStore.shared.postError(error.localizedDescription)
    }

    func emitError(_ message: String) {
        AppNotificationStore.shared.postError(message)
    }

    /// The old error pop-up, kept only for a scan flow that stays open on
    /// screen (the QR camera, the chip read) and has no inline slot, so the
    /// person sees why the scan didn't take while still holding the phone
    /// to it.
    func emitScanFlowError(_ error: Errors) {
        AlertPresenter().show(AppAlertSubject(type: .error, message: error.localizedDescription))
    }

    func emitSuccess(_ message: String) {
        AlertPresenter().show(AppAlertSubject(type: .success, message: message))
    }

    func emitProcessing(_ message: String) {
        AlertPresenter().show(AppAlertSubject(type: .processing, message: message))
    }
}

private let ALERT_WINDOW_HEIGHT: CGFloat = 100
private let ALERT_DURATION: TimeInterval = 5 // seconds

// Reference: https://gist.github.com/tciuro/059cb9a82b9dcdebbb87644db6fe90bd
class AlertPresenter {
    private var alertWindow: UIWindow?

    func show(_ alert: AppAlertSubject) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        alertWindow = UIWindow(windowScene: scene)
        alertWindow?.backgroundColor = .clear
        alertWindow?.frame = CGRect(x: 0, y: -100, width: UIScreen.main.bounds.width, height: ALERT_WINDOW_HEIGHT)

        if alert.type == .success {
            FeedbackGenerator.shared.notify(.success)
        } else if alert.type == .error {
            FeedbackGenerator.shared.notify(.error)
        }

        func hide() {
            UIView.animate(withDuration: 0.25, animations: {
                self.alertWindow?.frame = CGRect(x: 0, y: -100, width: UIScreen.main.bounds.width, height: ALERT_WINDOW_HEIGHT)
            }) { _ in
                self.alertWindow?.isHidden = true
                self.alertWindow = nil
            }
        }

        alertWindow?.rootViewController = UIHostingController(
            rootView: AppAlert(type: alert.type, message: alert.message)
                .onTapGesture(perform: hide)
        )
        alertWindow?.rootViewController?.view.backgroundColor = .clear
        alertWindow?.makeKeyAndVisible()

        UIView.animate(withDuration: 0.25, animations: {
            self.alertWindow?.frame = CGRect(x: 0, y: 50, width: UIScreen.main.bounds.width, height: ALERT_WINDOW_HEIGHT)
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + ALERT_DURATION) {
            hide()
        }
    }
}
