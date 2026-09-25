import Foundation
import SwiftUI

/// One entry behind Home's bell.
///
/// Holds reason text only: never a name, passport number or key. Callers pass
/// the same short error text the app used to show in a pop-up.
struct AppNotification: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case error
        case success
    }

    /// What "Try again" on a failed verification entry does. Entries with a
    /// retry also offer "Share app log".
    enum Retry: String, Codable {
        /// The passport part failed (scan or on-device proof): open the
        /// passport task guide again, as the Home card's "Try again" does.
        case scanPassport
        /// Foundation's own check failed: ask Foundation again.
        case finishVerification
    }

    let id: UUID
    let kind: Kind
    let title: String
    let message: String
    var date: Date
    var isRead: Bool
    let retry: Retry?

    var isVerificationFailure: Bool { kind == .error && retry != nil }
}

/// App-wide list of notifications shown behind Home's bell. Errors that used
/// to pop up over the screen land here instead (see `AlertManager.emitError`).
///
/// Kept in UserDefaults so it survives a relaunch, capped at `maxEntries`, and
/// cleared on sign out and account deletion.
final class AppNotificationStore: ObservableObject {
    static let shared = AppNotificationStore()

    static let maxEntries = 50
    private static let maxMessageLength = 600
    private static let storageKey = "foundation.appNotifications"

    @Published private(set) var entries: [AppNotification]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([AppNotification].self, from: data)
        {
            entries = saved
        } else {
            entries = []
        }
    }

    /// Drives the red dot on the bell: an error the person hasn't seen yet.
    var hasUnreadErrors: Bool {
        entries.contains { !$0.isRead && $0.kind == .error }
    }

    /// Lets Home's card say "The bell has the details." after a failed try
    /// that left no failure state of its own (for example an expired passport).
    var hasUnreadVerificationFailure: Bool {
        entries.contains { !$0.isRead && $0.isVerificationFailure }
    }

    var hasVerificationFailure: Bool {
        entries.contains { $0.isVerificationFailure }
    }

    // MARK: - Posting

    func postError(_ message: String, title: String = String(localized: "Something went wrong")) {
        post(kind: .error, title: title, message: message, retry: nil)
    }

    /// "Verification didn't finish", with Try again and Share app log.
    func postVerificationFailure(reason: String, retry: AppNotification.Retry) {
        post(
            kind: .error,
            title: String(localized: "Verification didn't finish"),
            message: reason,
            retry: retry
        )
    }

    func postSuccess(title: String, message: String) {
        post(kind: .success, title: title, message: message, retry: nil)
    }

    private func post(kind: AppNotification.Kind, title: String, message: String, retry: AppNotification.Retry?) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmed.count > Self.maxMessageLength
            ? String(trimmed.prefix(Self.maxMessageLength)) + "…"
            : trimmed

        onMain { [self] in
            // The same unread entry again (a retried call failing the same
            // way): bump it to the top instead of stacking duplicates.
            if let index = entries.firstIndex(where: {
                !$0.isRead && $0.kind == kind && $0.title == title && $0.message == text && $0.retry == retry
            }) {
                var existing = entries.remove(at: index)
                existing.date = Date()
                entries.insert(existing, at: 0)
            } else {
                let entry = AppNotification(
                    id: UUID(),
                    kind: kind,
                    title: title,
                    message: text,
                    date: Date(),
                    isRead: false,
                    retry: retry
                )
                entries.insert(entry, at: 0)
            }
            if entries.count > Self.maxEntries {
                entries.removeLast(entries.count - Self.maxEntries)
            }
            save()
        }
    }

    // MARK: - Reading and clearing

    func markAllRead() {
        onMain { [self] in
            guard entries.contains(where: { !$0.isRead }) else { return }
            entries = entries.map { entry in
                var entry = entry
                entry.isRead = true
                return entry
            }
            save()
        }
    }

    /// Sign out and account deletion: the list describes the departing member.
    func clear() {
        onMain { [self] in
            entries = []
            defaults.removeObject(forKey: Self.storageKey)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Callers post from background tasks too; `@Published` must change on
    /// the main thread.
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
