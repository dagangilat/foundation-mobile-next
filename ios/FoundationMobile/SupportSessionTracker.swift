import Foundation
import Combine

// In-memory counter of support tickets sent during this app session.
// Resets on app relaunch (terminated → cold-start). Also resets on
// sign-out so a switched user doesn't inherit the previous user's
// quota. AppConfig.support.maxPerSession is the per-profile cap; this
// tracker is the live counter the SupportSheet reads against it.
//
// Singleton because multiple SupportSheet instances (e.g. presented
// from HomeView and again from WebHomeView) need to share the cap.
@MainActor
final class SupportSessionTracker: ObservableObject {
    static let shared = SupportSessionTracker()

    @Published private(set) var sentCount: Int = 0

    func recordSent() {
        sentCount += 1
    }

    func reset() {
        sentCount = 0
    }

    var maxPerSession: Int {
        AppConfig.shared.support.maxPerSession
    }

    var remaining: Int {
        max(0, maxPerSession - sentCount)
    }

    var isAtLimit: Bool {
        sentCount >= maxPerSession
    }
}
