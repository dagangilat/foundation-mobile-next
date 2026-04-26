import Foundation
import DeviceCheck

// Drives the Phase 1 App Attest flow after sign-in and exposes UI-visible
// state. Kicks off at most once per signed-in session; a persisted keyId
// marks the device as already attested and the coordinator short-circuits.

// Two-tier attestation model. "Standard" is the happy path: App Attest
// passed end-to-end. "Unattested" is the degraded fallback for simulator
// runs, user-skipped attestation, or environments where DCAppAttestService
// is unavailable. Server-side, unattested tier triggers tighter
// `auth_time` freshness windows on mutating callables and stamps each
// produced artifact with `attestationTier: "unattested"` so downstream
// consumers (governance evaluators, constitution rules) can weigh
// commitments by trust tier.
enum AttestationTier: String, Equatable, Sendable {
    case standard = "standard"
    case unattested = "unattested"
}

enum UnattestedReason: String, Equatable, Sendable {
    case userSkipped       // User tapped "Continue without attestation" at 10s
    case deviceUnsupported // DCAppAttestService.isSupported == false (simulator)
}

@MainActor
final class AttestationCoordinator: ObservableObject {
    static let shared = AttestationCoordinator()

    enum State: Equatable {
        case idle
        case unsupported
        case alreadyAttested(keyId: String)
        case attesting
        case attested(keyId: String)
        case failed(String)
        // User explicitly accepted the unattested degraded mode — distinct
        // from .failed (transient, user should retry) and .unsupported
        // (device incapable). UI can render this with a subtle banner
        // rather than an error treatment.
        case unattested(reason: UnattestedReason)
    }

    @Published private(set) var state: State = .idle

    /// Tier the rest of the app should send to authenticated callables.
    /// Read by FunctionsService to inject `attestationTier` into the
    /// request payload of every mutating call. Server enforces the
    /// freshness window + stamps artifacts based on this.
    var tier: AttestationTier {
        switch state {
        case .attested, .alreadyAttested:
            return .standard
        case .unsupported, .unattested:
            return .unattested
        case .idle, .attesting, .failed:
            // Optimistic default while attestation is in-flight or about
            // to retry. The UI gates outbound calls behind verifyStage so
            // this branch should never actually attach to a request.
            return .standard
        }
    }
    /// Becomes true `Self.userSkipAfterSeconds` into an `.attesting` run so
    /// the UI can render a "Continue without attestation" escape hatch.
    /// Reset on every state transition out of `.attesting`.
    @Published private(set) var canSkipAttestation: Bool = false

    private var task: Task<Void, Never>?
    private var skipPromptTask: Task<Void, Never>?
    /// Bumps on every start/retry/skip. Stale completions of a previously
    /// in-flight attest task check this before mutating state — without
    /// it, a user-initiated skip could be overwritten by a late-arriving
    /// DCAppAttestService callback because those callbacks don't honor
    /// Task cancellation (see `attestWithHardTimeout` below).
    private var generation: Int = 0

    // User-visible escape hatch threshold. After this many seconds in
    // `.attesting`, the coordinator publishes `canSkipAttestation = true`
    // so HomeView can show a "Continue without attestation" link below
    // the disabled "App Attest pending" CTA.
    private static let userSkipAfterSeconds: Int = 10

    // Hard ceiling on the attest round-trip. Apple App Attest itself is
    // typically <2 s; Cloud Functions issueAttestationNonce + the on-device
    // generateKey/attestKey chain + recordMobileAttestation should land in
    // well under 10 s. Anything past this is a stuck network call or a
    // backend that's never going to answer — race the work against a
    // sleep so the coordinator can never wedge in .attesting indefinitely.
    private static let hardTimeoutSeconds: Int = 30

    func start() {
        guard case .idle = state else { return }

        if !DCAppAttestService.shared.isSupported {
            // Simulator / older devices. Drop straight to unattested
            // tier so the user can proceed (server will gate downstream
            // calls + flag artifacts).
            state = .unattested(reason: .deviceUnsupported)
            return
        }

        if let existing = Keychain.getAttestedKeyId() {
            state = .alreadyAttested(keyId: existing)
            return
        }

        generation += 1
        let myGeneration = generation
        state = .attesting
        canSkipAttestation = false

        // 10s escape hatch — flips a published bool the UI watches.
        skipPromptTask?.cancel()
        skipPromptTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.userSkipAfterSeconds))
            guard let self else { return }
            if self.generation == myGeneration, case .attesting = self.state {
                self.canSkipAttestation = true
            }
        }

        task = Task { [weak self] in
            let outcome: Result<RecordAttestationResult, Error>
            do {
                let r = try await Self.attestWithHardTimeout()
                outcome = .success(r)
            } catch {
                outcome = .failure(error)
            }
            guard let self else { return }
            // Late completion of a stale generation — user already
            // skipped or retried. Drop the result on the floor so we
            // don't clobber the live state.
            if self.generation != myGeneration { return }
            self.skipPromptTask?.cancel()
            self.skipPromptTask = nil
            self.canSkipAttestation = false
            switch outcome {
            case .success(let r):
                if r.accepted, let keyId = Keychain.getAttestedKeyId() {
                    self.state = .attested(keyId: keyId)
                } else {
                    self.state = .failed("Backend rejected attestation")
                }
            case .failure(is TimeoutError):
                self.state = .failed(
                    "Timed out after \(Self.hardTimeoutSeconds)s — server didn't respond. Tap Retry."
                )
            case .failure(let e):
                self.state = .failed(String(describing: e))
            }
        }
    }

    /// User-driven retry. Cancels any in-flight task, resets state, and
    /// starts a fresh attestation round. Safe to call from any state.
    func retry() {
        reset()
        start()
    }

    /// User-driven escape hatch. Available only after `canSkipAttestation`
    /// flips true (10s in). Invalidates the in-flight task via the
    /// generation counter and surfaces a `.failed` state with copy that
    /// signals the user opted out — UI may treat this differently from a
    /// transient failure (e.g. let the user proceed in an unattested
    /// tier; that broader change lives in the two-tier App Attest task).
    func skipAttestation() {
        guard case .attesting = state else { return }
        generation += 1
        task?.cancel()
        task = nil
        skipPromptTask?.cancel()
        skipPromptTask = nil
        canSkipAttestation = false
        state = .unattested(reason: .userSkipped)
    }

    func reset() {
        generation += 1
        task?.cancel()
        task = nil
        skipPromptTask?.cancel()
        skipPromptTask = nil
        canSkipAttestation = false
        state = .idle
    }

    // MARK: - Hard-timeout race

    private struct TimeoutError: Error {}

    /// Race the real attest work against a fixed-duration sleep using a
    /// throwing task group. Whichever child finishes first wins — the
    /// other is cancelled. Critical: this short-circuits the OUTER await
    /// at the deadline. The DCAppAttestService callbacks inside
    /// AttestationService use `withCheckedThrowingContinuation`, which
    /// does NOT honor Task cancellation, so naively cancelling the
    /// attest task leaves `attestTask.value` blocked until Apple
    /// eventually calls back (potentially never, on simulator/network
    /// issues). Racing via a TaskGroup means we exit the outer `try
    /// await` regardless; any straggler callback resumes a discarded
    /// continuation, which Swift drops cleanly.
    private static func attestWithHardTimeout() async throws -> RecordAttestationResult {
        try await withThrowingTaskGroup(of: RecordAttestationResult.self) { group in
            group.addTask {
                try await AttestationService.shared.attestDeviceEndToEnd()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(hardTimeoutSeconds))
                throw TimeoutError()
            }
            // First child to throw or return wins the race.
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw TimeoutError()
            }
            return first
        }
    }
}
