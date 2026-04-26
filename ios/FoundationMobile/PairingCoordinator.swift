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

    enum PendingAction: Equatable {
        case claim(payload: String)
        case disconnect
    }

    enum State: Equatable {
        case idle                                  // not paired
        case claiming                              // claim in flight
        case paired(sessionId: String)             // heartbeat active
        case releasing                             // release in flight
        case failed(message: String)               // last claim/heartbeat failed
        // Stolen-phone defense: claim/disconnect require a recent
        // email-link sign-in. When the current session is older than
        // PAIRING_AUTH_FRESHNESS_MS (or the server returns stale_auth),
        // PairingCoordinator parks the requested action here and the UI
        // prompts the user to sign back in. After a fresh sign-in the
        // user re-taps the action; we don't auto-resume to keep the
        // user's intent explicit.
        case needsFreshAuth(pending: PendingAction)
    }

    @Published private(set) var state: State = .idle

    private var heartbeatTask: Task<Void, Never>?
    // Tightened from 30s → 10s for demo-grade desktop disconnect
    // latency on mobile force-quit. Combined with the server's
    // HEARTBEAT_GRACE_MS=30s, the desktop's lease layer detects a
    // missing mobile within ~30-40s (heartbeat interval + grace).
    // Server-side sweep (every 1m) is no longer load-bearing —
    // AccessGate does its own client-side staleness check on a 5s
    // timer. See docs/architecture_pairing-lease-pattern-2026-04-26.md
    // for the full pattern rationale.
    private static let heartbeatInterval: Duration = .seconds(10)

    // Threshold for how recent the email-link sign-in must be before
    // claim/release will run. Sourced from the active profile JSON via
    // AppConfig.session.authFreshnessSeconds — hisec-global tightens to
    // 300s (5 min), standardsec sits at 600s (10 min default), lowsec-
    // attest relaxes to 1800s (30 min). Server-side ensureFreshPairingAuth
    // in foundation-global enforces an upper bound regardless of profile.
    private static var authFreshnessMs: Int64 {
        Int64(AppConfig.shared.session.authFreshnessSeconds) * 1000
    }

    /// Called by QRScannerView with the decoded payload. Trims whitespace +
    /// strips an optional `foundation://pair/` URL prefix so future deep-link
    /// formats remain compatible.
    func claim(scannedPayload: String) {
        let code = Self.extractCode(from: scannedPayload)
        guard !code.isEmpty else {
            state = .failed(message: "Empty pairing code.")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            if await self.isAuthStale() {
                self.state = .needsFreshAuth(pending: .claim(payload: scannedPayload))
                return
            }
            self.state = .claiming
            do {
                let result = try await FunctionsService.shared.claimPairingSession(code: code)
                self.state = .paired(sessionId: result.sessionId)
                self.startHeartbeat(sessionId: result.sessionId)
            } catch {
                if Self.isStaleAuthError(error) {
                    self.state = .needsFreshAuth(pending: .claim(payload: scannedPayload))
                } else {
                    self.state = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    /// User-initiated disconnect (e.g. tapped "Disconnect desktop" in
    /// HomeView). Server-side flip to status=disconnected; desktop reacts.
    func disconnect() {
        guard case .paired(let sessionId) = state else { return }
        Task { [weak self] in
            guard let self else { return }
            if await self.isAuthStale() {
                self.state = .needsFreshAuth(pending: .disconnect)
                return
            }
            self.state = .releasing
            self.heartbeatTask?.cancel()
            self.heartbeatTask = nil
            do {
                _ = try await FunctionsService.shared.releasePairingSession(sessionId: sessionId)
                self.state = .idle
            } catch {
                if Self.isStaleAuthError(error) {
                    self.state = .needsFreshAuth(pending: .disconnect)
                } else {
                    self.state = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    /// Called from HomeView's "Sign in to confirm" CTA when state is
    /// .needsFreshAuth. Drops to idle after sign-out so the next sign-in
    /// lands the user back on HomeView with a fresh auth_time, ready to
    /// re-tap the action.
    func clearStaleAuthGate() {
        state = .idle
    }

    private func isAuthStale() async -> Bool {
        guard let ageMs = await AuthService.shared.currentAuthAgeMs() else {
            // No current user / token unreadable — treat as stale; the
            // user will land on SignInView via the auth-state listener.
            return true
        }
        return ageMs > Self.authFreshnessMs
    }

    private static func isStaleAuthError(_ error: Error) -> Bool {
        // Server signals stale auth via HttpsError("failed-precondition",
        // "stale_auth: …"). The Firebase SDK surfaces that as an NSError
        // with FIRFunctionsErrorDomain code .failedPrecondition; the
        // localizedDescription includes the "stale_auth" prefix.
        let ns = error as NSError
        if ns.domain == "com.firebase.functions" && ns.code == 9 /* FailedPrecondition */ {
            return ns.localizedDescription.contains("stale_auth")
        }
        return ns.localizedDescription.contains("stale_auth")
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
