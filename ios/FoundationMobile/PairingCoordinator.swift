import Foundation
import Combine

// Desktop pairing lifecycle. The mobile user scans a desktop-rendered QR
// containing a short pairing code; we claim the session server-side, then
// keep it alive with a 30s heartbeat. iOS will not reliably fire
// applicationWillTerminate, so we treat any of:
//   - app moves to background (scenePhase != .active)
//   - user signs out
//   - explicit user "Disconnect desktop" tap
// as a release signal. The server flips paired sessions to "stale" after
// 90s without a heartbeat (cleanupStalePairings), which is the desktop's
// disconnect signal.

@MainActor
final class PairingCoordinator: ObservableObject {
    static let shared = PairingCoordinator()

    enum State: Equatable {
        case idle                                  // not paired
        case claiming                              // claim in flight
        case paired(sessionId: String)             // heartbeat active
        case releasing                             // release in flight
        case failed(message: String)               // last claim/heartbeat failed
    }

    @Published private(set) var state: State = .idle

    private var heartbeatTask: Task<Void, Never>?
    private static let heartbeatInterval: Duration = .seconds(30)

    /// Called by QRScannerView with the decoded payload. Trims whitespace +
    /// strips an optional `foundation://pair/` URL prefix so future deep-link
    /// formats remain compatible.
    func claim(scannedPayload: String) {
        let code = Self.extractCode(from: scannedPayload)
        guard !code.isEmpty else {
            state = .failed(message: "Empty pairing code.")
            return
        }
        state = .claiming
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await FunctionsService.shared.claimPairingSession(code: code)
                self.state = .paired(sessionId: result.sessionId)
                self.startHeartbeat(sessionId: result.sessionId)
            } catch {
                self.state = .failed(message: error.localizedDescription)
            }
        }
    }

    /// User-initiated disconnect (e.g. tapped "Disconnect desktop" in
    /// HomeView). Server-side flip to status=disconnected; desktop reacts.
    func disconnect() {
        guard case .paired(let sessionId) = state else { return }
        state = .releasing
        heartbeatTask?.cancel()
        heartbeatTask = nil
        Task { [weak self] in
            guard let self else { return }
            _ = try? await FunctionsService.shared.releasePairingSession(sessionId: sessionId)
            self.state = .idle
        }
    }

    /// Called from FoundationMobileApp's scenePhase observer + AuthService
    /// signOut path. Best-effort release; desktop's stale window catches
    /// hard kills.
    func suspendOnLifecycleEvent() {
        guard case .paired(let sessionId) = state else { return }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        state = .idle
        Task {
            _ = try? await FunctionsService.shared.releasePairingSession(sessionId: sessionId)
        }
    }

    private func startHeartbeat(sessionId: String) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.heartbeatInterval)
                } catch { return }
                if Task.isCancelled { return }
                do {
                    _ = try await FunctionsService.shared.heartbeatPairingSession(sessionId: sessionId)
                } catch {
                    // Single-shot failures are tolerated; the server's stale
                    // window (90s) absorbs a missed beat. Two consecutive
                    // missed beats triggers a forced release so the local
                    // state matches the server's eventual flip.
                    self?.state = .failed(message: "Heartbeat failed: \(error.localizedDescription)")
                    self?.heartbeatTask?.cancel()
                    return
                }
            }
        }
    }

    private static func extractCode(from payload: String) -> String {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if let scheme = trimmed.range(of: "foundation://pair/") {
            return String(trimmed[scheme.upperBound...]).split(separator: "?").first.map(String.init) ?? ""
        }
        return trimmed
    }
}
