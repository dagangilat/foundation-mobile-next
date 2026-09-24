import Foundation
import OSLog

class LoggerUtil {
    static let subsystem = Bundle.main.bundleIdentifier ?? "Undefined"
    static let common = Logger(subsystem: subsystem, category: "Common")

    static func export() throws -> [String] {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        // The last few hours of this run, filtered by the store itself:
        // walking every entry since boot on the main thread could take long
        // enough to look like a hang.
        let position = store.position(timeIntervalSinceEnd: -6 * 60 * 60)
        let entries = try store
            .getEntries(at: position, matching: NSPredicate(format: "subsystem == %@", subsystem))
            .compactMap { $0 as? OSLogEntryLog }
            .map { "[\($0.date.formatted())] [\($0.category)] \($0.composedMessage)" }

        return entries
    }
}
