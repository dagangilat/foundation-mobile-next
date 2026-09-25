import Foundation
import OSLog

class LoggerUtil {
    static let subsystem = Bundle.main.bundleIdentifier ?? "Undefined"
    static let common = AppLogger(subsystem: subsystem, category: "Common")

    // Entries also go to the app's own log file (AppLogFile), kept across
    // launches. The system log store only returns the current run and drops
    // info-level entries, so it came back empty whenever someone sent a log
    // after reopening the app.

    static func export() throws -> [String] {
        AppLogFile.shared.contents()
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

enum AppLogPrivacy {
    case `public`
    case `private`
}

/// Same call shape as `Logger` messages (`"\(value, privacy: .public)"`), so
/// every existing call site keeps compiling. Values not marked public are
/// written as <private>, as the system log does.
struct AppLogMessage: ExpressibleByStringInterpolation {
    let text: String

    init(stringLiteral value: String) {
        text = value
    }

    init(stringInterpolation: StringInterpolation) {
        text = stringInterpolation.text
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var text = ""

        init(literalCapacity: Int, interpolationCount: Int) {
            text.reserveCapacity(literalCapacity)
        }

        mutating func appendLiteral(_ literal: String) {
            text += literal
        }

        mutating func appendInterpolation<T>(_ value: T, privacy: AppLogPrivacy = .private) {
            text += privacy == .public ? String(describing: value) : "<private>"
        }
    }
}

/// Writes to the system log and to the app's log file.
struct AppLogger {
    private let logger: Logger
    private let category: String

    init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
        self.category = category
    }

    func debug(_ message: AppLogMessage) {
        logger.debug("\(message.text, privacy: .public)")
        AppLogFile.shared.append(level: "DEBUG", category: category, message.text)
    }

    func info(_ message: AppLogMessage) {
        logger.info("\(message.text, privacy: .public)")
        AppLogFile.shared.append(level: "INFO", category: category, message.text)
    }

    func warning(_ message: AppLogMessage) {
        logger.warning("\(message.text, privacy: .public)")
        AppLogFile.shared.append(level: "WARN", category: category, message.text)
    }

    func error(_ message: AppLogMessage) {
        logger.error("\(message.text, privacy: .public)")
        AppLogFile.shared.append(level: "ERROR", category: category, message.text)
    }

    func fault(_ message: AppLogMessage) {
        logger.fault("\(message.text, privacy: .public)")
        AppLogFile.shared.append(level: "FAULT", category: category, message.text)
    }
}

/// Application Support/Logs/foundation-app-log.txt, trimmed to the newest
/// half once it passes 2 MB. Not backed up.
final class AppLogFile {
    static let shared = AppLogFile()

    let url: URL

    private let queue = DispatchQueue(label: "foundation.app-log-file")
    private let dateFormatter = ISO8601DateFormatter()
    private var handle: FileHandle?

    private static let maxSize = 2 * 1024 * 1024

    private init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Logs", directoryHint: .isDirectory)
        url = directory.appending(path: "foundation-app-log.txt")
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        queue.async { [self] in
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            trimIfNeeded()
            if !FileManager.default.fileExists(atPath: url.path()) {
                FileManager.default.createFile(atPath: url.path(), contents: nil)
            }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try? mutableURL.setResourceValues(values)

            handle = try? FileHandle(forWritingTo: url)
            _ = try? handle?.seekToEnd()

            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "?"
            let build = info?["CFBundleVersion"] as? String ?? "?"
            var system = utsname()
            uname(&system)
            let machine = withUnsafeBytes(of: system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            let os = ProcessInfo.processInfo.operatingSystemVersionString
            write("[\(dateFormatter.string(from: Date()))] [INFO] [App] ---- Launch: app \(version) (\(build)), \(os), \(machine) ----")
        }
    }

    func append(level: String, category: String, _ text: String) {
        let date = Date()
        queue.async { [self] in
            write("[\(dateFormatter.string(from: date))] [\(level)] [\(category)] \(text)")
        }
    }

    func contents() -> String {
        queue.sync {
            try? handle?.synchronize()
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }

    /// A copy of the log in the temporary folder, for sharing.
    func exportCopy() throws -> URL {
        let copy = FileManager.default.temporaryDirectory.appending(path: "foundation-app-log.txt")
        var text = contents()
        if text.isEmpty { text = "The app log is empty." }
        try Data(text.utf8).write(to: copy, options: .atomic)
        return copy
    }

    private func write(_ line: String) {
        try? handle?.write(contentsOf: Data((line + "\n").utf8))
    }

    private func trimIfNeeded() {
        guard let data = try? Data(contentsOf: url), data.count > Self.maxSize else { return }

        var tail = data.suffix(Self.maxSize / 2)
        if let newline = tail.firstIndex(of: UInt8(ascii: "\n")) {
            tail = tail[tail.index(after: newline)...]
        }
        try? Data(tail).write(to: url, options: .atomic)
    }
}
