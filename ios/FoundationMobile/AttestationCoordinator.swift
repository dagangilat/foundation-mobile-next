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
            do {
                let result = try await AttestationService.shared.attestDeviceEndToEnd()
                guard let self else { return }
                if result.accepted, let keyId = Keychain.getAttestedKeyId() {
                    self.state = .attested(keyId: keyId)
                } else {
                    self.state = .failed("Backend rejected attestation")
                }
            } catch {
                self?.state = .failed(String(describing: error))
            }
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }
}
