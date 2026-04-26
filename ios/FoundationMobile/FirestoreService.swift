import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    struct UserDoc: Equatable, Sendable {
        let ring: Int?
        let inviteStatus: String?
    }

    @Published private(set) var userDoc: UserDoc?

    // True once any of the user's identity_commitments docs has reached
    // status="anchored". Drives HomeView's swap to WebHomeView so the
    // Verify-humanity CTA + technical readouts disappear after a
    // successful registration. Persists across app launches — unlike
    // CaptureCoordinator.anchorStatus, which is in-memory only.
    @Published private(set) var humanityVerified: Bool = false

    private var registration: ListenerRegistration?
    private var humanityRegistration: ListenerRegistration?

    func observeUser(uid: String) {
        registration?.remove()
        let db = Firestore.firestore()
        registration = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let data = snap?.data() else {
                    self?.userDoc = nil
                    return
                }
                let ring = (data["ring"] as? Int) ?? (data["ring"] as? NSNumber)?.intValue
                self.userDoc = UserDoc(
                    ring: ring,
                    inviteStatus: data["inviteStatus"] as? String
                )
                // Fast-path hydrate: anchorIdentityCommitmentTask stamps
                // users/{uid}.humanityVerified=true atomically with the
                // commitments doc flip. Reading it from the user doc
                // (already subscribed) means the verification badges
                // can paint green on cold launch the moment this
                // listener fires, without waiting for the second
                // identity_commitments query below to round-trip. The
                // commitments query stays as the authoritative source —
                // if it ever returns false after the user-doc said
                // true, we trust the commitments query.
                if let flag = data["humanityVerified"] as? Bool, flag {
                    self.humanityVerified = true
                }
            }
        }

        humanityRegistration?.remove()
        // limit:1 — we only need yes/no. Server marks the doc
        // status="anchored" inside anchorIdentityCommitmentTask once
        // the Solana tx lands.
        //
        // Path matches server-side anchorCommitment + handler:
        //   identity_commitments/{uid}/commitments/{hashHex}
        // Earlier this listened at users/{uid}/identity_commitments
        // (drift from a pre-Phase-2 layout) and silently never matched.
        // A future "passport expired" filter will layer on top so an
        // old anchored commitment doesn't keep the user out of the
        // verify funnel forever.
        humanityRegistration = db.collection("identity_commitments")
            .document(uid)
            .collection("commitments")
            .whereField("status", isEqualTo: "anchored")
            .limit(to: 1)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.humanityVerified = !(snap?.documents.isEmpty ?? true)
                }
            }
    }

    func stopObserving() {
        registration?.remove()
        registration = nil
        humanityRegistration?.remove()
        humanityRegistration = nil
        userDoc = nil
        humanityVerified = false
    }
}
