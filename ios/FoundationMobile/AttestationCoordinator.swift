import Foundation
import DeviceCheck

// Drives the Phase 1 App Attest flow after sign-in and exposes UI-visible
// state. Kicks off at most once per signed-in session; a persisted keyId
// marks the device as already attested and the coordinator short-circuits.

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
    }

    @Published private(set) var state: State = .idle

    private var task: Task<Void, Never>?

    // Hard ceiling on the attest round-trip. Apple App Attest itself is
    // typically <2 s; Cloud Functions issueAttestationNonce + the on-device
    // generateKey/attestKey chain + recordMobileAttestation should land in
    // well under 10 s. Anything past 30 s is a stuck network call or a
    // backend that's never going to answer — surface the failure so the
    // user can tap Retry instead of staring at "Setting up your secure
    // session…" forever.
    private static let attestationTimeoutSeconds: Int = 30

    func start() {
        guard case .idle = state else { return }

        if !DCAppAttestService.shared.isSupported {
            state = .unsupported
            return
        }

        if let existing = Keychain.getAttestedKeyId() {
            state = .alreadyAttested(keyId: existing)
            return
        }

        state = .attesting
        task = Task { [weak self] in
            // Race the attest round-trip against a fixed timeout so the
            // coordinator can never wedge in .attesting indefinitely.
            let attestTask = Task<RecordAttestationResult, Error> {
                try await AttestationService.shared.attestDeviceEndToEnd()
            }
            let watchdog = Task<Void, Never> {
                try? await Task.sleep(for: .seconds(Self.attestationTimeoutSeconds))
                if !Task.isCancelled {
                    attestTask.cancel()
                }
            }
            defer { watchdog.cancel() }

            do {
                let result = try await attestTask.value
                guard let self else { return }
                if result.accepted, let keyId = Keychain.getAttestedKeyId() {
                    self.state = .attested(keyId: keyId)
                } else {
                    self.state = .failed("Backend rejected attestation")
                }
            } catch is CancellationError {
                self?.state = .failed(
                    "Timed out after \(Self.attestationTimeoutSeconds)s — server didn't respond. Tap Retry."
                )
            } catch {
                self?.state = .failed(String(describing: error))
            }
        }
    }

    /// User-driven retry. Cancels any in-flight task, resets state, and
    /// starts a fresh attestation round. Safe to call from any state.
    func retry() {
        reset()
        start()
    }

    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }
}
